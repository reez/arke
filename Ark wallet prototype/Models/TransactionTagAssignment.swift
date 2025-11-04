//
//  TransactionTagAssignment.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI
import SwiftData

@Model
final class TransactionTagAssignment {
    var assignedDate: Date
    
    // Relationships to both tag and transaction
    @Relationship var tag: PersistentTag?
    @Relationship var transaction: TransactionModel?
    
    init(tag: PersistentTag, transaction: TransactionModel, assignedDate: Date = Date()) {
        self.tag = tag
        self.transaction = transaction
        self.assignedDate = assignedDate
    }
    
    // Computed property for easier identification
    var id: String {
        guard let tagId = tag?.id.uuidString,
              let txid = transaction?.txid else {
            return UUID().uuidString
        }
        return "\(tagId)_\(txid)"
    }
}
