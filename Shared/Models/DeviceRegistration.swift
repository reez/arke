//
//  DeviceRegistration.swift
//  Arké
//
//  Created by Christoph on 12/04/25.
//

import SwiftData
import Foundation

/// Represents a device that has the wallet installed
/// Syncs via CloudKit to enable cross-device awareness and management
@Model
class DeviceRegistration {
    // MARK: - Identity
    
    /// SwiftData identifier
    var id: UUID = UUID()
    
    /// Stable device identifier from Keychain (ThisDeviceOnly, never syncs)
    /// Each physical device has a unique ID that survives app reinstall
    var deviceId: String = ""
    
    /// User-facing device name (e.g., "Christoph's iPhone")
    var deviceName: String = ""
    
    /// Platform this device is running on
    var platform: String = DevicePlatform.current.rawValue  // Stored as String for Codable compatibility
    
    // MARK: - Wallet Association
    
    /// Hash of the wallet this device is associated with
    /// Links to WalletConfiguration.mnemonicHash
    var walletHash: String = ""
    
    /// Whether this device has the seed phrase stored locally
    /// true = full wallet, false = metadata-only device
    var hasSeed: Bool = false
    
    /// Whether this device is the primary device (allowed to open wallet and sync with ASP)
    /// Only one device can be primary at a time
    /// Primary device has exclusive access to wallet operations
    var isPrimaryDevice: Bool = false
    
    // MARK: - Lifecycle Tracking
    
    /// When this device was first registered
    var registeredAt: Date = Date()
    
    /// Last time this device was seen (heartbeat)
    /// Used for staleness detection (devices inactive >30 days)
    var lastSeenAt: Date = Date()
    
    /// App version when last seen (for debugging/support)
    var lastAppVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    // MARK: - Status
    
    /// Whether this device is actively linked
    /// Can be set to false to manually unlink without deleting
    var isActive: Bool = true
    
    /// Device model identifier (e.g., "iPhone15,3" or "Mac14,2")
    /// Optional for privacy/debugging purposes
    var deviceModelIdentifier: String?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        deviceId: String,
        deviceName: String,
        platform: DevicePlatform,
        walletHash: String,
        hasSeed: Bool,
        isPrimaryDevice: Bool = false,
        registeredAt: Date = Date(),
        lastSeenAt: Date = Date(),
        lastAppVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
        isActive: Bool = true,
        deviceModelIdentifier: String? = nil
    ) {
        self.id = id
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.platform = platform.rawValue
        self.walletHash = walletHash
        self.hasSeed = hasSeed
        self.isPrimaryDevice = isPrimaryDevice
        self.registeredAt = registeredAt
        self.lastSeenAt = lastSeenAt
        self.lastAppVersion = lastAppVersion
        self.isActive = isActive
        self.deviceModelIdentifier = deviceModelIdentifier
    }
    
    // MARK: - Computed Properties
    
    /// Returns the platform as a typed enum
    var devicePlatform: DevicePlatform {
        DevicePlatform(rawValue: platform) ?? .iOS
    }
    
    /// Human-readable time since last seen (e.g., "2 hours ago", "3 days ago")
    var lastSeenRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSeenAt, relativeTo: Date())
    }
    
    /// Whether this device is considered stale (not seen in 30+ days)
    var isStale: Bool {
        isStale(threshold: 30)
    }
    
    /// Check if device is stale with custom threshold
    func isStale(threshold days: Int) -> Bool {
        let threshold = TimeInterval(days * 24 * 60 * 60)
        return Date().timeIntervalSince(lastSeenAt) > threshold
    }
    
    /// Platform display name
    var platformDisplayName: String {
        devicePlatform.displayName
    }
    
    /// Platform emoji icon
    var platformIcon: String {
        devicePlatform.icon
    }
    
    /// Status summary (for UI display)
    var statusSummary: String {
        if !isActive {
            return "Unlinked"
        } else if isStale {
            return "Stale"
        } else if isPrimaryDevice {
            return "Primary Device"
        } else if hasSeed {
            return "Full Wallet"
        } else {
            return "Metadata Only"
        }
    }
}

// MARK: - Supporting Types

/// Platform enum for device types
enum DevicePlatform: String, Codable, CaseIterable {
    case iOS = "iOS"
    case macOS = "macOS"
    
    var displayName: String {
        switch self {
        case .iOS: return "iOS"
        case .macOS: return "macOS"
        }
    }
    
    var icon: String {
        switch self {
        case .iOS: return "📱"
        case .macOS: return "💻"
        }
    }
    
    /// Detects current platform at runtime
    static var current: DevicePlatform {
        #if os(iOS)
        return .iOS
        #elseif os(macOS)
        return .macOS
        #else
        return .iOS  // Fallback
        #endif
    }
}
