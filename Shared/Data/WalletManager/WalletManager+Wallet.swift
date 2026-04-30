//
//  WalletManager+Wallet.swift
//  Arké
//
//  Wallet lifecycle operations
//  Create, import, delete, and mnemonic management
//

import Foundation

extension WalletManager {
    
    // MARK: - Mnemonic Management
    
    /// Get the wallet's mnemonic phrase from secure storage
    /// Biometric authentication is currently disabled
    func getMnemonic() async throws -> String {
        // Biometric authentication disabled for now
        // TODO: Re-enable biometric authentication when ready
        // let authenticated = try await securityService.authenticateUser(
        //     reason: "Access your wallet recovery phrase"
        // )
        //
        // guard authenticated else {
        //     throw BarkErrorArke.commandFailed("Authentication failed")
        // }
        
        // Load from secure keychain through SecurityService
        guard let mnemonic = try securityService.loadMnemonic() else {
            throw BarkErrorArke.commandFailed("Mnemonic not found in keychain")
        }
        
        return mnemonic
    }
    
    // MARK: - Wallet Import
    
    /// Import an existing wallet using a mnemonic phrase
    /// Validates the mnemonic and saves it to secure storage
    /// - Parameters:
    ///   - mnemonic: The BIP39 mnemonic phrase to import
    ///   - networkConfig: Optional network configuration. If nil, uses wallet's current networkConfig.
    func importWallet(mnemonic: String, networkConfig: NetworkConfig? = nil) async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        
        let trimmedMnemonic = mnemonic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMnemonic.isEmpty else {
            throw BarkErrorArke.commandFailed("Mnemonic phrase cannot be empty")
        }
        
        // Validate the mnemonic using SecurityService
        let validation = await securityService.validateMnemonic(trimmedMnemonic)
        
        switch validation {
        case .valid:
            // Mnemonic matches hash in SwiftData - this is a recovery
            print("✅ Mnemonic is valid and matches existing wallet hash - recovering wallet")
            
        case .validNoReference:
            // Valid BIP39 but no reference hash exists - this is a first import
            print("✅ Mnemonic is valid, proceeding with first-time import")
            
        case .invalid:
            throw BarkErrorArke.commandFailed("Invalid mnemonic phrase - doesn't match your wallet")
            
        case .invalidFormat:
            throw BarkErrorArke.commandFailed("Invalid mnemonic format - must be 12, 15, 18, 21, or 24 words")
        }
        
        // Use provided networkConfig or fall back to wallet's current config
        let config = networkConfig ?? wallet.networkConfig
        
        // Import the wallet
        let result = try await wallet.importWallet(
            network: config.networkType,
            arkServer: config.arkServerBaseURL,
            mnemonic: trimmedMnemonic
        )
        
        // Update the wallet's network configuration to match what was actually imported
        wallet.updateNetworkConfig(config)
        
        // Persist the network configuration so it's restored on next app launch
        NetworkConfigPersistence.save(config)
        
        // Save mnemonic to keychain and update device registration
        // Note: This also saves hash to NSUbiquitousKeyValueStore for cross-device detection
        do {
            try await securityService.handleSeedImport(trimmedMnemonic)
            print("✅ Mnemonic saved to keychain and device updated")
        } catch {
            print("⚠️ Failed to save mnemonic to keychain: \(error)")
            throw BarkErrorArke.commandFailed("Failed to secure mnemonic: \(error.localizedDescription)")
        }
        
        isInitialized = true
        
        // Start background progression services for imported wallet
        exitProgressionService?.start()
        roundProgressionService?.start()
        lightningClaimService?.start()
        
        // Start wallet notification service
        if let transactionService = transactionService {
            walletNotificationService?.setTransactionService(transactionService)
            walletNotificationService?.start()
        }
        
        return result
    }
    
    // MARK: - Wallet Creation
    
    /// Create a new wallet with a randomly generated mnemonic
    /// Saves the mnemonic to secure storage and syncs hash via iCloud KVS
    /// - Parameters:
    ///   - networkConfig: Optional network configuration. If nil, uses wallet's current networkConfig.
    func createWallet(networkConfig: NetworkConfig? = nil) async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        
        print("WalletManager.createWallet name: \(networkConfig?.name ?? "none")")
        print("WalletManager.createWallet arkServerBaseURL: \(networkConfig?.arkServerBaseURL ?? "none")")
        print("WalletManager.createWallet esploraBaseURL: \(networkConfig?.esploraBaseURL ?? "none")")
        
        // Execute creation through task manager for deduplication
        return try await taskManager.execute(key: "createWallet") {
            // Use provided networkConfig or fall back to wallet's current config
            let config = networkConfig ?? wallet.networkConfig
            
            // Update the wallet's network configuration to match what was actually created
            wallet.updateNetworkConfig(config)
            
            // Persist the network configuration so it's restored on next app launch
            NetworkConfigPersistence.save(config)
            
            let mnemonic = try await wallet.createWallet(
                network: config.networkType,
                arkServer: config.arkServerBaseURL
            )
            
            print("✅ New wallet created successfully on \(config.name)")
            
            // Save mnemonic to keychain (this also saves hash to NSUbiquitousKeyValueStore)
            do {
                try await self.securityService.saveMnemonic(mnemonic, requireBiometric: false)
                print("✅ Mnemonic saved to keychain and hash synced via iCloud KVS")
            } catch {
                print("⚠️ Failed to save mnemonic to keychain: \(error)")
                throw BarkErrorArke.commandFailed("Failed to secure mnemonic: \(error.localizedDescription)")
            }
            
            self.isInitialized = true
            
            // Start background progression services for new wallet
            self.exitProgressionService?.start()
            self.roundProgressionService?.start()
            self.lightningClaimService?.start()
            
            // Start wallet notification service
            if let transactionService = self.transactionService {
                self.walletNotificationService?.setTransactionService(transactionService)
                self.walletNotificationService?.start()
            }
            
            return mnemonic
        }
    }
    
    // MARK: - Wallet Deletion
    
    /// Delete the current wallet and reset all manager state
    /// Note: Mnemonic deletion is handled separately by the caller (DeleteWalletSettingView)
    /// to allow for intelligent deletion strategies based on device registry
    func deleteWallet() async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        
        // Execute deletion through task manager for deduplication
        return try await taskManager.execute(key: "deleteWallet") {
            print("🗑️ [WalletManager] Starting wallet deletion...")
            
            // ✅ NEW: Reset manager state FIRST to prevent any operations during deletion
            print("   Step 1: Resetting manager state...")
            await self.resetManagerState()
            
            // ✅ Unregister from push notifications before deletion
            #if os(iOS)
            print("   Step 2: Unregistering from push notifications...")
            await self.unregisterFromPushNotifications()
            #endif
            
            // ✅ NEW: Give services time to release any resources
            print("   Step 3: Waiting for services to settle...")
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // Now delete the wallet (this handles FFI cleanup internally)
            print("   Step 4: Deleting wallet files...")
            let result = try await wallet.deleteWallet()
            
            // Clear the saved network configuration
            print("   Step 5: Clearing saved network configuration...")
            NetworkConfigPersistence.clear()
            
            // Note: Mnemonic deletion is now handled by the caller (DeleteWalletSettingView)
            // This allows for intelligent deletion strategies based on device registry
            
            print("✅ Wallet deleted and manager state reset")
            return result
        }
    }
    
    // MARK: - Private Helpers
    
    /// Reset all manager and service state after wallet deletion
    /// Clears all cached data, stops background services, and resets flags
    private func resetManagerState() async {
        // Stop all background services
        exitProgressionService?.stop()
        roundProgressionService?.stop()
        vtxoRefreshService?.stop()
        lightningClaimService?.stop()
        walletNotificationService?.stop()
        
        // Reset coordinator state
        isInitialized = false
        error = nil
        isRefreshing = false
        hasLoadedOnce = false
        
        // Reset balance service state
        balanceService?.arkBalance = nil
        balanceService?.onchainBalance = nil
        balanceService?.totalBalance = nil
        balanceService?.error = nil
        
        // Reset transaction service state (clear transactions)
        await transactionService?.clearTransactionModels()
        transactionService?.error = nil
        transactionService?.hasLoadedTransactions = false
        
        // Reset address service state
        addressService?.arkAddress = ""
        addressService?.onchainAddress = ""
        addressService?.error = nil
        
        // Clear persisted balance data
        balanceService?.resetBalances()
        
        print("🔄 All manager and service state reset")
    }
}
