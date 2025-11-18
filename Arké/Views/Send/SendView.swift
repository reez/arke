//
//  SendView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import AppKit

struct ModalState: Identifiable {
    let id = UUID()
    let state: SendModalState
}

struct SendView: View {
    // MARK: - View Mode
    enum Mode {
        case manualEntry
        case confirmedDestination
    }
    
    // MARK: - Initialization Parameters
    let prefilledRecipient: String?
    let prefilledContact: ContactModel?
    
    @Environment(WalletManager.self) private var manager
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State
    @State private var mode: Mode = .manualEntry
    @State private var manualInput = ""
    @State private var amount = ""
    @State private var error: String?
    @State private var sendModalState: SendModalState?
    @State private var clipboardPaymentRequest: PaymentRequest?
    @State private var showContactBanner = true
    @State private var showPaymentRequestBanner = true
    @State private var showAddressFormatsPopover = false
    
    // Payment destination selection state
    @State private var currentPaymentRequest: PaymentRequest?
    @State private var selectedDestination: PaymentDestination?
    @State private var rankedDestinations: [PaymentDestinationSelector.RankedDestination] = []
    @State private var showDestinationPicker = false
    
    // MARK: - Initializers
    init(prefilledRecipient: String? = nil, prefilledContact: ContactModel? = nil) {
        self.prefilledRecipient = prefilledRecipient
        self.prefilledContact = prefilledContact
    }
    
    // MARK: - Computed Properties
    
    /// Returns the current network configuration based on arkInfo
    private var currentNetworkConfig: NetworkConfig {
        // Try to get the network from arkInfo
        guard let arkInfo = manager.arkInfo,
              let bitcoinNetwork = arkInfo.bitcoinNetwork else {
            // Fallback to networkConfig if available
            return manager.networkConfig ?? .signet
        }
        
        // Map BitcoinNetwork to NetworkConfig
        switch bitcoinNetwork {
        case .mainnet:
            return .mainnet
        case .testnet:
            return .testnet
        case .signet:
            return .signet
        case .regtest:
            // No predefined regtest config, use signet as fallback
            return .signet
        }
    }
    
    /// Creates payment context for destination selection
    private var paymentContext: PaymentDestinationSelector.PaymentContext {
        PaymentDestinationSelector.PaymentContext(
            arkBalance: manager.arkBalance?.spendableSat,
            bitcoinBalance: manager.onchainBalance?.trustedSpendableSat,
            networkConfig: currentNetworkConfig,
            userPreferences: .default,
            arkServerConnected: true, // TODO: Get from manager
            hasLightningCapability: true // TODO: Get from manager
        )
    }
    
    // MARK: - Computed Properties for Balance Display
    
    /// Checks if the amount is locked (e.g., Lightning invoice with embedded amount)
    private var isAmountLocked: Bool {
        guard let paymentRequest = currentPaymentRequest else { return false }
        guard let destination = selectedDestination else { return false }
        return destination.format == .lightningInvoice && paymentRequest.amount != nil
    }
    
    /// Reason why amount is locked
    private var lockedAmountReason: String? {
        guard isAmountLocked else { return nil }
        return "set by Lightning invoice"
    }
    
    /// Returns the maximum spendable amount based on the selected destination
    private var maxSpendableAmount: Int {
        guard let destination = selectedDestination else {
            // No destination selected, show total balance
            return manager.totalBalance?.totalSpendableSat ?? 0
        }
        
        // Use the selector to get available balance for this specific destination
        if let balance = PaymentDestinationSelector.availableBalance(for: destination, context: paymentContext) {
            return balance
        }
        
        return 0
    }
    
    /// Returns the appropriate balance text based on the selected destination
    private var availableBalanceText: String {
        guard let destination = selectedDestination else {
            let formattedBalance = BitcoinFormatter.shared.formatAmount(manager.totalBalance?.totalSpendableSat ?? 0)
            return "Available: \(formattedBalance) (Total balance)"
        }
        
        let balanceSource = PaymentDestinationSelector.balanceSource(for: destination)
        let balance = maxSpendableAmount
        let formattedBalance = BitcoinFormatter.shared.formatAmount(balance)
        
        // Get estimated fee
        let ranked = rankedDestinations.first { $0.destination.id == destination.id }
        let feeText = ranked?.estimatedFee.map { fee in
            fee > 0 ? " · Est. fee: \(fee) sats" : " · No fees"
        } ?? ""
        
        return "Available: \(formattedBalance) (\(balanceSource.displayName))\(feeText)"
    }
    
    /// Returns the number of viable payment destinations
    private var viableDestinationCount: Int {
        rankedDestinations.filter { $0.viable }.count
    }
    
    /// Returns whether multiple viable destinations are available
    private var hasMultipleViableDestinations: Bool {
        viableDestinationCount > 1
    }
    
    /// Returns true if in manual entry mode (not confirmed)
    private var isManualEntryMode: Bool {
        mode == .manualEntry
    }
    
    /// Determines if we should show the payment request info banner
    private var shouldShowPaymentRequestBanner: Bool {
        // Only show in confirmed mode
        guard mode == .confirmedDestination else { return false }
        
        // Don't show if already showing contact banner
        guard prefilledContact == nil || !showContactBanner else { return false }
        
        // Show banner if:
        // 1. Has a label (merchant name, contact name, etc.)
        // 2. Has a message (order details, memo, etc.)
        // 3. Has multiple destinations (unified payment request)
        if let request = currentPaymentRequest {
            return (request.label != nil || 
                    request.message != nil || 
                    request.hasAlternatives) && 
                   showPaymentRequestBanner
        }
        
        return false
    }
    
    /// Determines if we should show the manual input field
    private var shouldShowManualInput: Bool {
        // Only show manual input in manual entry mode
        guard mode == .manualEntry else { return false }
        
        // Hide manual input if clipboard banner is visible
        // This forces user to make an explicit choice about the clipboard content
        return clipboardPaymentRequest == nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // BANNER SECTION
                // Contact info banner (when sending to a known contact)
                if let contact = prefilledContact, showContactBanner {
                    ContactInfoBanner(contact: contact, onClear: {
                        clearAll()
                    })
                }
                
                // Payment request info banner (when using BIP-21 with metadata)
                if shouldShowPaymentRequestBanner, let paymentRequest = currentPaymentRequest {
                    PaymentRequestInfoBanner(
                        paymentRequest: paymentRequest,
                        onClear: {
                            clearAll()
                        }
                    )
                }
                
                // Clipboard prompt banner
                if let paymentRequest = clipboardPaymentRequest {
                    ClipboardAddressBanner(
                        paymentRequest: paymentRequest,
                        onUseAddress: {
                            lockInPaymentRequest(paymentRequest)
                            clipboardPaymentRequest = nil
                        },
                        onDismiss: {
                            clipboardPaymentRequest = nil
                        },
                        currentNetwork: currentNetworkConfig,
                        paymentContext: paymentContext
                    )
                }
                
                // MODE SWITCHER: Manual Entry vs Confirmed Destination
                switch mode {
                case .manualEntry:
                    // Only show manual input if clipboard banner is not visible
                    // This forces user to make an explicit choice about clipboard content
                    if shouldShowManualInput {
                        RecipientInputSection(
                            input: $manualInput,
                            onValidPaymentRequest: { paymentRequest in
                                lockInPaymentRequest(paymentRequest)
                            },
                            onShowAddressFormats: {
                                showAddressFormatsPopover = true
                            }
                        )
                        .popover(isPresented: $showAddressFormatsPopover) {
                            AddressFormatsInfoView()
                        }
                    }
                    
                case .confirmedDestination:
                    if let paymentRequest = currentPaymentRequest {
                        ConfirmedDestinationCard(
                            paymentRequest: paymentRequest,
                            selectedDestination: $selectedDestination,
                            rankedDestinations: rankedDestinations,
                            onClear: {
                                clearAll()
                            },
                            onChangeDestination: {
                                showDestinationPicker = true
                            }
                        )
                    }
                }
                
                // Amount section (shown for both modes when destination is confirmed)
                if mode == .confirmedDestination {
                    AmountInputSection(
                        amount: $amount,
                        maxSpendableAmount: maxSpendableAmount,
                        availableBalanceText: availableBalanceText,
                        isAmountLocked: isAmountLocked,
                        lockedAmountReason: lockedAmountReason
                    )
                }
                
                // Error display
                if let error = error {
                    ErrorView(
                        errorMessage: error,
                        onRetry: {
                            sendPayment()
                        },
                        onDismiss: {
                            self.error = nil
                        }
                    )
                }
                
                // Send button (only in confirmed mode)
                if mode == .confirmedDestination {
                    Button("Send") {
                        sendPayment()
                    }
                    .buttonStyle(ArkeButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(sendModalState != nil || selectedDestination == nil || (amount.isEmpty && !isAmountLocked))
                    .padding(.top, 16)
                    
                    Text("Fee calculation is not implemented yet.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: 600)
            .padding(.top, 20)
            .padding()
        }
        .navigationTitle("Send bitcoin")
        .onAppear {
            handleInitialSetup()
        }
        .sheet(item: Binding(
            get: { sendModalState.map { ModalState(state: $0) } },
            set: { _ in sendModalState = nil }
        )) { modalState in
            SendModalView(state: modalState.state)
        }
        .sheet(isPresented: $showDestinationPicker) {
            PaymentDestinationPickerView(rankedDestinations: rankedDestinations) { destination in
                selectedDestination = destination
            }
        }
    }
    
    func sendPayment() {
        // Ensure we have a selected destination
        guard let destination = selectedDestination else {
            error = "No payment destination selected"
            return
        }
        
        // For Lightning invoices with embedded amounts, we don't need to validate the amount field
        if isAmountLocked {
            sendModalState = .sending
            error = nil
            
            Task {
                do {
                    // Pay the Lightning invoice without passing an amount
                    _ = try await manager.payLightningInvoice(invoice: destination.address, amount: nil)
                    sendModalState = .success
                    // Dismiss after a brief delay to show success state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                } catch {
                    sendModalState = .error(error.localizedDescription)
                    self.error = error.localizedDescription
                }
            }
            return
        }
        
        // For all other cases, validate the amount field
        guard let amountInt = Int(amount) else {
            error = "Invalid amount"
            return
        }
        
        // Validate amount against viability
        if let ranked = rankedDestinations.first(where: { $0.destination.id == destination.id }) {
            if !ranked.viable {
                error = "Cannot send: \(ranked.reason)"
                return
            }
            
            // Check if amount + fee exceeds available balance
            let totalRequired = amountInt + (ranked.estimatedFee ?? 0)
            if let availableBalance = ranked.availableBalance, totalRequired > availableBalance {
                error = "Amount + fees (\(totalRequired) sats) exceeds available balance (\(availableBalance) sats)"
                return
            }
        }
        
        sendModalState = .sending
        error = nil
        
        Task {
            do {
                // Route to the appropriate payment method based on destination format
                switch destination.format {
                case .bitcoin, .silentPayments:
                    _ = try await manager.sendOnchain(to: destination.address, amount: amountInt)
                    
                case .lightningInvoice, .lightning:
                    // Check if the invoice already has an embedded amount
                    let invoiceHasAmount = currentPaymentRequest?.amount != nil
                    if invoiceHasAmount {
                        _ = try await manager.payLightningInvoice(invoice: destination.address, amount: nil)
                    } else {
                        _ = try await manager.payLightningInvoice(invoice: destination.address, amount: amountInt)
                    }
                    
                case .ark:
                    _ = try await manager.send(to: destination.address, amount: amountInt)
                    
                case .bip353:
                    // BIP-353 should have been resolved to another format by now
                    // This is a fallback - try to send as Ark
                    _ = try await manager.send(to: destination.address, amount: amountInt)
                    
                case .bip21:
                    // BIP-21 should never be a final destination format
                    throw NSError(domain: "SendView", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "BIP-21 is a wrapper format and should be resolved before sending"
                    ])
                }
                
                sendModalState = .success
                // Dismiss after a brief delay to show success state
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch {
                sendModalState = .error(error.localizedDescription)
                self.error = error.localizedDescription
            }
        }
    }
    
    // MARK: - State Management Functions
    
    /// Locks in a payment request and switches to confirmed mode
    private func lockInPaymentRequest(_ paymentRequest: PaymentRequest) {
        print("🔒 [SendView] Locking in payment request with \(paymentRequest.destinations.count) destination(s)")
        
        // Store the payment request
        currentPaymentRequest = paymentRequest
        
        // Rank destinations using the selector
        rankedDestinations = paymentRequest.rankedDestinations(context: paymentContext)
        
        print("🎯 [SendView] Ranked destinations:")
        for (index, ranked) in rankedDestinations.enumerated() {
            let viableIcon = ranked.viable ? "✓" : "✗"
            print("   \(viableIcon) [\(index + 1)] \(ranked.destination.format.displayName)")
            print("      Balance: \(ranked.balanceSource.displayName)")
            print("      Available: \(ranked.availableBalance?.description ?? "N/A") sats")
            print("      Fee: ~\(ranked.estimatedFee?.description ?? "N/A") sats")
            print("      Reason: \(ranked.reason)")
        }
        
        // Select the optimal (first viable) destination
        if let optimal = rankedDestinations.first(where: { $0.viable }) {
            selectedDestination = optimal.destination
            print("✨ [SendView] Auto-selected optimal destination: \(optimal.destination.format.displayName)")
            
            // Clear any previous errors
            error = nil
            
            // Switch to confirmed mode
            mode = .confirmedDestination
        } else {
            selectedDestination = nil
            // Show error explaining why no destinations are viable
            let reasons = rankedDestinations.map { "\($0.destination.format.displayName): \($0.reason)" }
            error = "Cannot send payment. " + reasons.joined(separator: "; ")
            print("⚠️ [SendView] No viable destinations found")
            return
        }
        
        // Pre-fill amount for payment requests with embedded amounts
        if let requestAmount = paymentRequest.amount {
            print("   → Pre-filling amount: \(requestAmount) sats")
            amount = "\(requestAmount)"
        }
    }
    
    /// Clears all state and returns to manual entry mode
    private func clearAll() {
        print("🔄 [SendView] Clearing all state, returning to manual entry")
        mode = .manualEntry
        manualInput = ""
        amount = ""
        currentPaymentRequest = nil
        selectedDestination = nil
        rankedDestinations = []
        error = nil
        showContactBanner = false
        showPaymentRequestBanner = false
    }
    
    /// Handles initial setup when view appears
    private func handleInitialSetup() {
        // Prefill recipient if provided
        if let prefilledRecipient = prefilledRecipient {
            print("📝 [SendView] Pre-filling recipient: \(prefilledRecipient)")
            
            // Parse the pre-filled recipient
            if let paymentRequest = AddressValidator.parsePaymentRequest(prefilledRecipient) {
                lockInPaymentRequest(paymentRequest)
            } else {
                // Invalid pre-filled recipient, show in manual input
                manualInput = prefilledRecipient
                error = "Invalid pre-filled address"
            }
        } else {
            // Check clipboard for addresses
            checkClipboardForAddress()
        }
    }
    
    /// Checks clipboard for valid Bitcoin, Ark, Lightning, BIP-353, or BIP-21 addresses
    private func checkClipboardForAddress() {
        // Only check if we're in manual entry mode
        guard mode == .manualEntry else { return }
        
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { 
            print("🔍 [SendView] No clipboard content found")
            return 
        }
        
        let trimmedString = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 [SendView] Checking clipboard content: \(trimmedString)")
        
        // Check if clipboard contains a valid payment request
        guard let paymentRequest = AddressValidator.parsePaymentRequest(trimmedString) else {
            print("🔍 [SendView] Clipboard content is not a valid payment request: \(trimmedString)")
            return
        }
        
        // Debug log all payment request details from clipboard
        print("🔍 [SendView] Found valid payment request in clipboard:")
        print("   Destinations: \(paymentRequest.destinations.count)")
        if let primary = paymentRequest.primaryDestination {
            print("   Primary format: \(primary.format.rawValue) (\(primary.format.displayName))")
            print("   Primary network: \(primary.network?.displayName ?? "N/A")")
            print("   Primary address: \(primary.address)")
        }
        print("   Amount: \(paymentRequest.amount?.description ?? "N/A") sats")
        print("   Label: \(paymentRequest.label ?? "N/A")")
        print("   Message: \(paymentRequest.message ?? "N/A")")
        print("   Has alternatives: \(paymentRequest.hasAlternatives)")
        
        if paymentRequest.hasAlternatives {
            print("   Alternative destinations:")
            for (index, dest) in paymentRequest.alternativeDestinations.enumerated() {
                print("     [\(index + 1)] \(dest.format.displayName): \(dest.shortAddress)")
            }
        }
        
        // Store the payment request for the clipboard banner
        clipboardPaymentRequest = paymentRequest
    }
}

#Preview("Empty State - Manual Entry") {
    NavigationStack {
        SendView()
            .environment(WalletManager())
    }
}

#Preview("Pre-filled Bitcoin Address") {
    NavigationStack {
        SendView(
            prefilledRecipient: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
        )
            .environment(WalletManager())
    }
}

#Preview("Pre-filled Contact") {
    NavigationStack {
        SendView(
            prefilledRecipient: "ark1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            prefilledContact: ContactModel(
                cachedName: "Alice Johnson",
                notes: "Friend from work"
            )
        )
            .environment(WalletManager())
    }
}

#Preview("BIP-21 with Label and Message") {
    NavigationStack {
        SendView(
            prefilledRecipient: "bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.001&label=Coffee%20Shop&message=Order%20%2342"
        )
            .environment(WalletManager())
    }
}

#Preview("BIP-21 with Label Only") {
    NavigationStack {
        SendView(
            prefilledRecipient: "bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?label=Alice"
        )
            .environment(WalletManager())
    }
}

#Preview("BIP-21 Multi-Destination") {
    NavigationStack {
        SendView(
            prefilledRecipient: "bitcoin:tb1pxks6xl9e05xc3atcewg2tyyzgqm5n6mj6aduss3f0pau27206stsax872h?amount=0.001&label=Multi-Payment&ark=tark1pm6sr0fpzqqpu4k5llkn6wdswx48fwjjujgu4gm679lqwudrzghz7a2rx7wuup9cpqq6ssw20"
        )
            .environment(WalletManager())
    }
}

#Preview("Ark Address (No Label)") {
    NavigationStack {
        SendView(
            prefilledRecipient: "tark1pm6sr0fpzqqpu4k5llkn6wdswx48fwjjujgu4gm679lqwudrzghz7a2rx7wuup9cpqq6ssw20"
        )
            .environment(WalletManager())
    }
}

#Preview("Lightning Invoice") {
    NavigationStack {
        SendView(
            prefilledRecipient: "lnbc1000n1pj9x7zmpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpu"
        )
            .environment(WalletManager())
    }
}

#Preview("Silent Payment Address") {
    NavigationStack {
        SendView(
            prefilledRecipient: "sp1qqgste7k9hx0qftg6qmwlkqtwuy6cycyavzmzj85c6qdfhjdpdjtdgqjuexzk6murw56suy3e0rd2cgqvycxttddwsvgxe2usfpxumr70xc9pkqwv"
        )
            .environment(WalletManager())
    }
}
