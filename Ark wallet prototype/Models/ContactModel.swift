//
//  ContactModel.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/04/25.
//

import SwiftUI
import SwiftData

// MARK: - Persistent Contact Model

@Model
final class PersistentContact {
    @Attribute(.unique) var id: UUID
    var cachedName: String
    var notes: String?
    var avatarData: Data?
    var createdAt: Date
    var updatedAt: Date
    
    // Relationship to contact assignments (not direct to transactions for better control)
    @Relationship(deleteRule: .cascade, inverse: \TransactionContactAssignment.contact)
    var contactAssignments: [TransactionContactAssignment] = []
    
    init(id: UUID = UUID(), cachedName: String, notes: String? = nil, avatarData: Data? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.cachedName = cachedName
        self.notes = notes
        self.avatarData = avatarData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Display name (just the cached name for now)
    var displayName: String {
        cachedName.isEmpty ? "Unknown Contact" : cachedName
    }
    
    // Get all transactions that have this contact
    var associatedTransactions: [TransactionModel] {
        contactAssignments.compactMap { $0.transaction }
    }
    
    // Count of associated transactions
    var transactionCount: Int {
        contactAssignments.count
    }
    
    // Total amount (net: received - sent)
    var totalTransactionAmount: Int {
        let sent = sentAmount
        let received = receivedAmount
        return received - sent
    }
    
    // Sum of sent transaction amounts
    var sentAmount: Int {
        associatedTransactions
            .filter { $0.type == "sent" }
            .reduce(0) { $0 + $1.amount }
    }
    
    // Sum of received transaction amounts
    var receivedAmount: Int {
        associatedTransactions
            .filter { $0.type == "received" }
            .reduce(0) { $0 + $1.amount }
    }
    
    // Helper method to update the updatedAt timestamp
    func touch() {
        updatedAt = Date()
    }
}

// MARK: - Transaction Contact Assignment (Junction Table)

@Model
final class TransactionContactAssignment {
    var assignedDate: Date
    
    // Relationships to both contact and transaction
    @Relationship var contact: PersistentContact?
    @Relationship var transaction: TransactionModel?
    
    init(contact: PersistentContact, transaction: TransactionModel, assignedDate: Date = Date()) {
        self.contact = contact
        self.transaction = transaction
        self.assignedDate = assignedDate
    }
    
    // Computed property for easier identification
    var id: String {
        guard let contactId = contact?.id.uuidString,
              let txid = transaction?.txid else {
            return UUID().uuidString
        }
        return "\(contactId)_\(txid)"
    }
}

// MARK: - UI Model (for UI convenience)

struct ContactModel: Identifiable, Hashable, Codable {
    let id: UUID
    let cachedName: String
    let notes: String?
    let avatarData: Data?
    let createdAt: Date
    let updatedAt: Date
    
    init(id: UUID = UUID(), cachedName: String, notes: String? = nil, avatarData: Data? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.cachedName = cachedName
        self.notes = notes
        self.avatarData = avatarData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Initialize from persistent contact
    init(from persistentContact: PersistentContact) {
        self.id = persistentContact.id
        self.cachedName = persistentContact.cachedName
        self.notes = persistentContact.notes
        self.avatarData = persistentContact.avatarData
        self.createdAt = persistentContact.createdAt
        self.updatedAt = persistentContact.updatedAt
    }
    
    // Display name (just the cached name for now)
    var displayName: String {
        cachedName.isEmpty ? "Unknown Contact" : cachedName
    }
    
    // Convert to persistent model
    func toPersistentContact() -> PersistentContact {
        return PersistentContact(
            id: self.id,
            cachedName: self.cachedName,
            notes: self.notes,
            avatarData: self.avatarData,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
    
    // Create a new contact model with updated timestamp
    func withUpdatedTimestamp() -> ContactModel {
        return ContactModel(
            id: self.id,
            cachedName: self.cachedName,
            notes: self.notes,
            avatarData: self.avatarData,
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }
}