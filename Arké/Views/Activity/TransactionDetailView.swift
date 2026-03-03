//
//  TransactionDetailView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/19/25.
//

import SwiftUI
import AppKit

struct TransactionDetailView: View {
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
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    @ViewBuilder
    private func contentView(viewModel: TransactionDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Section
                VStack(spacing: 16) {
                    // Transaction Icon and Type
                    HStack(spacing: 15) {
                        Image(systemName: transaction.transactionType.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(transaction.transactionType.iconColor)
                            .frame(width: 40, height: 40)
                            .background(transaction.transactionType.iconColor.opacity(0.1))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading) {
                            Text(transaction.displayText(includeStatusPrefix: false))
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(transaction.formattedDate)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Amount
                    Text(transaction.formattedAmount)
                        .font(.largeTitle)
                        .fontWeight(.medium)
                        .foregroundColor(transaction.transactionType.amountColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Status Badge (only show if not confirmed)
                    if transaction.transactionStatus != .confirmed {
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
                }
                .padding(.horizontal, 15)
                
                Divider()
                    .padding(.leading, 15)
                    .padding(.trailing, 15)
                
                // Tags Section
                TransactionTagView(transaction: transaction)
                    .padding(.horizontal, 15)
                
                // Contacts Section
                TransactionContactView(
                    transaction: transaction,
                    onNavigateToContact: onNavigateToContact
                )
                    .padding(.horizontal, 15)
                
                // Notes Section
                TransactionNotesSection(transaction: transaction)
                    .padding(.horizontal, 5)
                
                Divider()
                    .padding(.leading, 15)
                    .padding(.trailing, 15)
                
                // Details Section
                DisclosureGroup {
                    VStack(spacing: 12) {
                        // Transaction ID
                        DetailRow(
                            title: "Transaction ID",
                            value: transaction.txid,
                            isCopyable: true,
                            onCopy: { viewModel.copyToClipboard($0) }
                        )
                        
                        // Address
                        if let address = transaction.address {
                            DetailRow(
                                title: transaction.transactionType == .received ? "From Address" : "To Address",
                                value: address,
                                isCopyable: true,
                                onCopy: { viewModel.copyToClipboard($0) }
                            )
                        }
                        
                        // Fee (show for sent and transfer transactions)
                        if transaction.hasFees && (transaction.transactionType == .sent || transaction.transactionType == .transfer) {
                            // If both fee types exist, show them separately
                            if transaction.hasBothFeeTypes {
                                if let offchainFee = transaction.formattedFee {
                                    DetailRow(
                                        title: "Offchain Fee",
                                        value: offchainFee
                                    )
                                }
                                if let onchainFee = transaction.formattedOnchainFee {
                                    DetailRow(
                                        title: "Onchain Fee",
                                        value: onchainFee
                                    )
                                }
                                // Show total
                                if let totalFee = transaction.formattedTotalFees {
                                    DetailRow(
                                        title: "Total Fee",
                                        value: totalFee
                                    )
                                }
                            } else {
                                // Show single fee line
                                DetailRow(
                                    title: "Fee",
                                    value: transaction.formattedTotalFees ?? BitcoinFormatter.shared.formatAmount(0)
                                )
                            }
                        }
                        
                        // Date
                        DetailRow(
                            title: "Date",
                            value: transaction.date.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                    .padding(.top, 8)
                } label: {
                    Text("label_details")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 15)
                
                Spacer()
            }
            .padding(.vertical, 15)
        }
        .overlay(alignment: .bottom) {
            if viewModel.showCopySuccess {
                Text("status_copied_clipboard")
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
}

#Preview {
    NavigationStack {
        TransactionDetailView(
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
    }
}
