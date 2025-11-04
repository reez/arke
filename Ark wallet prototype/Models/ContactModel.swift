//
//  ContactModel.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/04/25.
//

import SwiftUI
import SwiftData

struct ContactModel: Identifiable, Hashable, Codable {
    let id: UUID
    let cachedName: String
    let notes: String?
    let avatarData: Data?
    let createdAt: Date
    let updatedAt: Date
    
    // Transaction statistics (optional for backward compatibility)
    let transactionCount: Int?
    let sentAmount: Int?
    let receivedAmount: Int?
    
    init(id: UUID = UUID(), cachedName: String, notes: String? = nil, avatarData: Data? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), transactionCount: Int? = nil, sentAmount: Int? = nil, receivedAmount: Int? = nil) {
        self.id = id
        self.cachedName = cachedName
        self.notes = notes
        self.avatarData = avatarData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.transactionCount = transactionCount
        self.sentAmount = sentAmount
        self.receivedAmount = receivedAmount
    }
    
    // Initialize from persistent contact
    init(from persistentContact: PersistentContact) {
        self.id = persistentContact.id
        self.cachedName = persistentContact.cachedName
        self.notes = persistentContact.notes
        self.avatarData = persistentContact.avatarData
        self.createdAt = persistentContact.createdAt
        self.updatedAt = persistentContact.updatedAt
        self.transactionCount = persistentContact.transactionCount
        self.sentAmount = persistentContact.sentAmount
        self.receivedAmount = persistentContact.receivedAmount
    }
    
    // Display name (just the cached name for now)
    var displayName: String {
        cachedName.isEmpty ? "Unknown Contact" : cachedName
    }
    
    // Computed properties for formatted display of transaction statistics
    var formattedTransactionCount: String? {
        guard let count = transactionCount else { return nil }
        return count == 1 ? "1 transaction" : "\(count) transactions"
    }
    
    var formattedSentAmount: String? {
        guard let amount = sentAmount, amount > 0 else { return nil }
        return BitcoinFormatter.formatAccountingAmount(amount, transactionType: .sent)
    }
    
    var formattedReceivedAmount: String? {
        guard let amount = receivedAmount, amount > 0 else { return nil }
        return BitcoinFormatter.formatAccountingAmount(amount, transactionType: .received)
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
            updatedAt: Date(),
            transactionCount: self.transactionCount,
            sentAmount: self.sentAmount,
            receivedAmount: self.receivedAmount
        )
    }
}
