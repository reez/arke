//
//  TransactionListEmptyState.swift
//  Ark wallet prototype
//
//  Created by Christoph on 12/05/25.
//

import SwiftUI

/// Shared empty state component for transaction lists
struct TransactionListEmptyState: View {
    let filterContext: FilterContext
    
    enum FilterContext {
        case none
        case tag(name: String)
        case contact(name: String)
        
        var title: String {
            switch self {
            case .none:
                return "No Transactions"
            case .tag(let name):
                return "No Transactions in \"\(name)\""
            case .contact(let name):
                return "No Transactions with \(name)"
            }
        }
        
        var message: String {
            switch self {
            case .none:
                return "Start by sending bitcoin to your wallet"
            case .tag:
                return "Transactions you tag will appear here"
            case .contact:
                return "Transactions with this contact will appear here"
            }
        }
        
        var icon: String {
            switch self {
            case .none:
                return "arrow.down"
            case .tag:
                return "tag"
            case .contact:
                return "person"
            }
        }
    }
    
    init(filterTag: PersistentTag? = nil, filterContact: PersistentContact? = nil) {
        if let tag = filterTag {
            self.filterContext = .tag(name: tag.name)
        } else if let contact = filterContact {
            self.filterContext = .contact(name: contact.cachedName)
        } else {
            self.filterContext = .none
        }
    }
    
    var body: some View {
        ContentUnavailableView {
            Label(filterContext.title, systemImage: filterContext.icon)
        } description: {
            Text(filterContext.message)
        }
    }
}

#Preview("No Filter") {
    TransactionListEmptyState()
}

#Preview("Tag Filter") {
    TransactionListEmptyState(
        filterTag: PersistentTag(
            id: UUID(),
            name: "Mining",
            colorHex: "#FF5733",
            emoji: "⛏️"
        )
    )
}

#Preview("Contact Filter") {
    TransactionListEmptyState(
        filterContact: PersistentContact(
            id: UUID(),
            cachedName: "Alice"
        )
    )
}
