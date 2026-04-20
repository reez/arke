//
//  WalletManager+Data.swift
//  Arké
//
//  Data retrieval operations - balances, transactions, block height
//

import Foundation

extension WalletManager {
    
    func getLatestBlockHeight() async throws -> Int {
        return try await getBlockHeightWithDeduplication()
    }
    
    private func getBlockHeightWithDeduplication() async throws -> Int {
        // Check cache first
        if let cached = cacheManager.blockHeight.value {
            print("📦 Using cached block height: \(cached)")
            return cached
        }
        
        return try await taskManager.execute(key: "blockHeight") {
            guard let wallet = self.wallet else {
                throw BarkErrorArke.commandFailed("Wallet not initialized")
            }
            let result = try await wallet.getLatestBlockHeight()
            
            // Update cache
            self.cacheManager.blockHeight.setValue(result)
            print("🔗 Fetched latest block height: \(result)")
            
            return result
        }
    }


    func getTransactions() async throws -> String {
        return try await transactionService?.getTransactions() ?? ""
    }
    
    /// Get the current Ark balance response - delegates to balance service
    func getArkBalance() async throws -> ArkBalanceResponse {
        guard let balanceService = balanceService else {
            throw BarkErrorArke.commandFailed("Balance service not initialized")
        }
        
        return try await balanceService.getArkBalance()
    }
    
    /// Get the current onchain balance response - delegates to balance service
    func getOnchainBalance() async throws -> OnchainBalanceResponse {
        guard let balanceService = balanceService else {
            throw BarkErrorArke.commandFailed("Balance service not initialized")
        }
        return try await balanceService.getOnchainBalance()
    }
    
    /// Get onchain transactions from the BDK wallet - delegates to onchain transaction service
    func getOnchainTransactions() async throws -> [OnchainTransactionModel] {
        guard let service = onchainTransactionService else {
            throw BarkErrorArke.commandFailed("Onchain transaction service not initialized")
        }
        return try await service.getTransactions()
    }
    
    /// Refresh onchain transactions
    func refreshOnchainTransactions() async {
        await onchainTransactionService?.refreshTransactions()
    }
}
