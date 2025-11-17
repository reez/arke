//
//  PersistentTag.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI
import SwiftData

@Model
final class PersistentTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var emoji: String
    var createdDate: Date
    
    // Relationship to tag assignments (not direct to transactions for better control)
    @Relationship(deleteRule: .cascade, inverse: \TransactionTagAssignment.tag)
    var tagAssignments: [TransactionTagAssignment] = []
    
    init(id: UUID = UUID(), name: String, colorHex: String, emoji: String, createdDate: Date = Date()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.emoji = emoji
        self.createdDate = createdDate
    }
    
    // Computed property for SwiftUI Color
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    // Display name with emoji
    var displayName: String {
        emoji.isEmpty ? name : "\(emoji) \(name)"
    }
    
    // Get all transactions that have this tag
    var associatedTransactions: [PersistentTransaction] {
        tagAssignments.compactMap { $0.transaction }
    }
    
    // Count of associated transactions
    var transactionCount: Int {
        tagAssignments.count
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
}
