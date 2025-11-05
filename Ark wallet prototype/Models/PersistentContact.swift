//
//  PersistentContact.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI
import SwiftData

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
    
    // Relationship to addresses
    @Relationship(deleteRule: .cascade)
    var addresses: [PersistentContactAddress] = []
    
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
    
    // MARK: - Address Management
    
    /// Get the primary address if one exists
    var primaryAddress: PersistentContactAddress? {
        addresses.first { $0.isPrimary }
    }
    
    /// Get addresses by format
    func addresses(for format: AddressFormat) -> [PersistentContactAddress] {
        addresses.filter { $0.format == format }
    }
    
    /// Get addresses compatible with a specific network
    func addresses(for networkConfig: NetworkConfig) -> [PersistentContactAddress] {
        addresses.filter { $0.isCompatibleWith(networkConfig) }
    }
    
    /// Count of addresses
    var addressCount: Int {
        addresses.count
    }
}
