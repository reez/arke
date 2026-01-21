//
//  TransactionList.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import SwiftData

struct TransactionList: View {
    @Binding var selectedTransaction: TransactionModel?
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: TransactionListModel?
    
    let filterTag: PersistentTag?
    let filterContact: PersistentContact?
    let onShowFaucet: (() -> Void)?
    
    init(selectedTransaction: Binding<TransactionModel?>, filterTag: PersistentTag? = nil, filterContact: PersistentContact? = nil, onShowFaucet: (() -> Void)? = nil) {
        self._selectedTransaction = selectedTransaction
        self.filterTag = filterTag
        self.filterContact = filterContact
        self.onShowFaucet = onShowFaucet
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {            
            // Transaction List
            if walletManager.isRefreshing && viewModel?.transactions.isEmpty == true {
                VStack(spacing: 16) {
                    SkeletonLoader(
                        itemCount: 6,
                        itemHeight: 64,
                        spacing: 15,
                        cornerRadius: 15
                    )
                }
                .padding(.vertical, 16)
                .padding(.horizontal)
            } else if viewModel?.transactions.isEmpty == true {
                VStack {
                    TransactionListEmptyState(
                        filterTag: filterTag,
                        filterContact: filterContact,
                        onShowFaucet: onShowFaucet
                    )
                }
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel?.transactions ?? []) { transaction in
                        TransactionListItem(transaction: transaction, selectedTransaction: $selectedTransaction)
                        
                        if transaction.txid != viewModel?.transactions.last?.txid {
                            Divider()
                                .padding(.leading, 56) // Align with text content
                                .padding(.trailing, 12)
                        }
                    }
                }
                .background(.background)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
        }
        .onAppear {
            setupViewModel()
        }
        .onChange(of: walletManager.dataVersion) {
            viewModel?.fetchTransactions()
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
}

// MARK: - Mock Data for Previews
extension TransactionModel {
    @MainActor
    static var mockData: [TransactionModel] {
        [
            TransactionModel(
                txid: "movement_1_recipient_0",
                movementId: 1,
                recipientIndex: 0,
                type: .received,
                amount: 50000,
                date: Date().addingTimeInterval(-3600),
                status: .confirmed,
                address: nil
            ),
            TransactionModel(
                txid: "movement_2_recipient_0",
                movementId: 2,
                recipientIndex: 0,
                type: .sent,
                amount: 25000,
                date: Date().addingTimeInterval(-7200),
                status: .confirmed,
                address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
            ),
            TransactionModel(
                txid: "movement_3",
                movementId: 3,
                recipientIndex: nil,
                type: .received,
                amount: 75000,
                date: Date().addingTimeInterval(-86400),
                status: .confirmed,
                address: nil
            )
        ]
    }
}

#Preview("With Transactions") {
    @Previewable @State var selectedTransaction: TransactionModel? = nil
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    NavigationView {
        TransactionList(selectedTransaction: $selectedTransaction, onShowFaucet: {
            print("Show faucet tapped")
        })
            .environment(walletManager)
    }
    .modelContainer(for: PersistentTransaction.self, inMemory: true)
}

#Preview("Empty State") {
    @Previewable @State var selectedTransaction: TransactionModel? = nil
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    NavigationView {
        TransactionList(selectedTransaction: $selectedTransaction, onShowFaucet: {
            print("Show faucet tapped")
        })
            .environment(walletManager)
    }
    .modelContainer(for: PersistentTransaction.self, inMemory: true)
}
