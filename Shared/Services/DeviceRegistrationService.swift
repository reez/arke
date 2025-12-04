//
//  DeviceRegistrationService.swift
//  Arké
//
//  Created by Christoph on 12/04/25.
//

import Foundation
import SwiftData
import Observation

#if os(iOS)
import UIKit
#endif

@MainActor
@Observable
class DeviceRegistrationService {
    // MARK: - Published Properties
    
    /// All registered devices for the current wallet
    var registeredDevices: [DeviceRegistration] = []
    
    /// Error message for device registration operations
    var error: String?
    
    /// Loading state
    var isLoading: Bool = false
    
    // MARK: - Dependencies
    
    private var modelContext: ModelContext?
    private let taskManager: TaskDeduplicationManager
    
    // MARK: - Constants
    
    private let keychainService = "com.arke.device"
    private let deviceIdAccount = "deviceId"
    private let lastHeartbeatKey = "com.arke.device.lastHeartbeat"
    private let heartbeatInterval: TimeInterval = 24 * 60 * 60  // 24 hours
    
    // MARK: - Cached Values
    
    private var cachedDeviceId: String?
    
    // MARK: - Initialization
    
    init(taskManager: TaskDeduplicationManager) {
        self.taskManager = taskManager
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        
        // Load registered devices
        Task {
            await loadRegisteredDevices()
        }
    }
    
    // MARK: - Device ID Management
    
    /// Gets or creates a stable device ID stored in Keychain
    /// This ID survives app reinstall and NEVER syncs via iCloud Keychain
    func getOrCreateDeviceId() throws -> String {
        // Return cached value if available
        if let cached = cachedDeviceId {
            return cached
        }
        
        // Try to load from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: deviceIdAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let deviceId = String(data: data, encoding: .utf8) {
            cachedDeviceId = deviceId
            
            #if DEBUG
            print("✅ [DeviceRegistrationService] Loaded existing device ID: \(deviceId)")
            #endif
            
            return deviceId
        }
        
        // Generate new device ID
        let newDeviceId = UUID().uuidString
        guard let data = newDeviceId.data(using: .utf8) else {
            throw DeviceRegistrationError.encodingFailed
        }
        
        // Store in Keychain with ThisDeviceOnly
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: deviceIdAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false  // NEVER sync!
        ]
        
        status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw DeviceRegistrationError.keychainError(status)
        }
        
        cachedDeviceId = newDeviceId
        
        #if DEBUG
        print("✅ [DeviceRegistrationService] Created new device ID: \(newDeviceId)")
        #endif
        
        return newDeviceId
    }
    
    /// Gets the current device name from the system
    private func getDeviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Unknown Device"
        #endif
    }
    
    /// Gets the current platform
    private func getDevicePlatform() -> DevicePlatform {
        return DevicePlatform.current
    }
    
    /// Gets the device model identifier (e.g., "iPhone15,3")
    private func getDeviceModelIdentifier() -> String? {
        #if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #elseif os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
        #else
        return nil
        #endif
    }
    
    // MARK: - Device Registration
    
    /// Registers the current device in the device registry
    /// - Parameters:
    ///   - walletHash: The hash of the wallet this device is associated with
    ///   - hasSeed: Whether this device has the seed phrase stored locally
    func registerCurrentDevice(walletHash: String, hasSeed: Bool) async throws {
        return try await taskManager.execute(key: "registerCurrentDevice") {
            guard let modelContext = self.modelContext else {
                throw DeviceRegistrationError.noModelContext
            }
            
            let deviceId = try self.getOrCreateDeviceId()
            let deviceName = self.getDeviceName()
            let platform = self.getDevicePlatform()
            let modelIdentifier = self.getDeviceModelIdentifier()
            
            // Check if device already registered
            let descriptor = FetchDescriptor<DeviceRegistration>(
                predicate: #Predicate { $0.deviceId == deviceId }
            )
            
            if let existing = try? modelContext.fetch(descriptor).first {
                // Update existing registration
                existing.deviceName = deviceName
                existing.walletHash = walletHash
                existing.hasSeed = hasSeed
                existing.lastSeenAt = Date()
                existing.lastAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                existing.isActive = true
                existing.deviceModelIdentifier = modelIdentifier
                
                #if DEBUG
                print("✅ [DeviceRegistrationService] Updated existing device registration")
                #endif
            } else {
                // Create new registration
                let registration = DeviceRegistration(
                    deviceId: deviceId,
                    deviceName: deviceName,
                    platform: platform,
                    walletHash: walletHash,
                    hasSeed: hasSeed,
                    deviceModelIdentifier: modelIdentifier
                )
                
                modelContext.insert(registration)
                
                #if DEBUG
                print("✅ [DeviceRegistrationService] Created new device registration")
                #endif
            }
            
            try modelContext.save()
            
            // Update last heartbeat timestamp
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastHeartbeatKey)
            
            // Reload devices list
            await self.loadRegisteredDevices()
        }
    }
    
    /// Updates the current device's seed status
    /// Call this when a device imports the seed via QR code
    func updateCurrentDeviceHasSeed(_ hasSeed: Bool) async throws {
        guard let modelContext = modelContext else {
            throw DeviceRegistrationError.noModelContext
        }
        
        let deviceId = try getOrCreateDeviceId()
        
        let descriptor = FetchDescriptor<DeviceRegistration>(
            predicate: #Predicate { $0.deviceId == deviceId }
        )
        
        guard let registration = try? modelContext.fetch(descriptor).first else {
            throw DeviceRegistrationError.deviceNotRegistered
        }
        
        registration.hasSeed = hasSeed
        registration.lastSeenAt = Date()
        
        try modelContext.save()
        
        #if DEBUG
        print("✅ [DeviceRegistrationService] Updated device hasSeed to \(hasSeed)")
        #endif
        
        await loadRegisteredDevices()
    }
    
    /// Unregisters the current device from the device registry
    func unregisterCurrentDevice() async throws {
        guard let modelContext = modelContext else {
            throw DeviceRegistrationError.noModelContext
        }
        
        let deviceId = try getOrCreateDeviceId()
        
        let descriptor = FetchDescriptor<DeviceRegistration>(
            predicate: #Predicate { $0.deviceId == deviceId }
        )
        
        if let registration = try? modelContext.fetch(descriptor).first {
            modelContext.delete(registration)
            try modelContext.save()
            
            #if DEBUG
            print("🗑️ [DeviceRegistrationService] Unregistered current device")
            #endif
            
            await loadRegisteredDevices()
        }
    }
    
    // MARK: - Heartbeat System
    
    /// Updates the heartbeat timestamp if needed (>24h since last update)
    func updateHeartbeatIfNeeded() async {
        let lastHeartbeat = UserDefaults.standard.double(forKey: lastHeartbeatKey)
        let timeSinceLastHeartbeat = Date().timeIntervalSince1970 - lastHeartbeat
        
        // Only update if more than 24 hours have passed
        guard timeSinceLastHeartbeat > heartbeatInterval else {
            #if DEBUG
            let hoursRemaining = (heartbeatInterval - timeSinceLastHeartbeat) / 3600
            print("⏭️ [DeviceRegistrationService] Skipping heartbeat (next in \(String(format: "%.1f", hoursRemaining)) hours)")
            #endif
            return
        }
        
        do {
            try await updateHeartbeat()
        } catch {
            #if DEBUG
            print("⚠️ [DeviceRegistrationService] Heartbeat update failed: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Updates the last seen timestamp for the current device
    func updateHeartbeat() async throws {
        guard let modelContext = modelContext else {
            throw DeviceRegistrationError.noModelContext
        }
        
        let deviceId = try getOrCreateDeviceId()
        
        let descriptor = FetchDescriptor<DeviceRegistration>(
            predicate: #Predicate { $0.deviceId == deviceId }
        )
        
        guard let registration = try? modelContext.fetch(descriptor).first else {
            // Device not registered yet - this is OK, will register when wallet is created
            return
        }
        
        registration.lastSeenAt = Date()
        registration.lastAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        try modelContext.save()
        
        // Update last heartbeat timestamp
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastHeartbeatKey)
        
        #if DEBUG
        print("💓 [DeviceRegistrationService] Heartbeat updated")
        #endif
        
        await loadRegisteredDevices()
    }
    
    // MARK: - Queries
    
    /// Loads all registered devices from SwiftData
    func loadRegisteredDevices() async {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<DeviceRegistration>(
            sortBy: [SortDescriptor(\.lastSeenAt, order: .reverse)]
        )
        
        if let devices = try? modelContext.fetch(descriptor) {
            registeredDevices = devices
            
            #if DEBUG
            print("📱 [DeviceRegistrationService] Loaded \(devices.count) registered devices")
            #endif
        }
    }
    
    /// Gets all active devices (excluding inactive and stale devices)
    func getActiveDevices() async throws -> [DeviceRegistration] {
        guard let modelContext = modelContext else {
            throw DeviceRegistrationError.noModelContext
        }
        
        let descriptor = FetchDescriptor<DeviceRegistration>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.lastSeenAt, order: .reverse)]
        )
        
        let devices = try modelContext.fetch(descriptor)
        
        // Filter out stale devices
        return devices.filter { !$0.isStale }
    }
    
    /// Gets all devices except the current one
    func getOtherDevices() async throws -> [DeviceRegistration] {
        guard let modelContext = modelContext else {
            throw DeviceRegistrationError.noModelContext
        }
        
        let currentDeviceId = try getOrCreateDeviceId()
        
        let descriptor = FetchDescriptor<DeviceRegistration>(
            predicate: #Predicate { $0.deviceId != currentDeviceId && $0.isActive == true },
            sortBy: [SortDescriptor(\.lastSeenAt, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Checks if there are other active devices besides the current one
    func hasOtherActiveDevices() async throws -> Bool {
        let others = try await getOtherDevices()
        // Filter out stale devices
        return others.contains { !$0.isStale }
    }
    
    /// Gets the current device registration
    func getCurrentDevice() async throws -> DeviceRegistration? {
        guard let modelContext = modelContext else {
            throw DeviceRegistrationError.noModelContext
        }
        
        let deviceId = try getOrCreateDeviceId()
        
        let descriptor = FetchDescriptor<DeviceRegistration>(
            predicate: #Predicate { $0.deviceId == deviceId }
        )
        
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Gets stale devices (not seen in specified number of days)
    func getStaleDevices(olderThan days: Int = 30) async throws -> [DeviceRegistration] {
        guard let modelContext = modelContext else {
            throw DeviceRegistrationError.noModelContext
        }
        
        let descriptor = FetchDescriptor<DeviceRegistration>(
            sortBy: [SortDescriptor(\.lastSeenAt, order: .reverse)]
        )
        
        let allDevices = try modelContext.fetch(descriptor)
        
        return allDevices.filter { $0.isStale(threshold: days) }
    }
    
    // MARK: - Device Management
    
    /// Unlinks a specific device by deviceId
    func unlinkDevice(_ deviceId: String) async throws {
        guard let modelContext = modelContext else {
            throw DeviceRegistrationError.noModelContext
        }
        
        let descriptor = FetchDescriptor<DeviceRegistration>(
            predicate: #Predicate { $0.deviceId == deviceId }
        )
        
        guard let registration = try? modelContext.fetch(descriptor).first else {
            throw DeviceRegistrationError.deviceNotFound
        }
        
        // Delete the registration (could also set isActive = false to keep history)
        modelContext.delete(registration)
        try modelContext.save()
        
        #if DEBUG
        print("🗑️ [DeviceRegistrationService] Unlinked device: \(deviceId)")
        #endif
        
        await loadRegisteredDevices()
    }
    
    /// Unlinks all devices except the current one
    func unlinkAllOtherDevices() async throws {
        let others = try await getOtherDevices()
        
        for device in others {
            try await unlinkDevice(device.deviceId)
        }
        
        #if DEBUG
        print("🗑️ [DeviceRegistrationService] Unlinked \(others.count) other devices")
        #endif
    }
    
    /// Cleans up stale devices (not seen in specified number of days)
    func cleanupStaleDevices(olderThan days: Int = 30) async throws {
        let staleDevices = try await getStaleDevices(olderThan: days)
        
        guard !staleDevices.isEmpty else {
            #if DEBUG
            print("✅ [DeviceRegistrationService] No stale devices to cleanup")
            #endif
            return
        }
        
        for device in staleDevices {
            try await unlinkDevice(device.deviceId)
        }
        
        #if DEBUG
        print("🗑️ [DeviceRegistrationService] Cleaned up \(staleDevices.count) stale devices")
        #endif
    }
}

// MARK: - Error Types

enum DeviceRegistrationError: LocalizedError {
    case noModelContext
    case keychainError(OSStatus)
    case encodingFailed
    case deviceNotRegistered
    case deviceNotFound
    
    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "Model context not available"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .encodingFailed:
            return "Failed to encode device ID"
        case .deviceNotRegistered:
            return "Device not registered"
        case .deviceNotFound:
            return "Device not found"
        }
    }
}
