//
//  TransactionContactAssignment.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import Foundation
import SwiftData

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
