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
    
    /// Pending registration (for lazy registration pattern)
    private var pendingRegistration: (hash: String, hasSeed: Bool)?
    
    // MARK: - Initialization
    
    init(taskManager: TaskDeduplicationManager) {
        self.taskManager = taskManager
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        
        // Load registered devices
        Task {
            await loadRegisteredDevices()
            await processPendingRegistrations()
        }
    }
    
    // MARK: - Lazy Registration Pattern
    
    /// Schedules a device registration to occur when ModelContext becomes available
    /// Use this when you need to register a device but ModelContext might not be ready yet
    func schedulePendingRegistration(walletHash: String, hasSeed: Bool) {
        pendingRegistration = (hash: walletHash, hasSeed: hasSeed)
        
        #if DEBUG
        print("📅 [DeviceRegistrationService] Scheduled pending registration (hasSeed=\(hasSeed))")
        #endif
    }
    
    /// Processes any pending registrations (called after ModelContext is set)
    private func processPendingRegistrations() async {
        guard let pending = pendingRegistration else { return }
        
        pendingRegistration = nil
        
        do {
            try await registerCurrentDevice(
                walletHash: pending.hash,
                hasSeed: pending.hasSeed
            )
            
            #if DEBUG
            print("✅ [DeviceRegistrationService] Processed pending registration")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ [DeviceRegistrationService] Pending registration failed: \(error)")
            #endif
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
        // Use model name instead of user-assigned name (which requires special entitlement)
        return getDeviceModelName()
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Unknown Device"
        #endif
    }
    
    /// Gets a user-friendly device model name (e.g., "iPhone 15 Pro")
    private func getDeviceModelName() -> String {
        #if os(iOS)
        guard let identifier = getDeviceModelIdentifier() else {
            return UIDevice.current.model // Fallback to generic "iPhone", "iPad", etc.
        }
        
        // Map common identifiers to friendly names
        // Note: This list should be updated periodically with new models
        let modelMap: [String: String] = [
            // iPhone 15 series
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            
            // iPhone 14 series
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            
            // iPhone 13 series
            "iPhone14,5": "iPhone 13",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            
            // iPhone 12 series
            "iPhone13,2": "iPhone 12",
            "iPhone13,1": "iPhone 12 mini",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            
            // iPhone SE
            "iPhone14,6": "iPhone SE (3rd gen)",
            "iPhone12,8": "iPhone SE (2nd gen)",
            
            // iPad Pro
            "iPad14,3": "iPad Pro 11\" (4th gen)",
            "iPad14,4": "iPad Pro 11\" (4th gen)",
            "iPad14,5": "iPad Pro 12.9\" (6th gen)",
            "iPad14,6": "iPad Pro 12.9\" (6th gen)",
            
            // iPad Air
            "iPad13,16": "iPad Air (5th gen)",
            "iPad13,17": "iPad Air (5th gen)",
            
            // iPad
            "iPad13,18": "iPad (10th gen)",
            "iPad13,19": "iPad (10th gen)",
            
            // iPad mini
            "iPad14,1": "iPad mini (6th gen)",
            "iPad14,2": "iPad mini (6th gen)"
        ]
        
        // Return friendly name if found, otherwise return the identifier
        return modelMap[identifier] ?? identifier
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
                // Note: isPrimaryDevice is preserved - don't change it on update
                
                #if DEBUG
                print("✅ [DeviceRegistrationService] Updated existing device registration")
                #endif
            } else {
                // Check if this is the first device being registered for this wallet
                let walletDevicesDescriptor = FetchDescriptor<DeviceRegistration>(
                    predicate: #Predicate { $0.walletHash == walletHash }
                )
                let existingDevicesCount = (try? modelContext.fetch(walletDevicesDescriptor).count) ?? 0
                let isFirstDevice = existingDevicesCount == 0
                
                // Create new registration
                // First device becomes primary automatically
                let registration = DeviceRegistration(
                    deviceId: deviceId,
                    deviceName: deviceName,
                    platform: platform,
                    walletHash: walletHash,
                    hasSeed: hasSeed,
                    isPrimaryDevice: isFirstDevice,
                    deviceModelIdentifier: modelIdentifier
                )
                
                modelContext.insert(registration)
                
                #if DEBUG
                print("✅ [DeviceRegistrationService] Created new device registration (isPrimary=\(isFirstDevice))")
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
    
    /// Gets the primary device for the wallet
    func getPrimaryDevice() async throws -> DeviceRegistration? {
        guard let modelContext = modelContext else {
            throw DeviceRegistrationError.noModelContext
        }
        
        let descriptor = FetchDescriptor<DeviceRegistration>(
            predicate: #Predicate { $0.isPrimaryDevice == true && $0.isActive == true }
        )
        
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Checks if the current device is the primary device
    func isCurrentDevicePrimary() async throws -> Bool {
        let currentDevice = try await getCurrentDevice()
        return currentDevice?.isPrimaryDevice ?? false
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
    
    /// Migrates primary device status to the current device
    /// Sets current device as primary and removes primary status from all other devices
    func migrateToThisDevice() async throws {
        guard let modelContext = modelContext else {
            throw DeviceRegistrationError.noModelContext
        }
        
        let currentDeviceId = try getOrCreateDeviceId()
        
        // Get all devices for this wallet
        let currentDevice = try await getCurrentDevice()
        guard let walletHash = currentDevice?.walletHash else {
            throw DeviceRegistrationError.deviceNotRegistered
        }
        
        let descriptor = FetchDescriptor<DeviceRegistration>(
            predicate: #Predicate { $0.walletHash == walletHash }
        )
        
        let allDevices = try modelContext.fetch(descriptor)
        
        // Update all devices: current becomes primary, others become secondary
        for device in allDevices {
            if device.deviceId == currentDeviceId {
                device.isPrimaryDevice = true
                #if DEBUG
                print("✅ [DeviceRegistrationService] Set current device as primary")
                #endif
            } else if device.isPrimaryDevice {
                device.isPrimaryDevice = false
                #if DEBUG
                print("📱 [DeviceRegistrationService] Removed primary status from device: \(device.deviceName)")
                #endif
            }
        }
        
        try modelContext.save()
        await loadRegisteredDevices()
        
        #if DEBUG
        print("✅ [DeviceRegistrationService] Migration complete - this device is now primary")
        #endif
    }
    
    // MARK: - Manual Primary Device Assignment
    
    /// Demote this device from primary to secondary
    /// User must then promote another device to complete migration
    func demoteThisDevice() async throws {
        // 1. Verify we are currently primary
        guard try await isCurrentDevicePrimary() else {
            throw MigrationError.notPrimaryDevice
        }

        // 2. Get current device
        guard let currentDevice = try await getCurrentDevice() else {
            throw MigrationError.deviceNotFound
        }

        // 3. CRITICAL: Backup wallet state to iCloud BEFORE demotion
        // This ensures the new primary has the latest wallet state
        // Note: The actual backup will be triggered by WalletManager's closeWalletForMigration()
        // which is called when it receives the deviceDemotedFromPrimary notification
        print("📦 [DeviceRegistrationService] Backup will occur during wallet closure")

        // 4. Update current device to be secondary
        currentDevice.isPrimaryDevice = false
        currentDevice.demotedAt = Date()

        // 5. Save to CloudKit
        try modelContext?.save()

        // 6. Update iCloud KV Store for faster sync
        let kvStore = NSUbiquitousKeyValueStore.default
        kvStore.set(false, forKey: "device_\(currentDevice.deviceId)_isPrimary")
        kvStore.synchronize()

        // 7. Set local UserDefaults flag for instant detection on next launch
        UserDefaults.standard.set(true, forKey: "device_\(currentDevice.deviceId)_wasDemoted")

        // 8. Signal to WalletManager to close wallet immediately
        NotificationCenter.default.post(name: .deviceDemotedFromPrimary, object: nil)

        print("✅ [DeviceRegistrationService] Device demoted to secondary")
        
        // 9. Notify that there's no primary device now
        NotificationCenter.default.post(name: .showNoPrimaryDeviceBanner, object: nil)
    }

    /// Promote this device from secondary to primary
    /// Should only be called when no other primary device exists
    func promoteThisDeviceToPrimary() async throws {
        // 1. Get current device
        guard let currentDevice = try await getCurrentDevice() else {
            throw MigrationError.deviceNotFound
        }
        
        // 2. Verify we are NOT currently primary
        guard !currentDevice.isPrimaryDevice else {
            throw MigrationError.alreadyPrimary
        }
        
        // 3. Check if another primary device already exists
        let existingPrimary = try await getPrimaryDevice()
        if existingPrimary != nil {
            throw MigrationError.primaryDeviceAlreadyExists
        }

        // 4. Update current device to be primary
        currentDevice.isPrimaryDevice = true
        currentDevice.becamePrimaryAt = Date()

        // 5. Save to CloudKit
        try modelContext?.save()

        // 6. Update iCloud KV Store for faster sync
        let kvStore = NSUbiquitousKeyValueStore.default
        kvStore.set(true, forKey: "device_\(currentDevice.deviceId)_isPrimary")
        kvStore.synchronize()

        // 7. Clear any demotion flags
        UserDefaults.standard.removeObject(forKey: "device_\(currentDevice.deviceId)_wasDemoted")

        // 8. Signal to WalletManager to initialize as primary
        // WalletManager's observeMigrationNotifications() handler will:
        // - Call initialize(forceReadOnly: false)
        // - Which triggers initializePrimaryMode() to:
        //   * Open the wallet
        //   * Restore from backup if needed
        //   * Load all wallet data
        //   * Start all background services (exit, round, vtxo progression)
        //   * Start wallet notification service
        //   * Register for push notifications
        NotificationCenter.default.post(name: .devicePromotedToPrimary, object: nil)

        print("✅ [DeviceRegistrationService] Device promoted to primary")
    }

    /// Check if there is currently no primary device
    /// Returns true if no active device has isPrimaryDevice = true
    func checkForNoPrimaryDevice() async throws -> Bool {
        guard let modelContext = modelContext else {
            throw DeviceRegistrationError.noModelContext
        }

        let descriptor = FetchDescriptor<DeviceRegistration>(
            predicate: #Predicate { $0.isPrimaryDevice == true && $0.isActive == true }
        )

        let primaryDevices = try modelContext.fetch(descriptor)
        return primaryDevices.isEmpty
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

enum MigrationError: LocalizedError {
    case notPrimaryDevice
    case alreadyPrimary
    case deviceNotFound
    case cloudKitSyncFailed
    case backupFailed
    case primaryDeviceAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .notPrimaryDevice:
            return "This device is not currently primary"
        case .alreadyPrimary:
            return "This device is already primary"
        case .deviceNotFound:
            return "Could not find current device"
        case .cloudKitSyncFailed:
            return "Failed to sync with iCloud"
        case .backupFailed:
            return "Failed to backup wallet"
        case .primaryDeviceAlreadyExists:
            return "Another device is already set as primary. Demote that device first before promoting this one."
        }
    }
}
