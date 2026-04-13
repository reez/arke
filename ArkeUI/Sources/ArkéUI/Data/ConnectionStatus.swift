//
//  ConnectionStatus.swift
//  Ark wallet prototype
//
//  Created by Christoph on 1/6/26.
//

import Foundation

/// ASP connection quality levels
enum ConnectionQuality: String, Codable, CaseIterable, Sendable {
    case excellent = "excellent"
    case good = "good"
    case poor = "poor"
    case disconnected = "disconnected"
}

extension ConnectionQuality {
    var displayName: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .poor:
            return "Poor"
        case .disconnected:
            return "Disconnected"
        }
    }
    
    var iconName: String {
        switch self {
        case .excellent:
            return "wifi"
        case .good:
            return "wifi"
        case .poor:
            return "wifi.exclamationmark"
        case .disconnected:
            return "wifi.slash"
        }
    }
    
    /// Determine quality from latency (in milliseconds)
    static func from(latencyMs: Double?) -> ConnectionQuality {
        guard let latency = latencyMs else {
            return .disconnected
        }
        
        if latency < 200 {
            return .excellent
        } else if latency < 500 {
            return .good
        } else {
            return .poor
        }
    }
    
    /// Determine quality from time since last successful sync
    static func from(lastSuccessfulSync: Date?) -> ConnectionQuality {
        guard let lastSync = lastSuccessfulSync else {
            return .disconnected
        }
        
        let secondsSinceSync = Date().timeIntervalSince(lastSync)
        
        if secondsSinceSync < 60 {
            return .excellent
        } else if secondsSinceSync < 300 { // 5 minutes
            return .good
        } else if secondsSinceSync < 900 { // 15 minutes
            return .poor
        } else {
            return .disconnected
        }
    }
    
    var canPerformCollaborativeOperations: Bool {
        switch self {
        case .excellent, .good:
            return true
        case .poor:
            return true // Can try, but might be slow
        case .disconnected:
            return false
        }
    }
}

/// Connection status information (not persisted - computed/updated on each refresh)
struct ConnectionStatus: Sendable {
    var isConnected: Bool
    var quality: ConnectionQuality
    var lastSuccessfulSync: Date?
    var reconnectionAttempts: Int
    var lastError: String?
    
    init(
        isConnected: Bool = false,
        quality: ConnectionQuality = .disconnected,
        lastSuccessfulSync: Date? = nil,
        reconnectionAttempts: Int = 0,
        lastError: String? = nil
    ) {
        self.isConnected = isConnected
        self.quality = quality
        self.lastSuccessfulSync = lastSuccessfulSync
        self.reconnectionAttempts = reconnectionAttempts
        self.lastError = lastError
    }
    
    // MARK: - Display Properties
    
    var statusMessage: String {
        if isConnected {
            switch quality {
            case .excellent:
                return "Connected"
            case .good:
                return "Connected"
            case .poor:
                return "Poor connection"
            case .disconnected:
                return "Disconnected"
            }
        } else {
            if reconnectionAttempts > 0 {
                return "Reconnecting... (attempt \(reconnectionAttempts))"
            } else {
                return "Disconnected"
            }
        }
    }
    
    var detailedMessage: String? {
        if let lastSync = lastSuccessfulSync {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return String(localized: "status_last_synced", defaultValue: "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))")
        }
        return nil
    }
    
    var showWarning: Bool {
        return !isConnected || quality == .poor || quality == .disconnected
    }
    
    var canPerformCollaborativeOperations: Bool {
        return isConnected && quality.canPerformCollaborativeOperations
    }
    
    // MARK: - Update Methods
    
    mutating func markConnected(quality: ConnectionQuality = .excellent) {
        self.isConnected = true
        self.quality = quality
        self.lastSuccessfulSync = Date()
        self.reconnectionAttempts = 0
        self.lastError = nil
    }
    
    mutating func markDisconnected(error: String? = nil) {
        self.isConnected = false
        self.quality = .disconnected
        self.lastError = error
    }
    
    mutating func incrementReconnectionAttempt() {
        self.reconnectionAttempts += 1
    }
    
    mutating func updateQuality(from lastSync: Date?) {
        self.quality = ConnectionQuality.from(lastSuccessfulSync: lastSync)
    }
}
