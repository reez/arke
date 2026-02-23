//
//  TransactionListEmptyState.swift
//  Ark wallet prototype
//
//  Created by Christoph on 12/05/25.
//

import SwiftUI
import ArkeUI

/// Shared empty state component for transaction lists
struct TransactionListEmptyState: View {
    let filterContext: FilterContext
    let onShowFaucet: (() -> Void)?
    
    enum FilterContext: Equatable {
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
                return "Get started by funding your wallet with test bitcoin"
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
    
    init(filterTag: PersistentTag? = nil, filterContact: PersistentContact? = nil, onShowFaucet: (() -> Void)? = nil) {
        if let tag = filterTag {
            self.filterContext = .tag(name: tag.name)
        } else if let contact = filterContact {
            self.filterContext = .contact(name: contact.cachedName)
        } else {
            self.filterContext = .none
        }
        self.onShowFaucet = onShowFaucet
    }
    
    var body: some View {
        ContentUnavailableView {
            Label(filterContext.title, systemImage: filterContext.icon)
        } description: {
            Text(filterContext.message)
        } actions: {
            if filterContext == .none, let onShowFaucet = onShowFaucet {
                Button {
                    onShowFaucet()
                } label: {
                    HStack {
                        Image(systemName: "popcorn.fill")
                            .foregroundStyle(Color.arkeGold)
                        Text("See the test guide")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.arkeGold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
                .tint(Color.arkeGold)
            }
        }
    }
}

#Preview("No Filter") {
    TransactionListEmptyState(onShowFaucet: {
        print("Show faucet tapped")
    })
}

#Preview("Tag Filter") {
    TransactionListEmptyState(
        filterTag: PersistentTag(
            id: UUID(),
            name: "Mining",
            colorHex: "#FF5733",
            emoji: "⛏️"
        ),
        onShowFaucet: nil
    )
}

#Preview("Contact Filter") {
    TransactionListEmptyState(
        filterContact: PersistentContact(
            id: UUID(),
            cachedName: "Alice"
        ),
        onShowFaucet: nil
    )
}
