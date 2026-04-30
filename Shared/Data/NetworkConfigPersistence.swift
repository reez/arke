//
//  NetworkConfigPersistence.swift
//  Arke
//
//  Utility for persisting and loading network configuration across app sessions
//  Ensures the wallet uses the correct network (mainnet, signet, etc.) after restart
//
//  Created by Claude on 4/30/26.
//

import Foundation
import OSLog

/// Manages persistence of network configuration to UserDefaults
/// This ensures the wallet remembers which network it was created on
class NetworkConfigPersistence {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.arke", category: "NetworkConfigPersistence")
    
    /// Save the network configuration ID to UserDefaults
    /// - Parameter networkConfig: The network configuration to persist
    static func save(_ networkConfig: NetworkConfig) {
        UserDefaults.standard.set(networkConfig.id, forKey: UserDefaults.networkConfigKey)
        UserDefaults.standard.synchronize()
        logger.info("Network configuration saved: \(networkConfig.name) (ID: \(networkConfig.id))")
    }
    
    /// Load the saved network configuration from UserDefaults
    /// - Returns: The saved NetworkConfig, or nil if none was saved
    static func load() -> NetworkConfig? {
        guard let savedId = UserDefaults.standard.string(forKey: UserDefaults.networkConfigKey) else {
            logger.info("No saved network configuration found")
            return nil
        }
        
        logger.debug("Found saved network config ID: \(savedId)")
        
        // Try to match against predefined networks
        let predefinedNetworks: [NetworkConfig] = [.mainnet, .signet, .testnet]
        if let matched = predefinedNetworks.first(where: { $0.id == savedId }) {
            logger.info("Loaded saved network configuration: \(matched.name)")
            return matched
        }
        
        // If not found in predefined networks, it might be a custom network
        // For now, we'll log a warning and return nil
        // In the future, you could persist custom network details fully
        logger.warning("Saved network ID '\(savedId)' not found in predefined networks")
        return nil
    }
    
    /// Clear the saved network configuration
    /// Should be called when deleting the wallet
    static func clear() {
        UserDefaults.standard.removeObject(forKey: UserDefaults.networkConfigKey)
        UserDefaults.standard.synchronize()
        logger.info("Network configuration cleared from storage")
    }
    
    /// Check if a network configuration has been saved
    /// - Returns: True if a network config is saved, false otherwise
    static func hasSavedConfig() -> Bool {
        return UserDefaults.standard.string(forKey: UserDefaults.networkConfigKey) != nil
    }
}
