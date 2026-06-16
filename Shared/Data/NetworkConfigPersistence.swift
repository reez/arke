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

/// Manages persistence of network configuration to iCloud Key-Value Store and UserDefaults
/// Uses iCloud KV Store for cross-device sync and reinstall persistence
/// Uses UserDefaults as a fast local cache
class NetworkConfigPersistence {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.arke", category: "NetworkConfigPersistence")
    private static let kvStore = NSUbiquitousKeyValueStore.default
    private static let iCloudKey = "com.arke.wallet.networkConfigId"
    
    /// Save the network configuration ID to both iCloud and UserDefaults
    /// - Parameter networkConfig: The network configuration to persist
    static func save(_ networkConfig: NetworkConfig) {
        // Save to iCloud (survives reinstalls and syncs across devices)
        kvStore.set(networkConfig.id, forKey: iCloudKey)
        kvStore.synchronize()
        
        // Save to UserDefaults (fast local cache)
        UserDefaults.standard.set(networkConfig.id, forKey: UserDefaults.networkConfigKey)
        UserDefaults.standard.synchronize()
        
        logger.info("Network configuration saved: \(networkConfig.name) (ID: \(networkConfig.id))")
    }
    
    /// Load the saved network configuration with priority: iCloud → UserDefaults → mainnet default
    /// - Returns: The saved NetworkConfig, or mainnet as default
    static func load() -> NetworkConfig {
        // 1. Try iCloud first (survives reinstalls)
        if let iCloudId = kvStore.string(forKey: iCloudKey) {
            logger.debug("Found network config in iCloud: \(iCloudId)")
            if let config = findConfig(byId: iCloudId) {
                // Sync to UserDefaults cache for fast access
                UserDefaults.standard.set(iCloudId, forKey: UserDefaults.networkConfigKey)
                logger.info("Loaded network configuration from iCloud: \(config.name)")
                return config
            }
        }
        
        // 2. Fall back to UserDefaults (backward compatibility)
        if let localId = UserDefaults.standard.string(forKey: UserDefaults.networkConfigKey) {
            logger.debug("Found network config in UserDefaults: \(localId)")
            if let config = findConfig(byId: localId) {
                // Migrate to iCloud
                kvStore.set(localId, forKey: iCloudKey)
                kvStore.synchronize()
                logger.info("Loaded network configuration from UserDefaults: \(config.name) (migrated to iCloud)")
                return config
            }
        }
        
        // 3. Default to mainnet (not signet)
        logger.info("No saved config found, using default: \(NetworkConfig.mainnet.name)")
        return .mainnet
    }
    
    /// Find a network configuration by ID
    /// - Parameter id: The network configuration ID
    /// - Returns: The matching NetworkConfig, or nil if not found
    private static func findConfig(byId id: String) -> NetworkConfig? {
        let predefinedNetworks: [NetworkConfig] = [.mainnet, .signet, .testnet]
        if let matched = predefinedNetworks.first(where: { $0.id == id }) {
            return matched
        }
        
        // If not found in predefined networks, it might be a custom network
        // For now, we'll log a warning and return nil
        // In the future, you could persist custom network details fully
        logger.warning("Network ID '\(id)' not found in predefined networks")
        return nil
    }
    
    /// Clear the saved network configuration from both iCloud and UserDefaults
    /// Should be called when deleting the wallet
    static func clear() {
        kvStore.removeObject(forKey: iCloudKey)
        kvStore.synchronize()
        
        UserDefaults.standard.removeObject(forKey: UserDefaults.networkConfigKey)
        UserDefaults.standard.synchronize()
        
        logger.info("Network configuration cleared from storage")
    }
    
    /// Check if a network configuration has been saved in either location
    /// - Returns: True if a network config is saved, false otherwise
    static func hasSavedConfig() -> Bool {
        return kvStore.string(forKey: iCloudKey) != nil || 
               UserDefaults.standard.string(forKey: UserDefaults.networkConfigKey) != nil
    }
}
