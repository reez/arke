//
//  TransactionModel+DisplayHelpers.swift
//  Arké
//
//  Created by Assistant on 1/8/26.
//

import Foundation

extension TransactionModel {
    
    /// Returns a user-friendly display text for the transaction based on context
    /// - Parameter includeStatusPrefix: Whether to include status-aware prefixes (e.g., "Sending to" vs "To")
    /// - Returns: A formatted display string
    func displayText(includeStatusPrefix: Bool = true) -> String {
        // Prioritize notes if they exist
        if let notes = notes, !notes.isEmpty {
            return notes
        }
        
        // Check if this is a categorized operation
        if let category = category {
            switch category {
            case .boarding:
                return statusAwareText(
                    confirmed: "Transfer to payments",
                    pending: "Transferring to payments",
                    failed: "Failed transfer to payments",
                    includePrefix: includeStatusPrefix
                )
            case .exit:
                return statusAwareText(
                    confirmed: "Claim",
                    pending: "Claiming",
                    failed: "Failed claim",
                    includePrefix: includeStatusPrefix
                )
            case .offboarding:
                return statusAwareText(
                    confirmed: "Transfer to savings",
                    pending: "Transferring to savings",
                    failed: "Failed transfer to savings",
                    includePrefix: includeStatusPrefix
                )
            case .refresh:
                return statusAwareText(
                    confirmed: "Payments balance refresh",
                    pending: "Refreshing payments balance",
                    failed: "Failed balance refresh",
                    includePrefix: includeStatusPrefix
                )
            case .lightningSend:
                if let contact = associatedContacts.first {
                    return statusAwareText(
                        confirmed: "To \(contact.cachedName)",
                        pending: "Sending to \(contact.cachedName)",
                        failed: "Failed send to \(contact.cachedName)",
                        includePrefix: includeStatusPrefix
                    )
                }
                return statusAwareText(
                    confirmed: "Sent",
                    pending: "Sending",
                    failed: "Failed send",
                    includePrefix: includeStatusPrefix
                )
            case .lightningReceive:
                if let contact = associatedContacts.first {
                    return statusAwareText(
                        confirmed: "From \(contact.cachedName)",
                        pending: "Receiving from \(contact.cachedName)",
                        failed: "Failed receive from \(contact.cachedName)",
                        includePrefix: includeStatusPrefix
                    )
                }
                return statusAwareText(
                    confirmed: "Received",
                    pending: "Receiving",
                    failed: "Failed receive",
                    includePrefix: includeStatusPrefix
                )
            case .onchainSend:
                if let contact = associatedContacts.first {
                    return statusAwareText(
                        confirmed: "To \(contact.cachedName)",
                        pending: "Sending to \(contact.cachedName)",
                        failed: "Failed send to \(contact.cachedName)",
                        includePrefix: includeStatusPrefix
                    )
                }
                return statusAwareText(
                    confirmed: "Sent",
                    pending: "Sending",
                    failed: "Failed send",
                    includePrefix: includeStatusPrefix
                )
            case .offchainTransfer:
                // Fall through to contact logic below
                break
            case .unknown:
                break
            }
        }
        
        // Contact-based display for regular send/receive
        if let contact = associatedContacts.first {
            switch transactionType {
            case .received:
                return statusAwareText(
                    confirmed: "From \(contact.cachedName)",
                    pending: "Receiving from \(contact.cachedName)",
                    failed: "Failed receive from \(contact.cachedName)",
                    includePrefix: includeStatusPrefix
                )
            case .sent:
                return statusAwareText(
                    confirmed: "To \(contact.cachedName)",
                    pending: "Sending to \(contact.cachedName)",
                    failed: "Failed send to \(contact.cachedName)",
                    includePrefix: includeStatusPrefix
                )
            case .transfer:
                return statusAwareText(
                    confirmed: "Transfer",
                    pending: "Transferring",
                    failed: "Failed transfer",
                    includePrefix: includeStatusPrefix
                )
            case .pending:
                return "Pending..."
            }
        }
        
        // Fallback to status-aware type display
        return statusAwareTypeDisplayName(includePrefix: includeStatusPrefix)
    }
    
    /// Helper method to return status-aware text
    private func statusAwareText(confirmed: String, pending: String, failed: String, includePrefix: Bool) -> String {
        guard includePrefix else {
            return confirmed
        }
        
        switch transactionStatus {
        case .confirmed:
            return confirmed
        case .pending:
            return pending
        case .failed:
            return failed
        }
    }
    
    /// Helper method to return status-aware transaction type display name
    private func statusAwareTypeDisplayName(includePrefix: Bool) -> String {
        guard includePrefix else {
            return transactionType.displayName
        }
        
        switch transactionType {
        case .sent:
            return statusAwareText(
                confirmed: "Sent",
                pending: "Sending",
                failed: "Failed send",
                includePrefix: includePrefix
            )
        case .received:
            return statusAwareText(
                confirmed: "Received",
                pending: "Receiving",
                failed: "Failed receive",
                includePrefix: includePrefix
            )
        case .transfer:
            return statusAwareText(
                confirmed: "Transfer",
                pending: "Transferring",
                failed: "Failed transfer",
                includePrefix: includePrefix
            )
        case .pending:
            return "Pending..."
        }
    }
}
