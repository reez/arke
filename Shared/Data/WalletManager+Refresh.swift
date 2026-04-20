//
//  WalletManager+Refresh.swift
//  Arké
//
//  Convenience refresh methods for individual components
//

import Foundation
import Bark

extension WalletManager {
    
    /// Refresh server connection - delegates to wallet
    func refreshServer() async {
        guard let wallet = wallet else {
            print("⚠️ Cannot refresh server: wallet not initialized")
            return
        }
        
        do {
            try await wallet.refreshServer()
        } catch {
            print("⚠️ Failed to refresh server: \(error)")
            self.error = "Failed to refresh server connection: \(error.localizedDescription)"
        }
    }
    
    /// Refresh just Ark balance - delegates to balance service
    func refreshArkBalance() async {
        await balanceService?.refreshArkBalance()
        // Update local error state if balance service encountered an error
        if let balanceError = balanceService?.error {
            self.error = balanceError
        }
    }
    
    /// Refresh just onchain balance - delegates to balance service
    func refreshOnchainBalance() async {
        await balanceService?.refreshOnchainBalance()
        // Update local error state if balance service encountered an error
        if let balanceError = balanceService?.error {
            self.error = balanceError
        }
    }
    
    /// Load wallet addresses
    func loadAddresses() async {
        await addressService?.loadAddresses()
        // Update local error state if address service encountered an error
        if let addressError = addressService?.error {
            self.error = addressError
        }
    }
    
    /// Generate a new address
    func generateNewAddress(type: AddressType, strategy: AddressGenerationStrategy = .userRequested) async throws -> PersistentAddress {
        guard let addressService = addressService else {
            throw BarkErrorArke.commandFailed("Address service not available")
        }
        return try await addressService.generateNewAddress(type: type, strategy: strategy)
    }
    
    /// Get estimated block height, fetching cached data if needed
    func getEstimatedBlockHeight() async -> Int? {
        // Ensure we have both cached block height and ark info
        if cacheManager.blockHeight.value == nil {
            do {
                _ = try await getLatestBlockHeight()
            } catch {
                print("⚠️ Failed to fetch block height for estimation: \(error)")
            }
        }
        
        // Cache ArkInfo if needed using balance service
        if cacheManager.arkInfo.value == nil {
            await balanceService?.cacheArkInfoIfNeeded()
        }
        
        return cacheManager.getEstimatedBlockHeight()
    }
    
    /// Refresh data after round completion (balances and transactions)
    func refreshAfterRoundCompletion() async {
        await balanceService?.refreshAfterTransaction()
        await transactionService?.refreshTransactions()
    }
    
    /// Refresh balances (called by notification service on channel lagging)
    func refreshBalances() async {
        await balanceService?.refreshBalances()
    }
}
