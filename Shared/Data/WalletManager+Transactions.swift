//
//  WalletManager+Transactions.swift
//  Arké
//
//  Transaction operations
//

import Foundation

extension WalletManager {
    
    // MARK: - Transaction Properties
    
    var transactions: [TransactionModel] {
        unifiedTransactionService?.allTransactions ?? []  // Use unified service for merged transactions
    }
    
    /// Ark-only transactions (for debugging/admin views)
    var arkTransactionsOnly: [TransactionModel] {
        transactionService?.transactions ?? []
    }
    
    /// Onchain-only transactions (for debugging/admin views)
    var onchainTransactionsOnly: [OnchainTransactionModel] {
        onchainTransactionService?.onchainTransactions ?? []
    }
    
    var onchainTransactions: [OnchainTransactionModel] {
        onchainTransactionService?.onchainTransactions ?? []
    }
    
    var hasOnchainTransactions: Bool {
        onchainTransactionService?.hasTransactions ?? false
    }
    
    var onchainTransactionCount: Int {
        onchainTransactionService?.transactionCount ?? 0
    }
    
    var transactionServiceInstance: TransactionService? {
        transactionService
    }
    
    var unifiedTransactionServiceInstance: UnifiedTransactionService? {
        unifiedTransactionService
    }
    
    // MARK: - Transaction Operations
    
    /// Update notes for a transaction
    /// - Parameters:
    ///   - txid: The transaction ID to update
    ///   - notes: The notes text to set (nil to clear notes, empty strings are converted to nil)
    /// - Throws: TransactionServiceError if validation fails or transaction not found
    func updateTransactionNotes(for txid: String, notes: String?) async throws {
        guard let transactionService = transactionService else {
            throw BarkErrorArke.commandFailed("Transaction service not initialized")
        }
        try await transactionService.updateNotes(for: txid, notes: notes)
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after notes update")
    }
}
