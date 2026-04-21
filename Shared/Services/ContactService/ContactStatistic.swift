//
//  ContactStatistic.swift
//  Arké
//
//  Statistical data about contact transaction activity
//

import Foundation
import ArkeUI

/// Statistical data about a contact's transaction activity
/// Used for analytics and contact insights displays
struct ContactStatistic {
    let contactId: UUID
    let contactName: String
    let transactionCount: Int
    let totalAmount: Int        // Net total (received - sent)
    let sentAmount: Int         // Sum of sent transactions
    let receivedAmount: Int     // Sum of received transactions
    let lastActivity: Date
    
    // Computed properties for display
    var formattedTotalAmount: String {
        BitcoinFormatter.shared.formatAccountingAmount(totalAmount, transactionType: totalAmount >= 0 ? .received : .sent)
    }
    
    var formattedSentAmount: String {
        BitcoinFormatter.shared.formatAccountingAmount(sentAmount, transactionType: .sent)
    }
    
    var formattedReceivedAmount: String {
        BitcoinFormatter.shared.formatAccountingAmount(receivedAmount, transactionType: .received)
    }
    
    var formattedLastActivity: String {
        RelativeDateTimeFormatter().localizedString(for: lastActivity, relativeTo: Date())
    }
}
