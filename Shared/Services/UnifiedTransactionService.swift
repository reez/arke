//
//  UnifiedTransactionService.swift
//  Arké
//
//  Service that merges transactions from both Ark and onchain sources
//  Provides a unified list for UI consumption with full tag/contact support
//

import Foundation
import SwiftData
import ArkeUI

@MainActor
@Observable
class UnifiedTransactionService {
    // MARK: - Dependencies
    
    private let arkService: TransactionService
    private let onchainService: OnchainTransactionService
    private var modelContext: ModelContext?
    private weak var walletManager: WalletManager?
    
    // MARK: - Published Properties
    
    /// Unified list of all transactions from both sources
    var allTransactions: [TransactionModel] = []
    
    /// Whether any service is currently loading
    var isLoading: Bool = false
    
    /// Combined error from services
    var error: String?
    
    /// Whether transactions have been loaded at least once
    var hasLoadedTransactions: Bool = false
    
    // MARK: - Computed Properties
    
    /// Total number of transactions from both sources
    var transactionCount: Int {
        allTransactions.count
    }
    
    /// Whether there are any transactions
    var hasTransactions: Bool {
        !allTransactions.isEmpty
    }
    
    /// Number of ark-only transactions
    var arkTransactionCount: Int {
        arkService.transactions.count
    }
    
    /// Number of onchain-only transactions
    var onchainTransactionCount: Int {
        onchainService.transactionCount
    }
    
    /// Whether services are currently refreshing
    var isRefreshing: Bool {
        arkService.isRefreshing || onchainService.isLoading
    }
    
    // MARK: - Initialization
    
    init(
        arkService: TransactionService,
        onchainService: OnchainTransactionService,
        walletManager: WalletManager
    ) {
        self.arkService = arkService
        self.onchainService = onchainService
        self.walletManager = walletManager
        
        print("🔗 [UnifiedTxService] Initialized with ark + onchain services")
    }
    
    // MARK: - Public Methods
    
    /// Set the model context for SwiftData operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        print("📦 [UnifiedTxService] ModelContext set")
    }
    
    /// Refresh all transaction sources
    func refreshTransactions() async {
        isLoading = true
        defer { isLoading = false }
        
        print("🔄 [UnifiedTxService] Starting refresh of both sources...")
        
        // Refresh both services in parallel
        async let arkRefresh: () = arkService.refreshTransactions()
        async let onchainRefresh: () = onchainService.refreshTransactions()
        
        await arkRefresh
        await onchainRefresh
        
        // Merge results
        await mergeTransactions()
        
        // Check for errors from services
        if let arkError = arkService.error {
            error = "Ark: \(arkError)"
        } else if let onchainError = onchainService.error {
            error = "Onchain: \(onchainError)"
        } else {
            error = nil
        }
        
        hasLoadedTransactions = true
        
        print("✅ [UnifiedTxService] Refresh complete")
    }
    
    /// Merge transactions from both sources immediately (without refresh)
    func mergeTransactions() async {
        guard let modelContext = modelContext else {
            print("⚠️ [UnifiedTxService] No model context available for merging")
            return
        }
        
        // Get ark transactions (already as TransactionModel)
        let arkTransactions = arkService.transactions
        
        // Convert onchain transactions to TransactionModel
        let onchainTransactions = onchainService.onchainTransactions.compactMap { onchain -> TransactionModel? in
            // Find or create persistent transaction for metadata (tags, contacts, notes)
            let persistent = findOrCreatePersistentOnchainTransaction(
                onchain,
                modelContext: modelContext
            )
            
            // Convert to TransactionModel using adapter
            return convertOnchainToTransactionModel(
                onchain,
                persistent: persistent
            )
        }
        
        // Merge and sort by date (newest first)
        allTransactions = (arkTransactions + onchainTransactions)
            .sorted { $0.date > $1.date }
        
        print("📊 [UnifiedTxService] Merged \(arkTransactions.count) ark + \(onchainTransactions.count) onchain = \(allTransactions.count) total")
    }
    
    /// Get transactions for a specific tag (includes both sources)
    func transactionsForTag(_ tag: PersistentTag) -> [TransactionModel] {
        let filtered = allTransactions.filter { tx in
            tx.associatedTags.contains { $0.id == tag.id }
        }
        
        print("🏷️ [UnifiedTxService] Filtered by tag '\(tag.name)': \(filtered.count) transactions")
        
        return filtered
    }
    
    /// Get transactions for a specific contact (includes both sources)
    func transactionsForContact(_ contact: PersistentContact) -> [TransactionModel] {
        let filtered = allTransactions.filter { tx in
            tx.associatedContacts.contains { $0.id == contact.id }
        }
        
        print("👤 [UnifiedTxService] Filtered by contact '\(contact.cachedName)': \(filtered.count) transactions")
        
        return filtered
    }
    
    /// Get transaction by txid (searches both sources)
    func getTransaction(txid: String) -> TransactionModel? {
        return allTransactions.first { $0.txid == txid }
    }
    
    /// Force a re-merge without refreshing from network
    /// Useful after tag/contact assignments change
    func invalidateAndReMerge() async {
        await mergeTransactions()
    }
    
    // MARK: - Statistics
    
    /// Get statistics about transaction sources
    func getSourceStatistics() -> (ark: Int, onchain: Int, total: Int) {
        return (
            ark: arkTransactionCount,
            onchain: onchainTransactionCount,
            total: transactionCount
        )
    }
    
    /// Get a breakdown of transactions by category
    func getCategoryBreakdown() -> [MovementCategory: Int] {
        var breakdown: [MovementCategory: Int] = [:]
        
        for transaction in allTransactions {
            if let category = transaction.category {
                breakdown[category, default: 0] += 1
            }
        }
        
        return breakdown
    }
    
    // MARK: - Private Helpers
    
    /// Convert OnchainTransactionModel to TransactionModel
    /// - Parameters:
    ///   - onchain: The onchain transaction model from BDK
    ///   - persistent: The linked PersistentTransaction for metadata
    /// - Returns: A TransactionModel compatible with the existing UI
    private func convertOnchainToTransactionModel(
        _ onchain: OnchainTransactionModel,
        persistent: PersistentTransaction
    ) -> TransactionModel {
        
        return TransactionModel(
            txid: "onchain_\(onchain.txid)",  // Namespace to avoid collisions with ark txids
            movementId: nil,  // Onchain transactions don't have movement IDs
            recipientIndex: nil,
            type: onchain.isIncoming ? .received : .sent,
            amount: Int(abs(onchain.netAmount)),
            date: onchain.timestamp ?? Date(),
            status: onchain.isConfirmed ? .confirmed : .pending,
            address: nil,  // BDK doesn't provide recipient address easily
            notes: persistent.notes,
            associatedTags: persistent.associatedTags.map { TagModel(from: $0) },
            associatedContacts: persistent.associatedContacts.map { ContactModel(from: $0) },
            fees: onchain.fee.map { Int($0) },
            onchainFeeSat: onchain.fee.map { Int($0) },  // Same as fees for pure onchain
            subsystemCategory: "onchain_transaction",
            subsystemName: "bitcoin.core",
            subsystemKind: onchain.isIncoming ? "receive" : "send",
            paymentMethodType: "bitcoin",
            paymentHash: nil,
            fundingTxid: nil,
            inputVtxoIds: [],
            outputVtxoIds: [],
            exitedVtxoIds: [],
            category: .onchainTransaction
        )
    }
    
    /// Find existing or create new PersistentTransaction for an onchain transaction
    /// - Parameters:
    ///   - onchain: The onchain transaction model from BDK
    ///   - modelContext: SwiftData context for persistence
    /// - Returns: Existing or newly created PersistentTransaction
    private func findOrCreatePersistentOnchainTransaction(
        _ onchain: OnchainTransactionModel,
        modelContext: ModelContext
    ) -> PersistentTransaction {
        
        let txid = "onchain_\(onchain.txid)"
        
        // Try to find existing persistent transaction
        let descriptor = FetchDescriptor<PersistentTransaction>(
            predicate: #Predicate { $0.txid == txid }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            // Update confirmation data if changed
            updateConfirmationData(existing, from: onchain)
            return existing
        }
        
        // Create new persistent transaction
        let persistent = PersistentTransaction(
            txid: txid,
            movementId: nil,
            type: onchain.isIncoming ? .received : .sent,
            amount: Int(abs(onchain.netAmount)),
            date: onchain.timestamp ?? Date(),
            status: onchain.isConfirmed ? .confirmed : .pending,
            address: nil,
            subsystemCategory: "onchain_transaction"
        )
        
        // Set onchain-specific fields
        persistent.sourceType = "onchain"
        persistent.confirmationHeight = onchain.confirmationTime?.height
        persistent.confirmationCount = onchain.confirmations
        persistent.onchainReceived = onchain.received
        persistent.onchainSent = onchain.sent
        persistent.subsystemName = "bitcoin.core"
        persistent.subsystemKind = onchain.isIncoming ? "receive" : "send"
        persistent.paymentMethodType = "bitcoin"
        
        modelContext.insert(persistent)
        
        // Save immediately to ensure it's available for tag/contact assignment
        try? modelContext.save()
        
        print("📝 [UnifiedTxService] Created PersistentTransaction for onchain tx: \(onchain.shortTxid)")
        
        return persistent
    }
    
    /// Update confirmation data on existing persistent transaction
    /// - Parameters:
    ///   - persistent: The persistent transaction to update
    ///   - onchain: The current onchain transaction data
    private func updateConfirmationData(
        _ persistent: PersistentTransaction,
        from onchain: OnchainTransactionModel
    ) {
        var hasChanges = false
        
        // Update confirmation count if changed
        if persistent.confirmationCount != onchain.confirmations {
            persistent.confirmationCount = onchain.confirmations
            hasChanges = true
        }
        
        // Update confirmation height if changed
        if persistent.confirmationHeight != onchain.confirmationTime?.height {
            persistent.confirmationHeight = onchain.confirmationTime?.height
            hasChanges = true
        }
        
        // Update status if confirmation status changed
        let newStatus = onchain.isConfirmed ? "confirmed" : "pending"
        if persistent.status != newStatus {
            persistent.status = newStatus
            hasChanges = true
        }
        
        // Update timestamp if not set
        if persistent.date == Date() || persistent.date.timeIntervalSince1970 == 0 {
            if let timestamp = onchain.timestamp {
                persistent.date = timestamp
                hasChanges = true
            }
        }
        
        if hasChanges {
            print("🔄 [UnifiedTxService] Updated confirmation data for \(onchain.shortTxid): \(onchain.confirmations) confirmations")
        }
    }
}

// MARK: - Convenience Extensions

extension UnifiedTransactionService {
    /// Get a snapshot of current state for logging/debugging
    func getSnapshot() -> String {
        let stats = getSourceStatistics()
        
        return """
        Unified Transaction Service State:
        - Total: \(stats.total) transactions
        - Ark: \(stats.ark) transactions
        - Onchain: \(stats.onchain) transactions
        - Has loaded: \(hasLoadedTransactions)
        - Is refreshing: \(isRefreshing)
        - Error: \(error ?? "none")
        """
    }
}
