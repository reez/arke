//
//  UserSettings.swift
//  Arké
//
//  Created by Claude on 2/6/26.
//

import Foundation

/// Centralized UserDefaults keys for user preferences
extension UserDefaults {
    /// Key for storing balance privacy preference (hide/show balance)
    static let balancePrivacyKey = "balancePrivacyEnabled"
    
    /// Key for storing the network configuration ID (mainnet, signet, etc.)
    static let networkConfigKey = "com.arke.wallet.networkConfigId"
    
    /// Key for storing notifications enabled preference
    static let notificationsEnabledKey = "notifications_enabled"
    
    /// Key for storing proximity sharing permission
    static let proximityPermissionKey = "hasGrantedProximityPermission"
}
