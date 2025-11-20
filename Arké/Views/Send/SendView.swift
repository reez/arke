//
//  SendView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//
//  Architecture:
//  - Three distinct modes: Manual, Contact, and Quick
//  - Single SendState object that all child views can modify
//  - Mode selection happens once on initialization based on context
//  - Quick mode can transition to Manual (confirmed) when user accepts a bare address
//  - All modes can reset back to Manual (entering) via clearAll()
//

import SwiftUI
import AppKit

struct ModalState: Identifiable {
    let id = UUID()
    let state: SendModalState
}

struct SendView: View {
    // MARK: - Send Mode
    enum SendMode {
        case manual           // Manual entry (entering or confirmed)
        case contact(ContactModel)  // Sending to a saved contact
        case quick(PaymentRequest)  // Clipboard-detected payment request
    }
    
    // MARK: - Send State
    struct SendState {
        var manualInput: String = ""
        var amount: String = ""
        var selectedDestination: PaymentDestination?
        var rankedDestinations: [PaymentDestinationSelector.RankedDestination] = []
        var currentPaymentRequest: PaymentRequest?
        var error: String?
        var recipientState: RecipientState = .idle
    }
    
    // MARK: - Initialization Parameters
    let prefilledRecipient: String?
    let prefilledContact: ContactModel?
    let onNavigateToContact: ((ContactModel) -> Void)?
    let minimumSendArk: Int = 330
    
    @Environment(WalletManager.self) private var manager
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State
    @State private var sendMode: SendMode = .manual
    @State private var sendState = SendState()
    @State private var sendModalState: SendModalState?
    @State private var showAddressFormatsPopover = false
    @State private var showDestinationPicker = false
    
    // MARK: - Initializers
    init(prefilledRecipient: String? = nil, prefilledContact: ContactModel? = nil, onNavigateToContact: ((ContactModel) -> Void)? = nil) {
        self.prefilledRecipient = prefilledRecipient
        self.prefilledContact = prefilledContact
        self.onNavigateToContact = onNavigateToContact
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
        guard let paymentRequest = sendState.currentPaymentRequest else { return false }
        guard let destination = sendState.selectedDestination else { return false }
        return destination.format == .lightningInvoice && paymentRequest.amount != nil
    }
    
    /// Reason why amount is locked
    private var lockedAmountReason: String? {
        guard isAmountLocked else { return nil }
        return "set by Lightning invoice"
    }
    
    /// Returns the maximum spendable amount based on the selected destination
    private var maxSpendableAmount: Int {
        guard let destination = sendState.selectedDestination else {
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
        guard let destination = sendState.selectedDestination else {
            let formattedBalance = BitcoinFormatter.shared.formatAmount(manager.totalBalance?.totalSpendableSat ?? 0)
            return "Total balance: \(formattedBalance)"
        }
        
        let balanceSource = PaymentDestinationSelector.balanceSource(for: destination)
        let balance = maxSpendableAmount
        let formattedBalance = BitcoinFormatter.shared.formatAmount(balance)
        
        return "\(balanceSource.displayName): \(formattedBalance)"
    }

    /// Returns the estimated fee text for the selected destination
    private var feeText: String? {
        guard let destination = sendState.selectedDestination else {
            return nil
        }
        
        let ranked = sendState.rankedDestinations.first { $0.destination.id == destination.id }
        return ranked?.estimatedFee.map { fee in
            fee > 0 ? "Est. fee: \(fee) sats" : "No fees"
        }
    }
    
    /// Returns the number of viable payment destinations
    private var viableDestinationCount: Int {
        sendState.rankedDestinations.filter { $0.viable }.count
    }
    
    /// Returns whether multiple viable destinations are available
    private var hasMultipleViableDestinations: Bool {
        viableDestinationCount > 1
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Three distinct modes
                switch sendMode {
                case .manual:
                    ManualSendView(
                        manualInput: $sendState.manualInput,
                        recipientState: $sendState.recipientState,
                        amount: $sendState.amount,
                        showAddressFormatsPopover: $showAddressFormatsPopover,
                        selectedDestination: $sendState.selectedDestination,
                        maxSpendableAmount: maxSpendableAmount,
                        availableBalanceText: availableBalanceText,
                        feeText: feeText ?? "",
                        isAmountLocked: isAmountLocked,
                        lockedAmountReason: lockedAmountReason,
                        minimumSendArk: minimumSendArk,
                        onSend: {
                            Task {
                                await executeSend()
                            }
                        }
                    )
                    .popover(isPresented: $showAddressFormatsPopover) {
                        AddressFormatsInfoView()
                    }
                    
                case .contact(let contact):
                    ContactPaymentView(
                        contact: contact,
                        contactAddress: prefilledRecipient,
                        onClear: {
                            clearAll()
                        },
                        onNavigateToContact: onNavigateToContact,
                        onSend: {
                            Task {
                                await executeSend()
                            }
                        },
                        amount: $sendState.amount,
                        maxSpendableAmount: maxSpendableAmount,
                        availableBalanceText: availableBalanceText,
                        feeText: feeText ?? "",
                        isAmountLocked: isAmountLocked,
                        lockedAmountReason: lockedAmountReason,
                        minimumSendArk: minimumSendArk
                    )
                    
                case .quick(let paymentRequest):
                    QuickPaymentView(
                        paymentRequest: paymentRequest,
                        onDismiss: {
                            clearAll()
                        },
                        onSendImmediately: { destinationId, enteredAmount in
                            // Capture values immediately to avoid state race conditions
                            let capturedDestinationId = destinationId
                            let capturedAmount = enteredAmount
                            
                            // Determine the amount to send
                            let amountToSend: String?
                            if let entered = capturedAmount, !entered.isEmpty {
                                amountToSend = entered
                            } else if let amount = paymentRequest.amount {
                                amountToSend = "\(amount)"
                            } else {
                                amountToSend = nil
                            }
                            
                            Task {
                                await executeSend(paymentRequest: paymentRequest, destinationId: capturedDestinationId, amount: amountToSend)
                            }
                        },
                        currentNetwork: currentNetworkConfig,
                        paymentContext: paymentContext,
                        minimumSendArk: minimumSendArk,
                        contactLookup: { address in
                            let normalizedAddress = address.lowercased()
                            let contacts = ServiceContainer.shared.contactService.contacts
                            return contacts.first { contact in
                                contact.addresses.contains { $0.normalizedAddress == normalizedAddress }
                            }
                        },
                        maxSpendableAmount: maxSpendableAmount,
                        availableBalanceText: availableBalanceText,
                        feeText: feeText ?? ""
                    )
                }
                
                // Error display
                if let error = sendState.error {
                    ErrorView(
                        errorMessage: error,
                        onRetry: {
                            Task {
                                await executeSend()
                            }
                        },
                        onDismiss: {
                            sendState.error = nil
                        }
                    )
                    .frame(maxWidth: 400)
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
            PaymentDestinationPickerView(rankedDestinations: sendState.rankedDestinations) { destination in
                sendState.selectedDestination = destination
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            checkClipboardForAddress()
        }
    }
    
    // MARK: - Send Execution
    
    /// Executes the payment using the current send state
    @MainActor
    func executeSend(paymentRequest: PaymentRequest? = nil, destinationId: UUID? = nil, amount: String? = nil) async {
        // Compute ranked destinations from payment request if provided, otherwise use state
        let rankedDestinations: [PaymentDestinationSelector.RankedDestination]
        if let request = paymentRequest {
            rankedDestinations = request.rankedDestinations(context: paymentContext)
        } else {
            rankedDestinations = sendState.rankedDestinations
        }
        
        // Determine the destination to use
        let destination: PaymentDestination
        if let destId = destinationId,
           let found = rankedDestinations.first(where: { $0.destination.id == destId })?.destination {
            destination = found
        } else if let selected = sendState.selectedDestination {
            destination = selected
        } else if let firstViable = rankedDestinations.first(where: { $0.viable })?.destination {
            destination = firstViable
        } else {
            sendState.error = "No payment destination selected"
            return
        }
        
        // Check if amount is locked (Lightning invoice with embedded amount)
        let amountLocked: Bool
        if let request = paymentRequest {
            amountLocked = destination.format == .lightningInvoice && request.amount != nil
        } else {
            amountLocked = isAmountLocked
        }
        
        // For Lightning invoices with embedded amounts, we don't need to validate the amount field
        if amountLocked {
            sendModalState = .sending
            sendState.error = nil
            
            do {
                // Pay the Lightning invoice without passing an amount
                _ = try await manager.payLightningInvoice(invoice: destination.address, amount: nil)
                sendModalState = .success
                // Dismiss after a brief delay to show success state
                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
            } catch {
                sendModalState = .error(error.localizedDescription)
                sendState.error = error.localizedDescription
            }
            return
        }
        
        // Determine the amount to use (parameter override or state)
        let amountString = amount ?? sendState.amount
        
        // For all other cases, validate the amount field
        guard let amountInt = Int(amountString) else {
            sendState.error = "Invalid amount"
            return
        }
        
        // Validate amount against viability
        if let ranked = rankedDestinations.first(where: { $0.destination.id == destination.id }) {
            if !ranked.viable {
                sendState.error = "Cannot send: \(ranked.reason)"
                return
            }
            
            // Check if amount + fee exceeds available balance
            let totalRequired = amountInt + (ranked.estimatedFee ?? 0)
            if let availableBalance = ranked.availableBalance, totalRequired > availableBalance {
                sendState.error = "Amount + fees (\(totalRequired) sats) exceeds available balance (\(availableBalance) sats)"
                return
            }
        }
        
        sendModalState = .sending
        sendState.error = nil
        
        do {
            // Route to the appropriate payment method based on destination format
            switch destination.format {
            case .bitcoin, .silentPayments:
                _ = try await manager.sendOnchain(to: destination.address, amount: amountInt)
                
            case .lightningInvoice, .lightning:
                // Check if the invoice already has an embedded amount
                let invoiceHasAmount = paymentRequest?.amount != nil || sendState.currentPaymentRequest?.amount != nil
                if invoiceHasAmount {
                    _ = try await manager.payLightningInvoice(invoice: destination.address, amount: nil)
                } else {
                    _ = try await manager.payLightningInvoice(invoice: destination.address, amount: amountInt)
                }
                
            case .bolt12:
                // BOLT12 offers use the same payment pathway as BOLT11 invoices
                // Most Lightning implementations handle both transparently
                // Note: BOLT12 offers typically don't have embedded amounts
                _ = try await manager.payLightningInvoice(invoice: destination.address, amount: amountInt)
                
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
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            sendModalState = .error(error.localizedDescription)
            sendState.error = error.localizedDescription
        }
    }
    
    // MARK: - State Management Functions
    
    /// Locks in a payment request and switches to manual confirmed mode
    private func lockInPaymentRequest(_ paymentRequest: PaymentRequest) {
        print("🔒 [SendView] Locking in payment request with \(paymentRequest.destinations.count) destination(s)")
        
        // Store the payment request
        sendState.currentPaymentRequest = paymentRequest
        
        // Rank destinations using the selector
        sendState.rankedDestinations = paymentRequest.rankedDestinations(context: paymentContext)
        
        print("🎯 [SendView] Ranked destinations:")
        for (index, ranked) in sendState.rankedDestinations.enumerated() {
            let viableIcon = ranked.viable ? "✓" : "✗"
            print("   \(viableIcon) [\(index + 1)] \(ranked.destination.format.displayName)")
            print("      Balance: \(ranked.balanceSource.displayName)")
            print("      Available: \(ranked.availableBalance?.description ?? "N/A") sats")
            print("      Fee: ~\(ranked.estimatedFee?.description ?? "N/A") sats")
            print("      Reason: \(ranked.reason)")
        }
        
        // Select the optimal (first viable) destination
        if let optimal = sendState.rankedDestinations.first(where: { $0.viable }) {
            sendState.selectedDestination = optimal.destination
            print("✨ [SendView] Auto-selected optimal destination: \(optimal.destination.format.displayName)")
            
            // Clear any previous errors
            sendState.error = nil
            
            // Switch to manual confirmed mode
            sendMode = .manual
            sendState.recipientState = .valid
        } else {
            sendState.selectedDestination = nil
            // Show error explaining why no destinations are viable
            let reasons = sendState.rankedDestinations.map { "\($0.destination.format.displayName): \($0.reason)" }
            sendState.error = "Cannot send payment. " + reasons.joined(separator: "; ")
            print("⚠️ [SendView] No viable destinations found")
            return
        }
        
        // Pre-fill amount for payment requests with embedded amounts
        if let requestAmount = paymentRequest.amount {
            print("   → Pre-filling amount: \(requestAmount) sats")
            sendState.amount = "\(requestAmount)"
        }
    }
    
    /// Clears all state and returns to manual entry mode
    private func clearAll() {
        print("🔄 [SendView] Clearing all state, returning to manual entry")
        sendMode = .manual
        sendState = SendState()
    }
    
    /// Handles initial setup when view appears
    private func handleInitialSetup() {
        // Check for pre-filled contact first (highest priority)
        if let contact = prefilledContact, let recipient = prefilledRecipient {
            print("📝 [SendView] Pre-filling contact: \(contact.cachedName)")
            
            // Parse the recipient address
            if let paymentRequest = AddressValidator.parsePaymentRequest(recipient) {
                // Lock in the payment request (ranks destinations, selects optimal, pre-fills amount)
                sendState.currentPaymentRequest = paymentRequest
                sendState.rankedDestinations = paymentRequest.rankedDestinations(context: paymentContext)
                
                if let optimal = sendState.rankedDestinations.first(where: { $0.viable }) {
                    sendState.selectedDestination = optimal.destination
                    sendState.error = nil
                } else {
                    sendState.error = "Cannot send to this contact - no viable payment methods"
                }
                
                // Pre-fill amount if embedded in the payment request
                if let requestAmount = paymentRequest.amount {
                    print("   → Pre-filling amount: \(requestAmount) sats")
                    sendState.amount = "\(requestAmount)"
                }
                
                // Switch to contact mode
                sendMode = .contact(contact)
            } else {
                sendState.error = "Invalid contact address"
                sendMode = .manual
            }
            return
        }
        
        // Check for pre-filled recipient (second priority)
        if let recipient = prefilledRecipient {
            print("📝 [SendView] Pre-filling recipient: \(recipient)")
            
            // Parse the pre-filled recipient
            if let paymentRequest = AddressValidator.parsePaymentRequest(recipient) {
                // Show as quick payment if it's a simple address, otherwise lock it in
                if isSimplePaymentRequest(paymentRequest) {
                    sendMode = .quick(paymentRequest)
                } else {
                    lockInPaymentRequest(paymentRequest)
                }
            } else {
                // Invalid pre-filled recipient, show in manual input
                sendState.manualInput = recipient
                sendState.error = "Invalid pre-filled address"
                sendMode = .manual
            }
            return
        }
        
        // Check clipboard for addresses (lowest priority)
        checkClipboardForAddress()
    }
    
    /// Checks if a payment request is "simple" (bare address without metadata)
    private func isSimplePaymentRequest(_ paymentRequest: PaymentRequest) -> Bool {
        return !paymentRequest.hasAlternatives && 
               paymentRequest.amount == nil && 
               paymentRequest.label == nil && 
               paymentRequest.message == nil
    }
    
    /// Checks clipboard for valid Bitcoin, Ark, Lightning, BIP-353, or BIP-21 addresses
    private func checkClipboardForAddress() {
        // Only check if we're in manual entry mode
        guard case .manual = sendMode else { return }
        
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { 
            print("🔍 [SendView] No clipboard content found")
            return 
        }
        
        let trimmedString = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 [SendView] Checking clipboard content: \(trimmedString)")
        
        // Check if clipboard contains a BIP-353 address first
        if BIP353Resolver.isBIP353Format(trimmedString) {
            print("🔍 [SendView] Detected BIP-353 address format: \(trimmedString)")
            
            // Resolve BIP-353 address asynchronously
            Task { @MainActor in
                do {
                    let resolved = try await BIP353Resolver.resolve(trimmedString)
                    print("✅ [SendView] BIP-353 resolved to BIP-21 URI: \(resolved.bip21URI)")
                    
                    if !resolved.dnssecVerified {
                        print("⚠️ [SendView] Warning: DNSSEC validation failed for \(trimmedString)")
                        // For v1, just log - future: show security warning to user
                    }
                    
                    // Process the resolved BIP-21 URI, preserving the original BIP-353 address
                    processClipboardPaymentRequest(resolved.bip21URI, originalBIP353Address: resolved.originalAddress)
                } catch {
                    print("❌ [SendView] BIP-353 resolution failed: \(error.localizedDescription)")
                    
                    // Fallback: Try parsing as a normal address (e.g., Lightning Address)
                    // This handles the ambiguous case where alice@example.com might be Lightning
                    if AddressValidator.parsePaymentRequest(trimmedString) != nil {
                        print("🔄 [SendView] Falling back to parsing as regular address")
                        processClipboardPaymentRequest(trimmedString)
                    } else {
                        print("🔍 [SendView] Clipboard content is not a valid payment request after fallback")
                    }
                }
            }
            return
        }
        
        // Not BIP-353, process normally
        processClipboardPaymentRequest(trimmedString)
    }
    
    /// Processes a payment request string from clipboard and shows it in the UI
    /// - Parameters:
    ///   - paymentString: The payment request string (BIP-21 URI, address, invoice, etc.)
    ///   - originalBIP353Address: The original BIP-353 address if this was resolved from one
    private func processClipboardPaymentRequest(_ paymentString: String, originalBIP353Address: String? = nil) {
        // Check if clipboard contains a valid payment request
        guard var paymentRequest = AddressValidator.parsePaymentRequest(paymentString) else {
            print("🔍 [SendView] Clipboard content is not a valid payment request: \(paymentString)")
            return
        }
        
        // If this was resolved from a BIP-353 address, preserve that as the original string
        if let bip353Address = originalBIP353Address {
            paymentRequest = PaymentRequest(
                destinations: paymentRequest.destinations,
                amount: paymentRequest.amount,
                label: paymentRequest.label,
                message: paymentRequest.message,
                originalString: bip353Address  // Store the human-readable BIP-353 address
            )
        }
        
        // Debug log all payment request details from clipboard
        print("🔍 [SendView] Found valid payment request in clipboard:")
        if let bip353 = originalBIP353Address {
            print("   Resolved from BIP-353: \(bip353)")
        }
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
        
        // Show in quick mode
        sendMode = .quick(paymentRequest)
    }
}

#Preview("Empty State - Manual Entry") {
    NavigationStack {
        SendView()
            .environment(WalletManager(useMock: true))
    }
}

#Preview("Pre-filled Bitcoin Address") {
    NavigationStack {
        SendView(
            prefilledRecipient: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            prefilledContact: nil
        )
        .environment(WalletManager(useMock: true))
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
        .environment(WalletManager(useMock: true))
    }
}

#Preview("BIP-21 with Label and Message") {
    NavigationStack {
        SendView(
            prefilledRecipient: "bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.001&label=Coffee%20Shop&message=Order%20%2342"
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("BIP-21 with Label Only") {
    NavigationStack {
        SendView(
            prefilledRecipient: "bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?label=Alice"
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("BIP-21 Multi-Destination") {
    NavigationStack {
        SendView(
            prefilledRecipient: "bitcoin:tb1pxks6xl9e05xc3atcewg2tyyzgqm5n6mj6aduss3f0pau27206stsax872h?amount=0.001&label=Multi-Payment&ark=tark1pm6sr0fpzqqpu4k5llkn6wdswx48fwjjujgu4gm679lqwudrzghz7a2rx7wuup9cpqq6ssw20"
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("Ark Address (No Label)") {
    NavigationStack {
        SendView(
            prefilledRecipient: "tark1pm6sr0fpzqqpu4k5llkn6wdswx48fwjjujgu4gm679lqwudrzghz7a2rx7wuup9cpqq6ssw20"
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("Lightning Invoice") {
    NavigationStack {
        SendView(
            prefilledRecipient: "lnbc1000n1pj9x7zmpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpu"
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("BOLT12 Lightning Offer") {
    NavigationStack {
        SendView(
            prefilledRecipient: "lno1zrxq8pjw7qjlm68mtp7e3yvxee4y5xrgjhhyf2fxhlphpckrvevh50u0q2uumyll60x70znjle4vhrg496pmj4csnrnnxk7tkmf8fjx44zy4sqsrqtk7wvd7uqdv6yfrkpfgqplwggwfh8hnzsc8wzs8e79vphc6kugqqvuu3nm57har2dc73p40jz4xczrvjxdxyksueekymnzlvyytgy5fn8v4hjfxwrszhzkrgvd4hd"
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("BIP-21 with BOLT12 Offer") {
    NavigationStack {
        SendView(
            prefilledRecipient: "bitcoin:?lno=lno1zrxq8pjw7qjlm68mtp7e3yvxee4y5xrgjhhyf2fxhlphpckrvevh50u0q2uumyll60x70znjle4vhrg496pmj4csnrnnxk7tkmf8fjx44zy4sqsrqtk7wvd7uqdv6yfrkpfgqplwggwfh8hnzsc8wzs8e79vphc6kugqqvuu3nm57har2dc73p40jz4xczrvjxdxyksueekymnzlvyytgy5fn8v4hjfxwrszhzkrgvd4hd"
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("Silent Payment Address") {
    NavigationStack {
        SendView(
            prefilledRecipient: "sp1qqgste7k9hx0qftg6qmwlkqtwuy6cycyavzmzj85c6qdfhjdpdjtdgqjuexzk6murw56suy3e0rd2cgqvycxttddwsvgxe2usfpxumr70xc9pkqwv"
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("BIP-353") {
    NavigationStack {
        // Note: This will attempt DNS resolution for ₿alice@example.com
        // In preview mode, it will likely fail and show nothing
        // Real testing requires actual DNS records
        SendView(
            prefilledRecipient: "₿chri@sto.ph"
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("BIP-353 2") {
    NavigationStack {
        // Note: This will attempt DNS resolution first
        // If DNS fails, falls back to Lightning Address parsing
        SendView(
            prefilledRecipient: "chri@sto.ph"
        )
        .environment(WalletManager(useMock: true))
    }
}
