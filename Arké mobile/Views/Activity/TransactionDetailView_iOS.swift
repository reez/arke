//
//  TransactionDetailView_iOS.swift
//  Arké
//
//  Created by Assistant on 12/8/25.
//

import SwiftUI

struct TransactionDetailView_iOS: View {
    let transaction: TransactionModel
    let onNavigateToContact: ((ContactModel) -> Void)?
    
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel: TransactionDetailViewModel?
    
    var body: some View {
        Group {
            if let viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .task {
                        viewModel = TransactionDetailViewModel(
                            transaction: transaction,
                            walletManager: walletManager
                        )
                    }
            }
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func contentView(viewModel: TransactionDetailViewModel) -> some View {
        List {
            // Header Section
            Section {
                headerView
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // Tags Section
            Section {
                TransactionTagView(transaction: transaction)
            } header: {
                Text("Tags")
            }
            
            // Contacts Section
            Section {
                TransactionContactView(
                    transaction: transaction,
                    onNavigateToContact: onNavigateToContact
                )
            } header: {
                Text("Contact")
            }
            
            // Notes Section
            Section {
                TransactionNotesSection(transaction: transaction)
            } header: {
                Text("Notes")
            }
            
            // Details Section
            Section {
                detailsView
            } header: {
                Text("Details")
            }
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .bottom) {
            if viewModel.showCopySuccess {
                Text("Copied to clipboard")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .cornerRadius(8)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 16) {
            // Transaction Icon and Type
            HStack(spacing: 15) {
                Image(systemName: transaction.transactionType.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(transaction.transactionType.iconColor)
                    .frame(width: 40, height: 40)
                    .background(transaction.transactionType.iconColor.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.transactionType.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(transaction.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Amount
            Text(transaction.formattedAmount)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(transaction.transactionType.amountColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Status Badge
            HStack {
                Text(transaction.transactionStatus.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(transaction.transactionStatus.textColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(transaction.transactionStatus.backgroundColor)
                    .clipShape(Capsule())
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    @ViewBuilder
    private var detailsView: some View {
        VStack(spacing: 16) {
            // Transaction ID
            DetailRow(
                title: "Transaction ID",
                value: transaction.txid,
                isCopyable: true,
                onCopy: { viewModel?.copyToClipboard($0) }
            )
            
            // Address
            if let address = transaction.address {
                Divider()
                DetailRow(
                    title: transaction.transactionType == .received ? "From Address" : "To Address",
                    value: address,
                    isCopyable: true,
                    onCopy: { viewModel?.copyToClipboard($0) }
                )
            }
            
            // Date
            Divider()
            DetailRow(
                title: "Date",
                value: transaction.date.formatted(date: .abbreviated, time: .shortened)
            )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TransactionDetailView_iOS(
            transaction: TransactionModel(
                txid: "1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z",
                movementId: nil,
                recipientIndex: nil,
                type: TransactionTypeEnum.received,
                amount: 50000,
                date: Date().addingTimeInterval(-3600),
                status: TransactionStatusEnum.confirmed,
                address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
            ),
            onNavigateToContact: nil
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("Sent Transaction") {
    NavigationStack {
        TransactionDetailView_iOS(
            transaction: TransactionModel(
                txid: "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz",
                movementId: nil,
                recipientIndex: nil,
                type: TransactionTypeEnum.sent,
                amount: -125000,
                date: Date().addingTimeInterval(-86400),
                status: TransactionStatusEnum.confirmed,
                address: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"
            ),
            onNavigateToContact: nil
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("Pending Transaction") {
    NavigationStack {
        TransactionDetailView_iOS(
            transaction: TransactionModel(
                txid: "pending123abc456def789ghi012jkl345mno678pqr",
                movementId: nil,
                recipientIndex: nil,
                type: TransactionTypeEnum.received,
                amount: 75000,
                date: Date(),
                status: TransactionStatusEnum.pending,
                address: nil
            ),
            onNavigateToContact: nil
        )
        .environment(WalletManager(useMock: true))
    }
}
