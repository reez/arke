//
//  PersistentTransaction.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/23/25.
//

import Foundation
import SwiftData

@Model
final class PersistentTransaction {
    // Remove @Attribute(.unique) for CloudKit compatibility
    var txid: String = ""  // Primary stable identifier - default for CloudKit
    var movementId: Int?  // Server movement ID for grouping (optional for migration compatibility)
    var recipientIndex: Int?  // For tracking multiple recipients in same movement
    var type: String = "received"  // "sent" or "received" - default for CloudKit
    var amount: Int = 0  // Amount in satoshis - default for CloudKit
    var date: Date = Date()  // Default for CloudKit
    var status: String = "pending"  // "confirmed", "pending", etc. - default for CloudKit
    var address: String?  // Recipient address for sends, nil for receives
    var notes: String?  // User-added notes for this transaction (max 1000 characters)
    var fees: Int?  // Transaction fees in satoshis (proportionally allocated for multi-recipient sends)
    
    // Tag assignments relationship - MUST be optional for CloudKit
    @Relationship(deleteRule: .cascade, inverse: \TransactionTagAssignment.transaction)
    var tagAssignments: [TransactionTagAssignment]? = []
    
    // Contact assignments relationship - MUST be optional for CloudKit
    @Relationship(deleteRule: .cascade, inverse: \TransactionContactAssignment.transaction)
    var contactAssignments: [TransactionContactAssignment]? = []
    
    init(txid: String, movementId: Int?, recipientIndex: Int? = nil, type: TransactionTypeEnum, 
         amount: Int, date: Date, status: TransactionStatusEnum, address: String?, notes: String? = nil, fees: Int? = nil) {
        self.txid = txid
        self.movementId = movementId
        self.recipientIndex = recipientIndex
        self.type = Self.stringValue(for: type)
        self.amount = amount
        self.date = date
        self.status = Self.stringValue(for: status)
        self.address = address
        self.notes = notes
        self.fees = fees
    }
    
    // MARK: - Computed Properties
    
    /// SwiftUI identifier using txid instead of persistentModelID
    var id: String { txid }
    
    /// Get the transaction type as enum
    var transactionType: TransactionTypeEnum {
        return Self.transactionType(from: type)
    }
    
    /// Get the transaction status as enum
    var transactionStatus: TransactionStatusEnum {
        return Self.transactionStatus(from: status)
    }
    
    // MARK: - Tag Convenience Methods
    
    /// Get all tags associated with this transaction
    var associatedTags: [PersistentTag] {
        (tagAssignments ?? []).compactMap { $0.tag }
    }
    
    /// Get count of tags on this transaction
    var tagCount: Int {
        tagAssignments?.count ?? 0
    }
    
    /// Check if transaction has a specific tag
    func hasTag(_ tag: PersistentTag) -> Bool {
        (tagAssignments ?? []).contains { $0.tag?.id == tag.id }
    }
    
    /// Check if transaction has any tags
    var hasTags: Bool {
        !(tagAssignments ?? []).isEmpty
    }
    
    // MARK: - Contact Convenience Methods
    
    /// Get all contacts associated with this transaction
    var associatedContacts: [PersistentContact] {
        (contactAssignments ?? []).compactMap { $0.contact }
    }
    
    /// Get count of contacts on this transaction
    var contactCount: Int {
        contactAssignments?.count ?? 0
    }
    
    /// Check if transaction has a specific contact
    func hasContact(_ contact: PersistentContact) -> Bool {
        (contactAssignments ?? []).contains { $0.contact?.id == contact.id }
    }
    
    /// Check if transaction has any contacts
    var hasContacts: Bool {
        !(contactAssignments ?? []).isEmpty
    }
    
    // MARK: - Notes Convenience Methods
    
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
    
    // MARK: - Helper methods for enum conversion
    
    private static func stringValue(for type: TransactionTypeEnum) -> String {
        switch type {
        case .sent: return "sent"
        case .received: return "received"
        case .pending: return "pending" // This seems like a design issue - pending should be status, not type
        }
    }
    
    private static func stringValue(for status: TransactionStatusEnum) -> String {
        switch status {
        case .confirmed: return "confirmed"
        case .pending: return "pending"
        case .failed: return "failed"
        }
    }
    
    private static func transactionType(from string: String) -> TransactionTypeEnum {
        switch string {
        case "sent": return .sent
        case "received": return .received
        case "pending": return .pending // This seems like a design issue - pending should be status, not type
        default: return .sent // fallback
        }
    }
    
    private static func transactionStatus(from string: String) -> TransactionStatusEnum {
        switch string {
        case "confirmed": return .confirmed
        case "pending": return .pending
        case "failed": return .failed
        default: return .confirmed // fallback
        }
    }
}


