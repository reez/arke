//
//  TransactionDetailView_iOS.swift
//  Arké
//
//  Created by Assistant on 12/8/25.
//

import SwiftUI
import ArkeUI
import Bark

struct TransactionDetailView_iOS: View {
    let transaction: TransactionModel
    let onNavigateToContact: ((ContactModel) -> Void)?
    
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: TransactionDetailViewModel?
    @State private var showAbsoluteDate = false
    
    // Exit claim state
    @State private var exitVtxos: [ExitVtxo] = []
    @State private var estimatedFee: UInt64?
    @State private var isCalculatingFee = false
    @State private var isClaiming = false
    @State private var claimError: String?
    @State private var showClaimError = false
    
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
            print("  subsystemCategory: \(transaction.subsystemCategory ?? "nil")")
            print("  subsystemKind: \(transaction.subsystemKind ?? "nil")")
            print("  subsystemName: \(transaction.subsystemName ?? "nil")")
            print("  notes: \(transaction.notes ?? "nil")")
            print("  associatedContacts: \(transaction.associatedContacts.map { $0.displayName }.joined(separator: ", "))")
            print("  associatedTags: \(transaction.associatedTags.map { $0.name }.joined(separator: ", "))")
            print("=====================================")
            
            // Load exit data for claimable exit banner
            loadExitData()
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
                
                // Claimable Exit Banner
                claimableExitBanner
                    .padding(.horizontal)
                
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
                
                // Exit details (for unilateral exit transactions)
                TransactionExitDetailsView(transaction: transaction)
                    .padding(.horizontal)
                
                // Technical details (for testing/debugging)
                TransactionTechnicalDetailsView(transaction: transaction)
                    .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .ignoresSafeArea(edges: .top)
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
        VStack(spacing: 25) {
            // Transaction Icon and Type (or Contact Avatar if contact exists)
            Group {
                if let contact = transaction.associatedContacts.first {
                    // Show contact avatar
                    ContactAvatarView(
                        avatarData: contact.avatarData,
                        size: 75,
                        fallbackText: contact.displayName
                    )
                    .padding(.top, 120)
                } else {
                    // Show transaction icon
                    transactionIcon
                        .font(.system(size: 32))
                        //.foregroundColor(transaction.transactionType.iconColor)
                        .foregroundColor(.white)
                        .frame(width: 75, height: 75)
                        .background(transactionIconColor)
                        .cornerRadius(15)
                        .padding(.top, 120)
                }
            }
            
            VStack(alignment: .center, spacing: 0) {
                Text(transaction.shortDisplayText(includeStatusPrefix: true))
                    .font(.system(.title, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Amount (transferred amount for internal transfers, net amount for others)
                Text(transaction.formattedDisplayAmount)
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundColor(amountTextColor == .black || amountTextColor == .primary ? .white : amountTextColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            VStack(alignment: .center, spacing: 5) {
                if transaction.isInternalTransfer {
                    Text(transaction.detailedDisplayText(includeStatusPrefix: true))
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                
                HStack(alignment: .center, spacing: 4) {
                    // Fee information (only show for sent/transfer)
                    if transaction.transactionType == .sent || transaction.transactionType == .transfer {
                        let feeText = transaction.formattedTotalFees ?? BitcoinFormatter.shared.formatAmount(0)
                        Text(transaction.hasFees ? "\(feeText) fee" : "No fee")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.75))
                        
                        Text("·")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    
                    Text(showAbsoluteDate ? transaction.formattedDateAbsolute : transaction.formattedDate)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.75))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showAbsoluteDate.toggle()
                        }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Status Badge (only show if not confirmed)
            /*
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
            */
        }
        .colorScheme(.dark)
        .padding(.horizontal)
        .padding(.bottom, 30)
        .background(alignment: .bottom) {
            Color(hex: "#1C1C1C")
            
            Image(backgroundPatternImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .opacity(0.15)
        }
    }
    
    // MARK: - Icon and Color Helpers
    
    /// Returns the appropriate icon Image view based on transaction category or type
    @ViewBuilder
    private var transactionIcon: some View {
        let iconName = transactionIconName
        
        // Check if it's a system symbol (contains dots or common SF Symbol patterns)
        // Asset names we use are: "wallet", "safe"
        // System symbols are: "arrow.up", "arrow.down", "repeat", "clock"
        if iconName.contains(".") || ["repeat", "clock"].contains(iconName) {
            Image(systemName: iconName)
        } else {
            Image(iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
    
    /// Returns the appropriate icon name based on transaction category or type
    private var transactionIconName: String {
        // For internal transfers, use category-specific icons
        if transaction.isInternalTransfer, let _ = transaction.category {
            /*
            // Special case: onchain_send with bark.offboard subsystem should use offboarding icon
            // TODO: This needs a more elegant solution
            if category == .onchainSend, transaction.subsystemName == "bark.offboard" {
                return MovementCategory.offboarding.icon
            }
            
            return category.icon
             */
            
            let imageName: String = {
                if let category = transaction.category {
                    // Special case: onchain_send with bark.offboard subsystem should use offboarding logic
                    if category == .onchainSend, transaction.subsystemName == "bark.offboard" {
                        return "safe"
                    }
                    
                    switch category {
                    case .boarding, .refresh:
                        return "wallet"
                    case .offboarding:
                        return "safe"
                    default:
                        return "wallet" // fallback
                    }
                }
                
                // Check for exit subsystem
                if transaction.subsystemName == "bark.exit" {
                    return "safe"
                }
                
                return "wallet" // fallback
            }()
            return imageName
        }
        
        // For other transactions, use type-based icons
        return transaction.transactionType.iconName
    }
    
    /// Returns the appropriate icon color based on transaction status
    private var transactionIconColor: Color {
        // Special case for unilateral exits: only complete when claimed
        if transaction.subsystemName == "bark.exit" {
            if transaction.subsystemKind == "claimed" {
                // Exit is complete
                if transaction.isInternalTransfer {
                    return .gray
                }
                return transaction.transactionType.iconColor
            } else {
                // Exit is still pending (not yet claimed)
                return .blue
            }
        }
        
        switch transaction.transactionStatus {
        case .confirmed:
            // For confirmed transactions, use semantic colors
            if transaction.isInternalTransfer {
                return .gray
            }
            return transaction.transactionType.iconColor
            
        case .pending:
            return .blue
            
        case .failed:
            return .red
        }
    }
    
    /// Returns the appropriate amount text color based on transaction status
    private var amountTextColor: Color {
        // Special case for unilateral exits: only complete when claimed
        if transaction.subsystemName == "bark.exit" {
            if transaction.subsystemKind == "claimed" {
                // Exit is complete
                if transaction.isInternalTransfer {
                    return .primary
                }
                return transaction.transactionType.amountColor
            } else {
                // Exit is still pending (not yet claimed)
                return .blue
            }
        }
        
        switch transaction.transactionStatus {
        case .confirmed:
            // For confirmed transactions, use semantic colors
            if transaction.isInternalTransfer {
                return .primary
            }
            return transaction.transactionType.amountColor
            
        case .pending:
            return .blue
            
        case .failed:
            return .red
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
    
    // MARK: - Exit Claim Helpers
    
    /// Load exit VTXOs data
    private func loadExitData() {
        guard transaction.subsystemName == "bark.exit" else {
            return
        }
        
        let inputIds = Set(transaction.inputVtxoIds)
        exitVtxos = walletManager.allUnilateralExits.filter { exit in
            inputIds.contains(exit.vtxoId)
        }
        
        // Calculate fee if there are claimable exits
        let hasClaimable = exitVtxos.contains { $0.isClaimable }
        if hasClaimable && estimatedFee == nil {
            Task {
                await calculateFee()
            }
        }
    }
    
    /// Calculate the estimated fee for claiming
    private func calculateFee() async {
        let hasClaimable = exitVtxos.contains { $0.isClaimable }
        guard hasClaimable, !isCalculatingFee else { return }
        
        isCalculatingFee = true
        defer { isCalculatingFee = false }
        
        do {
            let address = walletManager.onchainAddress
            let claimableVtxoIds = exitVtxos.filter { $0.isClaimable }.map { $0.vtxoId }
            
            // Call drainExits to get the fee (without broadcasting)
            let claimTx = try await walletManager.drainExits(
                vtxoIds: claimableVtxoIds,
                address: address,
                feeRateSatPerVb: nil as UInt64?
            )
            
            estimatedFee = claimTx.feeSats
        } catch {
            print("❌ Failed to calculate exit claim fee: \(error)")
            // Don't show error to user for fee calculation failure
        }
    }
    
    /// Perform the exit claim
    private func claimExit() async {
        let hasClaimable = exitVtxos.contains { $0.isClaimable }
        guard hasClaimable else { return }
        
        isClaiming = true
        defer { isClaiming = false }
        
        do {
            print("💰 Claiming exit funds...")
            
            let address = walletManager.onchainAddress
            let claimableVtxoIds = exitVtxos.filter { $0.isClaimable }.map { $0.vtxoId }
            
            // Step 1: Create the claim transaction
            let claimTx = try await walletManager.drainExits(
                vtxoIds: claimableVtxoIds,
                address: address,
                feeRateSatPerVb: nil as UInt64?
            )
            
            print("✅ Exit claim transaction created (Fee: \(claimTx.feeSats) sats)")
            
            // Step 2: Extract the raw transaction from PSBT
            let txHex = try await walletManager.extractTxFromPsbt(psbtBase64: claimTx.psbtBase64)
            
            // Step 3: Broadcast the transaction
            let txid = try await walletManager.broadcastTx(txHex: txHex)
            print("✅ Transaction broadcast successful! TXID: \(txid)")
            
            // Step 4: Progress exits to sync state
            // This will update the exit states to "ClaimInProgress"
            let _ = try await walletManager.progressExits(feeRateSatPerVb: nil as UInt64?)
            
            // Refresh wallet state
            await walletManager.refresh()
            
            // Reload exit data
            loadExitData()
            
        } catch {
            print("❌ Failed to claim exit: \(error)")
            claimError = error.localizedDescription
            showClaimError = true
        }
    }
    
    // MARK: - Claimable Exit Banner
    
    @ViewBuilder
    private var claimableExitBanner: some View {
        TransactionClaimExitBanner(
            exitVtxos: exitVtxos,
            estimatedFee: estimatedFee,
            isCalculatingFee: isCalculatingFee,
            isClaiming: isClaiming,
            onClaim: {
                Task {
                    await claimExit()
                }
            }
        )
        .alert("Claim Failed", isPresented: $showClaimError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = claimError {
                Text(error)
            }
        }
    }
    
    @ViewBuilder
    private var detailsView: some View {
        VStack(spacing: 16) {
            /*
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
            */
            
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
            
            /*
            // Explainer text for non-intuitive transaction types
            if let explainerText = transaction.explainerText {
                Text(explainerText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
             */
            
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
