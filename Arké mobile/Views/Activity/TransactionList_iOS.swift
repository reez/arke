//
//  TransactionList_iOS.swift
//  Ark wallet prototype
//
//  Created by Christoph on 12/05/25.
//

import SwiftUI
import SwiftData

struct TransactionList_iOS: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: TransactionListModel?
    @State private var selectedTransaction: TransactionModel?
    
    let filterTag: PersistentTag?
    let filterContact: PersistentContact?
    
    init(filterTag: PersistentTag? = nil, filterContact: PersistentContact? = nil) {
        self.filterTag = filterTag
        self.filterContact = filterContact
    }
    
    var body: some View {
        Group {
            if walletManager.isRefreshing && viewModel?.transactions.isEmpty == true {
                // Loading state with skeleton
                ScrollView {
                    VStack(spacing: 12) {
                        SkeletonLoader(
                            itemCount: 8,
                            itemHeight: 72,
                            spacing: 12,
                            cornerRadius: 12
                        )
                    }
                    .padding()
                }
            } else if viewModel?.transactions.isEmpty == true {
                // Empty state
                TransactionListEmptyState(
                    filterTag: filterTag,
                    filterContact: filterContact
                )
            } else {
                // Transaction list
                List {
                    ForEach(viewModel?.transactions ?? []) { transaction in
                        NavigationLink(value: transaction) {
                            TransactionListItem(
                                transaction: transaction,
                                selectedTransaction: $selectedTransaction
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await refreshTransactions()
                }
            }
        }
        .navigationTitle(navigationTitle)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .onAppear {
            setupViewModel()
        }
        .onChange(of: walletManager.dataVersion) {
            viewModel?.fetchTransactions()
        }
    }
    
    private var navigationTitle: String {
        if let contact = filterContact {
            return contact.cachedName
        } else if let tag = filterTag {
            return tag.name
        } else {
            return "Transactions"
        }
    }
    
    private func setupViewModel() {
        if viewModel == nil {
            viewModel = TransactionListModel(
                modelContext: modelContext,
                walletManager: walletManager,
                filterTag: filterTag,
                filterContact: filterContact
            )
            viewModel?.fetchTransactions()
        }
    }
    
    private func refreshTransactions() async {
        // Trigger wallet refresh if needed
        // This is a placeholder - implement based on your WalletManager API
        viewModel?.fetchTransactions()
    }
}

// MARK: - Previews
#Preview("iOS Transaction List") {
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    NavigationStack {
        TransactionList_iOS()
            .environment(walletManager)
    }
    .modelContainer(for: PersistentTransaction.self, inMemory: true)
}

#Preview("iOS Empty State") {
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    NavigationStack {
        TransactionList_iOS()
            .environment(walletManager)
    }
    .modelContainer(for: PersistentTransaction.self, inMemory: true)
}

#Preview("iOS Transaction Row") {
    @Previewable @State var selectedTransaction: TransactionModel? = nil
    
    List {
        TransactionListItem(
            transaction: TransactionModel(
                txid: "test_1",
                movementId: 1,
                recipientIndex: 0,
                type: .received,
                amount: 50000,
                date: Date(),
                status: .confirmed,
                address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
            ),
            selectedTransaction: $selectedTransaction
        )
        
        TransactionListItem(
            transaction: TransactionModel(
                txid: "test_2",
                movementId: 2,
                recipientIndex: 0,
                type: .sent,
                amount: 25000,
                date: Date(),
                status: .pending,
                address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
            ),
            selectedTransaction: $selectedTransaction
        )
    }
}
