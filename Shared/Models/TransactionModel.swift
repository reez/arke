//
//  TransactionModel.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/23/25.
//

import Foundation

struct TransactionModel: Identifiable, Hashable, Codable {
    let txid: String  // Primary stable identifier
    let movementId: Int?  // Server movement ID for grouping
    let recipientIndex: Int?  // For tracking multiple recipients in same movement
    let type: TransactionTypeEnum
    let amount: Int  // Amount in satoshis
    let date: Date
    let status: TransactionStatusEnum
    let address: String?  // Recipient address for sends, nil for receives
    let notes: String?  // User-added notes for this transaction (max 1000 characters)
    let fees: Int?  // Offchain transaction fees in satoshis (proportionally allocated for multi-recipient sends)
    let onchainFeeSat: Int?  // Bitcoin network fees (for onchain operations like boarding)
    
    // Enhanced metadata fields (Phase 4)
    let subsystemCategory: String?  // Movement category (e.g., "lightning_send", "offchain_transfer")
    let subsystemName: String?  // Subsystem name from server (e.g., "bark.arkoor", "bark.offboard")
    let subsystemKind: String?  // Subsystem kind from server (e.g., "send", "receive", "send_onchain")
    let paymentMethodType: String?  // Payment method type (e.g., "invoice", "bitcoin", "ark")
    let paymentHash: String?  // Lightning payment hash identifier
    let fundingTxid: String?  // Round funding transaction ID
    
    // VTXO ID tracking
    let inputVtxoIds: [String]  // VTXOs consumed in this transaction
    let outputVtxoIds: [String]  // VTXOs created by this transaction
    let exitedVtxoIds: [String]  // VTXOs forced into unilateral exit
    
    // Associated tags and contacts (full objects for UI convenience)
    let associatedTags: [TagModel]
    let associatedContacts: [ContactModel]
    
    // Movement category for enhanced display
    let category: MovementCategory?
    
    init(txid: String, movementId: Int?, recipientIndex: Int? = nil, type: TransactionTypeEnum,
         amount: Int, date: Date, status: TransactionStatusEnum, address: String?, notes: String? = nil,
         associatedTags: [TagModel] = [], associatedContacts: [ContactModel] = [], fees: Int? = nil,
         onchainFeeSat: Int? = nil, subsystemCategory: String? = nil, subsystemName: String? = nil,
         subsystemKind: String? = nil, paymentMethodType: String? = nil,
         paymentHash: String? = nil, fundingTxid: String? = nil,
         inputVtxoIds: [String] = [], outputVtxoIds: [String] = [], 
         exitedVtxoIds: [String] = [], category: MovementCategory? = nil) {
        self.txid = txid
        self.movementId = movementId
        self.recipientIndex = recipientIndex
        self.type = type
        self.amount = amount
        self.date = date
        self.status = status
        self.address = address
        self.notes = notes
        self.associatedTags = associatedTags
        self.associatedContacts = associatedContacts
        self.fees = fees
        self.onchainFeeSat = onchainFeeSat
        self.subsystemCategory = subsystemCategory
        self.subsystemName = subsystemName
        self.subsystemKind = subsystemKind
        self.paymentMethodType = paymentMethodType
        self.paymentHash = paymentHash
        self.fundingTxid = fundingTxid
        self.inputVtxoIds = inputVtxoIds
        self.outputVtxoIds = outputVtxoIds
        self.exitedVtxoIds = exitedVtxoIds
        self.category = category
    }
    
    // MARK: - Initialize from PersistentTransaction
    
    init(from persistentTransaction: PersistentTransaction) {
        self.txid = persistentTransaction.txid
        self.movementId = persistentTransaction.movementId
        self.recipientIndex = persistentTransaction.recipientIndex
        self.type = persistentTransaction.transactionType
        self.amount = persistentTransaction.amount
        self.date = persistentTransaction.date
        self.status = persistentTransaction.transactionStatus
        self.address = persistentTransaction.address
        self.notes = persistentTransaction.notes
        self.fees = persistentTransaction.fees
        self.onchainFeeSat = persistentTransaction.onchainFeeSat
        self.subsystemCategory = persistentTransaction.subsystemCategory
        self.subsystemName = persistentTransaction.subsystemName
        self.subsystemKind = persistentTransaction.subsystemKind
        self.paymentMethodType = persistentTransaction.paymentMethodType
        self.paymentHash = persistentTransaction.paymentHash
        self.fundingTxid = persistentTransaction.fundingTxid
        self.inputVtxoIds = persistentTransaction.inputVtxoIds
        self.outputVtxoIds = persistentTransaction.outputVtxoIds
        self.exitedVtxoIds = persistentTransaction.exitedVtxoIds
        self.associatedTags = persistentTransaction.associatedTags.map { TagModel(from: $0) }
        self.associatedContacts = persistentTransaction.associatedContacts.map { ContactModel(from: $0) }
        self.category = persistentTransaction.category
    }
    
    // MARK: - Identifiable
    
    var id: String { txid }
    
    // MARK: - UI Formatting Properties
    
    /// Formatted amount for display (e.g., "+0.00123456 BTC" or "-0.00050000 BTC")
    var formattedAmount: String {
        return BitcoinFormatter.shared.formatTransactionAmount(amount, transactionType: type, isInternalTransfer: isInternalTransfer)
    }
    
    /// Formatted amount for accounting display
    var formattedAmountAccounting: String {
        return BitcoinFormatter.shared.formatAccountingAmount(amount, transactionType: type, isInternalTransfer: isInternalTransfer)
    }
    
    /// Formatted date for display (relative time)
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Absolute formatted date
    var formattedDateAbsolute: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Formatted fee for display (e.g., "250 sats" or "0.00000250 BTC")
    /// Shows offchain fees only (for backwards compatibility)
    var formattedFee: String? {
        guard let fees = fees, fees > 0 else {
            return nil
        }
        return BitcoinFormatter.shared.formatAmount(fees)
    }
    
    /// Formatted onchain fee for display
    var formattedOnchainFee: String? {
        guard let onchainFee = onchainFeeSat, onchainFee > 0 else {
            return nil
        }
        return BitcoinFormatter.shared.formatAmount(onchainFee)
    }
    
    /// Total fees (offchain + onchain)
    var totalFees: Int {
        let offchain = fees ?? 0
        let onchain = onchainFeeSat ?? 0
        return offchain + onchain
    }
    
    /// Formatted total fees for display
    var formattedTotalFees: String? {
        let total = totalFees
        guard total > 0 else {
            return nil
        }
        return BitcoinFormatter.shared.formatAmount(total)
    }
    
    /// Check if transaction has fees
    var hasFees: Bool {
        totalFees > 0
    }
    
    /// Check if transaction has both onchain and offchain fees
    var hasBothFeeTypes: Bool {
        let hasOffchain = (fees ?? 0) > 0
        let hasOnchain = (onchainFeeSat ?? 0) > 0
        return hasOffchain && hasOnchain
    }
    
    /// Convenience accessor for transaction type (already a typed property)
    var transactionType: TransactionTypeEnum {
        return type
    }
    
    /// Convenience accessor for transaction status (already a typed property)
    var transactionStatus: TransactionStatusEnum {
        return status
    }
    
    /// Check if this transaction is an internal transfer (between user's own balances)
    /// Internal transfers include:
    /// - Boarding, offboarding, refresh, exit operations (internal by nature)
    /// - Onchain sends to own addresses (requires client-side detection)
    var isInternalTransfer: Bool {
        guard let category = category else { return false }
        
        switch category {
        case .boarding, .offboarding, .refresh, .exit:
            return true
        case .onchainSend:
            return subsystemName == "bark.offboard"
            // For onchain sends, this will be determined by whether a receivingAddress
            // is linked in PersistentTransaction. This property will be true when
            // the TransactionService detects the destination is owned by the user.
            // Note: This check is placeholder - actual detection happens in PersistentTransaction
            //return false
        default:
            return false
        }
    }
    
    // MARK: - Tag and Contact Helpers
    
    /// Check if transaction has any tags
    var hasTags: Bool {
        !associatedTags.isEmpty
    }
    
    /// Count of tags
    var tagCount: Int {
        associatedTags.count
    }
    
    /// Check if transaction has a specific tag
    func hasTag(_ tag: TagModel) -> Bool {
        associatedTags.contains { $0.id == tag.id }
    }
    
    /// Check if transaction has a specific tag ID
    func hasTag(id: UUID) -> Bool {
        associatedTags.contains { $0.id == id }
    }
    
    /// Check if transaction has any contacts
    var hasContacts: Bool {
        !associatedContacts.isEmpty
    }
    
    /// Count of contacts
    var contactCount: Int {
        associatedContacts.count
    }
    
    /// Check if transaction has a specific contact
    func hasContact(_ contact: ContactModel) -> Bool {
        associatedContacts.contains { $0.id == contact.id }
    }
    
    /// Check if transaction has a specific contact ID
    func hasContact(id: UUID) -> Bool {
        associatedContacts.contains { $0.id == id }
    }
    
    // MARK: - Notes Helpers
    
    /// Check if transaction has notes
    var hasNotes: Bool {
        guard let notes = notes else { return false }
        return !notes.isEmpty
    }
    
    /// Get a preview of the notes (first 100 characters)
    var notesPreview: String? {
        guard let notes = notes, !notes.isEmpty else { return nil }
        if notes.count <= 100 {
            return notes
        }
        let endIndex = notes.index(notes.startIndex, offsetBy: 100)
        return String(notes[..<endIndex]) + "..."
    }
    
    // MARK: - Convert to PersistentTransaction
    
    func toPersistentTransaction() -> PersistentTransaction {
        return PersistentTransaction(
            txid: self.txid,
            movementId: self.movementId,
            recipientIndex: self.recipientIndex,
            type: self.type,
            amount: self.amount,
            date: self.date,
            status: self.status,
            address: self.address,
            notes: self.notes,
            fees: self.fees,
            subsystemCategory: self.subsystemCategory,
            subsystemName: self.subsystemName,
            subsystemKind: self.subsystemKind,
            paymentMethodType: self.paymentMethodType,
            paymentHash: self.paymentHash,
            onchainFeeSat: self.onchainFeeSat,
            fundingTxid: self.fundingTxid,
            inputVtxoIds: self.inputVtxoIds,
            outputVtxoIds: self.outputVtxoIds,
            exitedVtxoIds: self.exitedVtxoIds
        )
        // Note: Tag and contact assignments should be managed separately through services
        // to avoid complex relationship management during transaction creation
    }
}
