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
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: TransactionDetailViewModel?
    @State private var showAbsoluteDate = false
    
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
        .onAppear {
            print("=== Transaction Detail View Appeared ===")
            print("Transaction Data:")
            print("  txid: \(transaction.txid)")
            print("  movementId: \(transaction.movementId?.description ?? "nil")")
            print("  recipientIndex: \(transaction.recipientIndex?.description ?? "nil")")
            print("  type: \(transaction.transactionType)")
            print("  amount: \(transaction.amount)")
            print("  date: \(transaction.date)")
            print("  status: \(transaction.transactionStatus)")
            print("  address: \(transaction.address ?? "nil")")
            print("  fees: \(transaction.fees?.description ?? "nil")")
            print("  onchainFeeSat: \(transaction.onchainFeeSat?.description ?? "nil")")
            print("  category: \(transaction.category?.rawValue ?? "nil")")
            print("  notes: \(transaction.notes ?? "nil")")
            print("  associatedContacts: \(transaction.associatedContacts.map { $0.displayName }.joined(separator: ", "))")
            print("  associatedTags: \(transaction.associatedTags.map { $0.name }.joined(separator: ", "))")
            print("=====================================")
        }
        //.navigationTitle("Transaction")
        //.navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func contentView(viewModel: TransactionDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header Section
                headerView
                
                VStack(alignment: .leading, spacing: 20) {
                    // Contact
                    TransactionContactView(
                        transaction: transaction,
                        onNavigateToContact: onNavigateToContact
                    )
                    
                    // Tags
                    TransactionTagView(transaction: transaction)
                    
                    // Note
                    TransactionNotesSection(transaction: transaction)
                }
                .padding(.horizontal)
                
                detailsView
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
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
        VStack(spacing: 15) {
            // Transaction Icon and Type
            Image(systemName: transaction.transactionType.iconName)
                .font(.system(size: 32))
                //.foregroundColor(transaction.transactionType.iconColor)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(transaction.transactionType.iconColor)
                .cornerRadius(15)
            
            VStack(alignment: .center, spacing: 5) {
                // Amount
                Text(transaction.formattedAmount)
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundColor(transaction.transactionType.amountColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                HStack(alignment: .center, spacing: 4) {
                    Text(transaction.displayText(includeStatusPrefix: false))
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(" · ")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(showAbsoluteDate ? transaction.formattedDateAbsolute : transaction.formattedDate)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showAbsoluteDate.toggle()
                        }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
            
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
                .padding(.vertical, 16)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
        .background(alignment: .bottom) {
            Image(backgroundPatternImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .opacity(colorScheme == .dark ? 0.25 : 0.75)
        }
    }
    
    // MARK: - Helper Properties
    
    /// Determines the appropriate background pattern image based on transaction category
    private var backgroundPatternImageName: String {
        guard let category = transaction.category else {
            // Fallback to block pattern if no category
            return "block-pattern-gold"
        }
        
        switch category {
        case .boarding, .exit, .offboarding, .refresh:
            // Internal/Ark transactions
            return "circle-pattern-gold"
            
        case .onchainSend:
            // Onchain transactions
            return "block-pattern-gold"
            
        case .lightningSend, .lightningReceive:
            // Lightning transactions
            return "lightning-pattern-gold"
            
        case .offchainTransfer, .unknown:
            // Fallback for unknown categories
            return "wave-pattern-gold"
        }
    }
    
    @ViewBuilder
    private var detailsView: some View {
        VStack(spacing: 16) {
            // Fee (show for sent and transfer transactions)
            if (transaction.transactionType == .sent || transaction.transactionType == .transfer) {
                // If both fee types exist, show them separately
                if transaction.hasBothFeeTypes {
                    /*
                    if let offchainFee = transaction.formattedFee {
                        DetailRow(
                            title: "Offchain Fee",
                            value: offchainFee
                        )
                    }
                    if let onchainFee = transaction.formattedOnchainFee {
                        Divider()
                        DetailRow(
                            title: "Onchain Fee",
                            value: onchainFee
                        )
                    }
                    */
                    // Show total
                    if let totalFee = transaction.formattedTotalFees {
                        Divider()
                        DetailRow(
                            title: "Fee",
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
            
            // Address
            if let address = transaction.address {
                // Extract the actual address value if it's a PaymentMethod JSON object
                let addressValue: String = {
                    if let data = address.data(using: .utf8),
                       let paymentMethod = try? JSONDecoder().decode(PaymentMethod.self, from: data) {
                        return paymentMethod.value
                    } else {
                        // Fallback to the raw string if it's not a PaymentMethod object
                        return address
                    }
                }()
                
                /*
                DetailRow(
                    title: transaction.transactionType == .received ? "From Address" : "To Address",
                    value: addressValue,
                    isCopyable: true,
                    onCopy: { viewModel?.copyToClipboard($0) }
                )
                
                Divider()
                */
                
                VStack(alignment: .leading, spacing: 4) {
                    /*
                    Text(transaction.transactionType == .received ? "From Address" : "To Address")
                        .font(.body)
                        .foregroundColor(.secondary)
                    */
                    
                    AddressCardExpandable(
                        address: addressValue,
                        shareContent: addressValue,
                        label: transaction.transactionType == .received ? "From Address" : "To Address"
                    )
                }
            }
            
            // Explainer text for non-intuitive transaction types
            if let explainerText = transaction.explainerText {
                Text(explainerText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            
            /*
            // Transaction ID
            Divider()
            DetailRow(
                title: "Transaction ID",
                value: transaction.txid,
                isCopyable: true,
                onCopy: { viewModel?.copyToClipboard($0) }
            )
            */
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
                address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
                fees: 0
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
                address: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq",
                fees: 2500
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

#Preview("Boarding Transaction with Onchain Fee") {
    NavigationStack {
        TransactionDetailView_iOS(
            transaction: TransactionModel(
                txid: "movement_1",
                movementId: 1,
                recipientIndex: nil,
                type: TransactionTypeEnum.transfer,
                amount: 50000,
                date: Date().addingTimeInterval(-3600),
                status: TransactionStatusEnum.confirmed,
                address: nil,
                onchainFeeSat: 155,
                category: .boarding
            ),
            onNavigateToContact: nil
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("Transaction with Both Fee Types") {
    NavigationStack {
        TransactionDetailView_iOS(
            transaction: TransactionModel(
                txid: "movement_2",
                movementId: 2,
                recipientIndex: nil,
                type: TransactionTypeEnum.sent,
                amount: 100000,
                date: Date().addingTimeInterval(-7200),
                status: TransactionStatusEnum.confirmed,
                address: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq",
                fees: 500,
                onchainFeeSat: 300,
                category: .lightningSend
            ),
            onNavigateToContact: nil
        )
        .environment(WalletManager(useMock: true))
    }
}
