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
                return String(localized: "transaction_list_empty_title")
            case .tag(let name):
                return String(localized: "transaction_list_empty_tag_title \(name)")
            case .contact(let name):
                return String(localized: "transaction_list_empty_contact_title \(name)")
            }
        }
        
        func message(isTestnet: Bool) -> String {
            switch self {
            case .none:
                return isTestnet ? String(localized: "transaction_list_empty_message_testnet") : String(localized: "transaction_list_empty_message_mainnet")
            case .tag:
                return String(localized: "transaction_list_empty_tag_message")
            case .contact:
                return String(localized: "transaction_list_empty_contact_message")
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
            Text(filterContext.message(isTestnet: onShowFaucet != nil))
        } actions: {
            if filterContext == .none, let onShowFaucet = onShowFaucet {
                Button {
                    onShowFaucet()
                } label: {
                    HStack {
                        Image(systemName: "book.pages.fill")
                            .foregroundStyle(Color.Arke.gold)
                        Text("transaction_list_empty_guide_button")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.Arke.gold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
                .tint(Color.Arke.gold)
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
