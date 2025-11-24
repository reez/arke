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
    
    let filterTag: PersistentTag?
    let filterContact: PersistentContact?
    
    init(selectedTransaction: Binding<TransactionModel?>, filterTag: PersistentTag? = nil, filterContact: PersistentContact? = nil) {
        self._selectedTransaction = selectedTransaction
        self.filterTag = filterTag
        self.filterContact = filterContact
    }
    
    // Dynamic query based on filter parameters
    private var transactions: [TransactionModel] {
        let context = modelContext
        
        // Access dataVersion to create observation dependency
        // This ensures the view updates when relationships change
        _ = walletManager.dataVersion
        
        if let contact = filterContact {
            // For contact filtering, we need to query the assignment table first
            return transactionsForContact(contact, context: context)
        } else if let tag = filterTag {
            // For tag filtering, use the same approach as contact filtering
            return transactionsForTag(tag, context: context)
        } else {
            // No filter, fetch all transactions
            let fetchDescriptor = createFetchDescriptor()
            do {
                let persistentTransactions = try context.fetch(fetchDescriptor)
                return persistentTransactions.map { TransactionModel(from: $0) }
            } catch {
                print("Error fetching transactions: \(error)")
                return []
            }
        }
    }
    
    // Helper method to get transactions for a specific tag
    private func transactionsForTag(_ tag: PersistentTag, context: ModelContext) -> [TransactionModel] {
        do {
            // Store the tag ID to avoid capturing the tag object in the predicate
            let tagId = tag.id
            
            // First, get all tag assignments for this tag
            let assignmentDescriptor = FetchDescriptor<TransactionTagAssignment>(
                predicate: #Predicate<TransactionTagAssignment> { assignment in
                    assignment.tag?.id == tagId
                }
            )
            let assignments = try context.fetch(assignmentDescriptor)
            
            // Extract the transaction IDs
            let txids = assignments.compactMap { $0.transaction?.txid }
            
            // If no assignments found, return empty array
            guard !txids.isEmpty else { return [] }
            
            // Now fetch transactions with those IDs, sorted by date
            let transactionDescriptor = FetchDescriptor<PersistentTransaction>(
                predicate: #Predicate<PersistentTransaction> { transaction in
                    txids.contains(transaction.txid)
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            let persistentTransactions = try context.fetch(transactionDescriptor)
            return persistentTransactions.map { TransactionModel(from: $0) }
        } catch {
            print("Error fetching transactions for tag: \(error)")
            return []
        }
    }
    
    // Helper method to get transactions for a specific contact
    private func transactionsForContact(_ contact: PersistentContact, context: ModelContext) -> [TransactionModel] {
        do {
            // Store the contact ID to avoid capturing the contact object in the predicate
            let contactId = contact.id
            
            // First, get all contact assignments for this contact
            let assignmentDescriptor = FetchDescriptor<TransactionContactAssignment>(
                predicate: #Predicate<TransactionContactAssignment> { assignment in
                    assignment.contact?.id == contactId
                }
            )
            let assignments = try context.fetch(assignmentDescriptor)
            
            // Extract the transaction IDs
            let txids = assignments.compactMap { $0.transaction?.txid }
            
            // If no assignments found, return empty array
            guard !txids.isEmpty else { return [] }
            
            // Now fetch transactions with those IDs, sorted by date
            let transactionDescriptor = FetchDescriptor<PersistentTransaction>(
                predicate: #Predicate<PersistentTransaction> { transaction in
                    txids.contains(transaction.txid)
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            let persistentTransactions = try context.fetch(transactionDescriptor)
            return persistentTransactions.map { TransactionModel(from: $0) }
        } catch {
            print("Error fetching transactions for contact: \(error)")
            return []
        }
    }
    
    // Create fetch descriptor for all transactions (no filter)
    private func createFetchDescriptor() -> FetchDescriptor<PersistentTransaction> {
        var descriptor = FetchDescriptor<PersistentTransaction>()
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        return descriptor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {            
            // Transaction List
            if walletManager.isRefreshing && transactions.isEmpty {
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
            } else if transactions.isEmpty {
                VStack {
                    ContentUnavailableView {
                        VStack(spacing: 15) {
                            Image(systemName: "arrow.down")
                                .imageScale(.medium)
                                .symbolVariant(.none)
                            Text("Start by sending bitcoin to your wallet")
                                .font(.system(size: 19, design: .serif))
                        }
                    }
                }
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(transactions) { transaction in
                        TransactionListItem(transaction: transaction, selectedTransaction: $selectedTransaction)
                        
                        if transaction.txid != transactions.last?.txid {
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
        TransactionList(selectedTransaction: $selectedTransaction)
            .environment(walletManager)
    }
    .modelContainer(for: PersistentTransaction.self, inMemory: true)
}

#Preview("Empty State") {
    @Previewable @State var selectedTransaction: TransactionModel? = nil
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    NavigationView {
        TransactionList(selectedTransaction: $selectedTransaction)
            .environment(walletManager)
    }
    .modelContainer(for: PersistentTransaction.self, inMemory: true)
}
