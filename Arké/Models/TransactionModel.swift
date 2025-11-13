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
    
    // Associated tags and contacts (full objects for UI convenience)
    let associatedTags: [TagModel]
    let associatedContacts: [ContactModel]
    
    init(txid: String, movementId: Int?, recipientIndex: Int? = nil, type: TransactionTypeEnum,
         amount: Int, date: Date, status: TransactionStatusEnum, address: String?,
         associatedTags: [TagModel] = [], associatedContacts: [ContactModel] = []) {
        self.txid = txid
        self.movementId = movementId
        self.recipientIndex = recipientIndex
        self.type = type
        self.amount = amount
        self.date = date
        self.status = status
        self.address = address
        self.associatedTags = associatedTags
        self.associatedContacts = associatedContacts
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
        self.associatedTags = persistentTransaction.associatedTags.map { TagModel(from: $0) }
        self.associatedContacts = persistentTransaction.associatedContacts.map { ContactModel(from: $0) }
    }
    
    // MARK: - Identifiable
    
    var id: String { txid }
    
    // MARK: - UI Formatting Properties
    
    /// Formatted amount for display (e.g., "+0.00123456 BTC" or "-0.00050000 BTC")
    var formattedAmount: String {
        return BitcoinFormatter.formatTransactionAmount(amount, transactionType: type)
    }
    
    /// Formatted amount for accounting display
    var formattedAmountAccounting: String {
        return BitcoinFormatter.formatAccountingAmount(amount, transactionType: type)
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
    
    /// Convenience accessor for transaction type (already a typed property)
    var transactionType: TransactionTypeEnum {
        return type
    }
    
    /// Convenience accessor for transaction status (already a typed property)
    var transactionStatus: TransactionStatusEnum {
        return status
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
            address: self.address
        )
        // Note: Tag and contact assignments should be managed separately through services
        // to avoid complex relationship management during transaction creation
    }
}
