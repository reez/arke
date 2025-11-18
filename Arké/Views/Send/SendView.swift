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
    // MARK: - Initialization Parameters
    let prefilledRecipient: String?
    let prefilledContact: ContactModel?
    
    @Environment(WalletManager.self) private var manager
    @Environment(\.dismiss) var dismiss
    
    @State private var recipient = ""
    @State private var amount = ""
    @State private var error: String?
    @State private var sendModalState: SendModalState?
    @State private var clipboardPaymentRequest: PaymentRequest?
    @State private var clipboardRawString: String? // Store the original clipboard string
    @State private var showContactBanner = true
    @State private var showAddressFormatsPopover = false
    
    // Payment destination selection state
    @State private var currentPaymentRequest: PaymentRequest?
    @State private var selectedDestination: PaymentDestination?
    @State private var rankedDestinations: [PaymentDestinationSelector.RankedDestination] = []
    @State private var showDestinationPicker = false
    @State private var isManualDestinationSelection = false // Track if user manually selected a destination
    
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
    
    /// Checks if the current recipient is a Lightning invoice with an embedded amount
    private var isLightningInvoiceWithAmount: Bool {
        guard let paymentRequest = currentPaymentRequest else { return false }
        guard let destination = selectedDestination else { return false }
        return destination.format == .lightningInvoice && paymentRequest.amount != nil
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Contact info banner (when sending to a known contact)
                if let contact = prefilledContact, showContactBanner {
                    ContactInfoBanner(contact: contact, onClear: {
                        showContactBanner = false
                        recipient = ""
                    })
                }
                
                // Clipboard prompt banner
                if let paymentRequest = clipboardPaymentRequest {
                    ClipboardAddressBanner(
                        paymentRequest: paymentRequest,
                        onUseAddress: {
                            // Use the original raw clipboard string to preserve all payment alternatives
                            // This allows the destination selector to see all options (Bitcoin, Ark, Lightning, etc.)
                            recipient = clipboardRawString ?? paymentRequest.primaryAddress ?? ""
                            // Note: amount pre-filling is handled by handleRecipientChange
                            clipboardPaymentRequest = nil
                            clipboardRawString = nil
                        },
                        onDismiss: {
                            clipboardPaymentRequest = nil
                            clipboardRawString = nil
                        },
                        currentNetwork: currentNetworkConfig,
                        paymentContext: paymentContext
                    )
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Address")
                            .font(.title2)
                        
                        Button(action: {
                            showAddressFormatsPopover.toggle()
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .help("Show supported address formats")
                        .popover(isPresented: $showAddressFormatsPopover) {
                            AddressFormatsInfoView()
                        }
                    }
                    
                    TextField("Enter address...", text: $recipient)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        .font(.system(.title2, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: recipient) { _, newValue in
                            handleRecipientChange(newValue)
                        }
                    
                    // Payment method selector (when multiple viable destinations)
                    if let destination = selectedDestination {
                        HStack {
                            Image(systemName: iconForDestination(destination))
                                .foregroundStyle(colorForDestination(destination))
                            
                            Text("Paying via \(destination.format.displayName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if hasMultipleViableDestinations {
                                Button(action: {
                                    showDestinationPicker = true
                                }) {
                                    HStack(spacing: 4) {
                                        Text("Change")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Amount in satoshis")
                            .font(.title2)
                        
                        if isLightningInvoiceWithAmount {
                            Text("(amount set by invoice)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    TextField("0", text: $amount)
                        .textFieldStyle(.plain)
                        .font(.title2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(isLightningInvoiceWithAmount ? 0.05 : 0.1))
                        .cornerRadius(16)
                        .disabled(isLightningInvoiceWithAmount)
                    
                    HStack(spacing: 0) {
                        Text(BitcoinFormatter.shared.formatAmount(330) + " minimum · ")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if !isLightningInvoiceWithAmount {
                            Button(availableBalanceText) {
                                amount = "\(maxSpendableAmount)"
                            }
                            .font(.body)
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                            .disabled(maxSpendableAmount == 0)
                        } else {
                            Text("Amount is fixed by the Lightning invoice")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
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
                
                Button("Send") {
                    sendPayment()
                }
                .buttonStyle(ArkeButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(sendModalState != nil || selectedDestination == nil || (amount.isEmpty && !isLightningInvoiceWithAmount))
                .padding(.top, 16)
                
                Text("Fee calculation is not implemented yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .frame(maxWidth: 600)
            .padding(.top, 20)
            .padding()
        }
        .navigationTitle("Send bitcoin")
        .onAppear {
            // Prefill recipient if provided
            if let prefilledRecipient = prefilledRecipient {
                recipient = prefilledRecipient
                // Handle amount pre-filling for pre-filled recipients
                handleRecipientChange(prefilledRecipient)
            } else {
                checkClipboardForAddress()
            }
        }

        .sheet(item: Binding(
            get: { sendModalState.map { ModalState(state: $0) } },
            set: { _ in sendModalState = nil }
        )) { modalState in
            SendModalView(state: modalState.state)
        }
        .sheet(isPresented: $showDestinationPicker) {
            PaymentDestinationPickerView(rankedDestinations: rankedDestinations) { destination in
                // Only update the selected destination, don't change the recipient field
                // This preserves the BIP-21 context and all its alternatives
                isManualDestinationSelection = true
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
        if isLightningInvoiceWithAmount {
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
    
    /// Handles recipient field changes to parse payment requests and select destinations
    private func handleRecipientChange(_ newRecipient: String) {
        // Clear previous state when input is empty
        guard !newRecipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            currentPaymentRequest = nil
            selectedDestination = nil
            rankedDestinations = []
            isManualDestinationSelection = false
            return
        }
        
        // Parse the payment request
        guard let paymentRequest = AddressValidator.parsePaymentRequest(newRecipient) else {
            print("🔍 [SendView] Could not parse recipient as payment request: \(newRecipient)")
            error = "Invalid address or payment request"
            currentPaymentRequest = nil
            selectedDestination = nil
            rankedDestinations = []
            isManualDestinationSelection = false
            return
        }
        
        // Check if this is the same payment request (same destinations)
        let isSamePaymentRequest = currentPaymentRequest?.destinations.map { $0.address } == 
                                   paymentRequest.destinations.map { $0.address }
        
        currentPaymentRequest = paymentRequest
        
        // Debug log all payment request details
        print("🔍 [SendView] Parsed payment request details:")
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
        
        // Rank destinations using the selector
        rankedDestinations = paymentRequest.rankedDestinations(context: paymentContext)
        
        print("\n🎯 [SendView] Ranked destinations:")
        for (index, ranked) in rankedDestinations.enumerated() {
            let viableIcon = ranked.viable ? "✓" : "✗"
            print("   \(viableIcon) [\(index + 1)] \(ranked.destination.format.displayName)")
            print("      Balance: \(ranked.balanceSource.displayName)")
            print("      Available: \(ranked.availableBalance?.description ?? "N/A") sats")
            print("      Fee: ~\(ranked.estimatedFee?.description ?? "N/A") sats")
            print("      Reason: \(ranked.reason)")
        }
        
        // If this is the same payment request and user had manually selected a destination,
        // preserve their selection if it's still viable
        if isSamePaymentRequest, 
           isManualDestinationSelection,
           let currentSelection = selectedDestination,
           rankedDestinations.contains(where: { $0.destination.id == currentSelection.id && $0.viable }) {
            print("\n✨ [SendView] Preserving user's manual destination selection: \(currentSelection.format.displayName)")
            // Keep the existing selectedDestination
            error = nil
            return
        }
        
        // Reset manual selection flag for new payment requests
        if !isSamePaymentRequest {
            isManualDestinationSelection = false
        }
        
        // Select the optimal (first viable) destination
        if let optimal = rankedDestinations.first(where: { $0.viable }) {
            selectedDestination = optimal.destination
            print("\n✨ [SendView] Auto-selected optimal destination: \(optimal.destination.format.displayName)")
            
            // Clear any previous errors
            error = nil
        } else {
            selectedDestination = nil
            // Show error explaining why no destinations are viable
            let reasons = rankedDestinations.map { "\($0.destination.format.displayName): \($0.reason)" }
            error = "Cannot send payment. " + reasons.joined(separator: "; ")
            print("\n⚠️ [SendView] No viable destinations found")
        }
        
        // Pre-fill amount for payment requests with embedded amounts
        if let requestAmount = paymentRequest.amount {
            print("   → Pre-filling amount: \(requestAmount) sats")
            amount = "\(requestAmount)"
        }
    }
    
    /// Checks clipboard for valid Bitcoin, Ark, Lightning, BIP-353, or BIP-21 addresses
    private func checkClipboardForAddress() {
        // Only check if recipient field is empty
        guard recipient.isEmpty else { return }
        
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
        
        // Store both the parsed request AND the original string
        // The original string is needed to preserve all alternatives when filling the recipient field
        clipboardPaymentRequest = paymentRequest
        clipboardRawString = trimmedString
    }
    
    // MARK: - Helper Functions
    
    /// Returns an SF Symbol icon name for a payment destination
    private func iconForDestination(_ destination: PaymentDestination) -> String {
        switch destination.format {
        case .ark:
            return "cube.fill"
        case .lightning, .lightningInvoice:
            return "bolt.fill"
        case .bitcoin:
            return "bitcoinsign.circle.fill"
        case .silentPayments:
            return "eye.slash.fill"
        case .bip353:
            return "at.circle.fill"
        case .bip21:
            return "qrcode"
        }
    }
    
    /// Returns a color for a payment destination format
    private func colorForDestination(_ destination: PaymentDestination) -> Color {
        switch destination.format {
        case .ark:
            return .purple
        case .lightning, .lightningInvoice:
            return .orange
        case .bitcoin:
            return .orange
        case .silentPayments:
            return .blue
        case .bip353:
            return .green
        case .bip21:
            return .gray
        }
    }
}

#Preview {
    NavigationStack {
        SendView(
            prefilledRecipient: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            prefilledContact: ContactModel(cachedName: "John Doe")
        )
            .environment(WalletManager())
    }
}
