//
//  PersistentTransaction+DisplayHelpers.swift
//  Arké
//
//  Display helper methods for PersistentTransaction to enable direct use in views
//

import Foundation
import SwiftUI
import ArkeUI

extension PersistentTransaction {
    
    // MARK: - Display Text
    
    /// Primary display text for the transaction (prioritizes notes, then context-aware description)
    /// - Parameter includeStatusPrefix: Whether to include status-aware prefixes
    /// - Returns: A formatted display string
    func displayText(includeStatusPrefix: Bool = true) -> String {
        // Convert to TransactionModel and use its displayText method
        // This leverages existing display logic without duplication
        return TransactionModel(from: self).displayText(includeStatusPrefix: includeStatusPrefix)
    }
    
    /// Short display text for list views
    func shortDisplayText(includeStatusPrefix: Bool = true) -> String {
        return TransactionModel(from: self).shortDisplayText(includeStatusPrefix: includeStatusPrefix)
    }
    
    /// Detailed display text for detail views
    func detailedDisplayText(includeStatusPrefix: Bool = true) -> String {
        return TransactionModel(from: self).detailedDisplayText(includeStatusPrefix: includeStatusPrefix)
    }
    
    // MARK: - Formatted Amounts
    
    /// Formatted amount for display
    var formattedAmount: String {
        TransactionModel(from: self).formattedAmount
    }
    
    /// Formatted display amount (for detail views)
    var formattedDisplayAmount: String {
        TransactionModel(from: self).formattedDisplayAmount
    }
    
    /// Formatted net amount (includes fees)
    var formattedNetAmount: String {
        TransactionModel(from: self).formattedNetAmount
    }
    
    // MARK: - Dates
    
    /// Formatted relative date
    var formattedDate: String {
        TransactionModel(from: self).formattedDate
    }
    
    /// Formatted absolute date
    var formattedDateAbsolute: String {
        TransactionModel(from: self).formattedDateAbsolute
    }
    
    // MARK: - Associated Data as Models
    
    /// Associated contacts as ContactModel array (for compatibility with views expecting ContactModel)
    var associatedContactModels: [ContactModel] {
        associatedContacts.map { ContactModel(from: $0) }
    }
    
    /// Associated tags as TagModel array (for compatibility with views expecting TagModel)
    var associatedTagModels: [TagModel] {
        associatedTags.map { TagModel(from: $0) }
    }
}
