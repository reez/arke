//
//  TransactionModel+OnchainAdapter.swift
//  Arké
//
//  Adapter for converting OnchainTransactionModel to TransactionModel
//  Enables unified transaction display from both Ark and onchain sources
//

import Foundation
import SwiftData
import ArkeUI

extension TransactionModel {
    // MARK: - Onchain Transaction Adapter
    
    /// Create TransactionModel from OnchainTransactionModel
    /// Links to or creates PersistentTransaction for tags/contacts/notes
    /// - Parameters:
    ///   - onchain: The onchain transaction model from BDK
    ///   - persistent: The linked PersistentTransaction for metadata
    ///   - walletManager: Reference to WalletManager for context
    /// - Returns: A TransactionModel compatible with the existing UI
    static func fromOnchain(
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
    
    // MARK: - Persistent Transaction Lookup/Creation
    
    /// Find existing or create new PersistentTransaction for an onchain transaction
    /// - Parameters:
    ///   - onchain: The onchain transaction model from BDK
    ///   - modelContext: SwiftData context for persistence
    /// - Returns: Existing or newly created PersistentTransaction
    static func findOrCreatePersistentOnchainTransaction(
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
        
        print("📝 [OnchainAdapter] Created PersistentTransaction for onchain tx: \(onchain.shortTxid)")
        
        return persistent
    }
    
    // MARK: - Helper Methods
    
    /// Update confirmation data on existing persistent transaction
    /// - Parameters:
    ///   - persistent: The persistent transaction to update
    ///   - onchain: The current onchain transaction data
    private static func updateConfirmationData(
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
            print("🔄 [OnchainAdapter] Updated confirmation data for \(onchain.shortTxid): \(onchain.confirmations) confirmations")
        }
    }
}
