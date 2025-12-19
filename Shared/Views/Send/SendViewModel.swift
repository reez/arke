//
//  SendViewModel.swift
//  Ark wallet prototype
//
//  Created by Assistant on 12/8/25.
//
//  Architecture:
//  - Three distinct modes: Manual, Contact, and Quick
//  - Single SendState object that all child views can modify
//  - Mode selection happens once on initialization based on context
//  - Quick mode can transition to Manual (confirmed) when user accepts a bare address
//  - All modes can reset back to Manual (entering) via clearAll()
//

import SwiftUI

/// Shared view model for Send flow across macOS and iOS
@Observable
@MainActor
final class SendViewModel {
    
    // MARK: - Send Mode
    enum SendMode {
        case manual           // Manual entry (entering or confirmed)
        case contact(ContactModel)  // Sending to a saved contact
        case quick(PaymentRequest, source: PaymentRequestSource)  // Payment request with source tracking
        
        var description: String {
            switch self {
            case .manual:
                return "manual"
            case .contact(let contact):
                return "contact(\(contact.displayName))"
            case .quick(let request, let source):
                return "quick(\(request.primaryDestination?.shortAddress ?? "unknown"), source: \(source.displayName))"
            }
        }
    }
    
    // MARK: - Dependencies
    private let walletManager: WalletManager
    private let clipboardService: ClipboardServiceProtocol
    
    // MARK: - State
    var manualInput: String = ""
    var amount: String = ""
    var selectedDestination: PaymentDestination?
    var rankedDestinations: [PaymentDestinationSelector.RankedDestination] = []
    var currentPaymentRequest: PaymentRequest?
    var error: String?
    var recipientState: RecipientState = .idle
    var sendMode: SendMode = .manual
    var sendModalState: SendModalState?
    var showAddressFormatsPopover = false
    var showDestinationPicker = false
    
    // MARK: - Configuration
    let minimumSendArk: Int = 330
    
    // MARK: - Clipboard State
    /// Tracks whether clipboard has content available
    var hasClipboardContent: Bool = false
    
    // MARK: - Initialization
    init(walletManager: WalletManager, clipboardService: ClipboardServiceProtocol) {
        self.walletManager = walletManager
        self.clipboardService = clipboardService
    }
    
    // MARK: - Computed Properties
    
    /// Returns the current network configuration based on arkInfo
    var currentNetworkConfig: NetworkConfig {
        // Try to get the network from arkInfo
        guard let arkInfo = walletManager.arkInfo,
              let bitcoinNetwork = arkInfo.bitcoinNetwork else {
            // Fallback to networkConfig if available
            return walletManager.networkConfig ?? .signet
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
    var paymentContext: PaymentDestinationSelector.PaymentContext {
        PaymentDestinationSelector.PaymentContext(
            arkBalance: walletManager.arkBalance?.spendableSat,
            bitcoinBalance: walletManager.onchainBalance?.trustedSpendableSat,
            networkConfig: currentNetworkConfig,
            userPreferences: .default,
            arkServerConnected: true, // TODO: Get from manager
            hasLightningCapability: true // TODO: Get from manager
        )
    }
    
    /// Checks if the amount is locked (e.g., Lightning invoice with embedded amount)
    var isAmountLocked: Bool {
        guard let paymentRequest = currentPaymentRequest else { return false }
        guard let destination = selectedDestination else { return false }
        return destination.format == .lightningInvoice && paymentRequest.amount != nil
    }
    
    /// Reason why amount is locked
    var lockedAmountReason: String? {
        guard isAmountLocked else { return nil }
        return "set by Lightning invoice"
    }
    
    /// Returns the maximum spendable amount based on the selected destination
    var maxSpendableAmount: Int {
        guard let destination = selectedDestination else {
            // No destination selected, show total balance
            return walletManager.totalBalance?.totalSpendableSat ?? 0
        }
        
        // Use the selector to get available balance for this specific destination
        if let balance = PaymentDestinationSelector.availableBalance(for: destination, context: paymentContext) {
            return balance
        }
        
        return 0
    }
    
    /// Returns the appropriate balance text based on the selected destination
    var availableBalanceText: String {
        guard let destination = selectedDestination else {
            let formattedBalance = BitcoinFormatter.shared.formatAmount(walletManager.totalBalance?.totalSpendableSat ?? 0)
            return "Total balance: \(formattedBalance)"
        }
        
        let balanceSource = PaymentDestinationSelector.balanceSource(for: destination)
        let balance = maxSpendableAmount
        let formattedBalance = BitcoinFormatter.shared.formatAmount(balance)
        
        return "\(balanceSource.displayName): \(formattedBalance)"
    }

    /// Returns the estimated fee text for the selected destination
    var feeText: String? {
        guard let destination = selectedDestination else {
            return nil
        }
        
        let ranked = rankedDestinations.first { $0.destination.id == destination.id }
        return ranked?.estimatedFee.map { fee in
            fee > 0 ? "Est. fee: \(fee) sats" : "No fees"
        }
    }
    
    /// Returns the number of viable payment destinations
    var viableDestinationCount: Int {
        rankedDestinations.filter { $0.viable }.count
    }
    
    /// Returns whether multiple viable destinations are available
    var hasMultipleViableDestinations: Bool {
        viableDestinationCount > 1
    }
    
    // MARK: - Initialization & Setup
    
    /// Handles initial setup when view appears
    /// Implements Option C: automatic clipboard check only when SendView is first opened
    func handleInitialSetup(prefilledRecipient: String?, prefilledContact: ContactModel?) async {
        // Check for pre-filled contact first (highest priority)
        if let contact = prefilledContact, let recipient = prefilledRecipient {
            print("📝 [SendViewModel] Pre-filling contact: \(contact.cachedName)")
            
            // Parse the recipient address
            if let paymentRequest = AddressValidator.parsePaymentRequest(recipient) {
                // Lock in the payment request (ranks destinations, selects optimal, pre-fills amount)
                currentPaymentRequest = paymentRequest
                rankedDestinations = paymentRequest.rankedDestinations(context: paymentContext)
                
                if let optimal = rankedDestinations.first(where: { $0.viable }) {
                    selectedDestination = optimal.destination
                    error = nil
                } else {
                    error = "Cannot send to this contact - no viable payment methods"
                }
                
                // Pre-fill amount if embedded in the payment request
                if let requestAmount = paymentRequest.amount {
                    print("   → Pre-filling amount: \(requestAmount) sats")
                    amount = "\(requestAmount)"
                }
                
                // Switch to contact mode
                sendMode = .contact(contact)
            } else {
                error = "Invalid contact address"
                sendMode = .manual
            }
            return
        }
        
        // Check for pre-filled recipient (second priority)
        if let recipient = prefilledRecipient {
            print("📝 [SendViewModel] Pre-filling recipient: \(recipient)")
            
            // Parse the pre-filled recipient
            if let paymentRequest = AddressValidator.parsePaymentRequest(recipient) {
                // Show as quick payment if it's a simple address, otherwise lock it in
                // Pre-filled recipients are treated as manual source since they could come from various places
                if isSimplePaymentRequest(paymentRequest) {
                    sendMode = .quick(paymentRequest, source: .manual)
                } else {
                    lockInPaymentRequest(paymentRequest)
                }
            } else {
                // Invalid pre-filled recipient, show in manual input
                manualInput = recipient
                error = "Invalid pre-filled address"
                sendMode = .manual
            }
            return
        }
        
        // No pre-filled data - start in manual mode
        // Don't check clipboard automatically to avoid permission dialogs
        // User can tap the paste button if they want to paste from clipboard
        sendMode = .manual
    }
    
    // MARK: - Clipboard Detection
    
    /// Checks if clipboard has string content without reading it
    /// On iOS, this is less intrusive and doesn't trigger permission dialogs
    /// On macOS, this freely checks the clipboard
    func checkClipboardAvailability() {
        hasClipboardContent = clipboardService.hasStrings()
        print("🔍 [SendViewModel] Clipboard availability check: \(hasClipboardContent)")
    }
    
    /// Checks clipboard for valid payment requests
    /// This is called when the user explicitly taps the paste button
    func checkClipboardForAddress() async {
        // Only check if we're in manual entry mode
        guard case .manual = sendMode else { return }
        
        guard let clipboardString = clipboardService.getCurrentString() else { 
            print("🔍 [SendViewModel] No clipboard content found")
            return 
        }
        
        let trimmedString = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 [SendViewModel] Checking clipboard content: \(trimmedString)")
        
        // Check if clipboard contains a BIP-353 address first
        if BIP353Resolver.isBIP353Format(trimmedString) {
            print("🔍 [SendViewModel] Detected BIP-353 address format: \(trimmedString)")
            
            // Resolve BIP-353 address asynchronously
            do {
                let resolved = try await BIP353Resolver.resolve(trimmedString)
                print("✅ [SendViewModel] BIP-353 resolved to BIP-21 URI: \(resolved.bip21URI)")
                
                if !resolved.dnssecVerified {
                    print("⚠️ [SendViewModel] Warning: DNSSEC validation failed for \(trimmedString)")
                    // For v1, just log - future: show security warning to user
                }
                
                // Process the resolved BIP-21 URI, preserving the original BIP-353 address
                processClipboardPaymentRequest(resolved.bip21URI, originalBIP353Address: resolved.originalAddress)
            } catch {
                print("❌ [SendViewModel] BIP-353 resolution failed: \(error.localizedDescription)")
                
                // Fallback: Try Lightning Address resolution if format matches
                await tryLightningAddressFallback(trimmedString)
            }
            return
        }
        
        // Check if clipboard contains a Lightning Address (user@domain format, non-BIP-353)
        if LightningAddressResolver.isLightningAddressFormat(trimmedString) {
            print("🔍 [SendViewModel] Detected Lightning Address format: \(trimmedString)")
            
            await tryLightningAddressFallback(trimmedString)
            return
        }
        
        // Not BIP-353, process normally
        processClipboardPaymentRequest(trimmedString)
    }
    
    /// Attempts to resolve a Lightning Address, falling back to basic parsing if resolution fails
    private func tryLightningAddressFallback(_ address: String) async {
        do {
            let resolved = try await LightningAddressResolver.resolve(address)
            print("✅ [SendViewModel] Lightning Address validated: \(resolved.originalAddress)")
            print("   → Min: \(resolved.minSendableSats) sats, Max: \(resolved.maxSendableSats) sats")
            
            // Lightning Address is valid, process it
            processClipboardPaymentRequest(address)
        } catch {
            print("❌ [SendViewModel] Lightning Address resolution failed: \(error.localizedDescription)")
            
            // Final fallback: Try parsing as a regular address without validation
            if AddressValidator.parsePaymentRequest(address) != nil {
                print("🔄 [SendViewModel] Falling back to parsing as unvalidated Lightning Address")
                processClipboardPaymentRequest(address)
            } else {
                print("🔍 [SendViewModel] Address is not a valid payment request")
            }
        }
    }
    
    /// Processes a payment request string from clipboard and shows it in the UI
    /// - Parameters:
    ///   - paymentString: The payment request string (BIP-21 URI, address, invoice, etc.)
    ///   - originalBIP353Address: The original BIP-353 address if this was resolved from one
    private func processClipboardPaymentRequest(_ paymentString: String, originalBIP353Address: String? = nil) {
        // Check if clipboard contains a valid payment request
        guard var paymentRequest = AddressValidator.parsePaymentRequest(paymentString) else {
            print("🔍 [SendViewModel] Clipboard content is not a valid payment request: \(paymentString)")
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
        print("🔍 [SendViewModel] Found valid payment request in clipboard:")
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
        
        // Show in quick mode with clipboard source
        sendMode = .quick(paymentRequest, source: .clipboard)
    }
    
    // MARK: - Payment Execution
    
    /// Callback to dismiss the view after successful payment
    var onDismiss: (() -> Void)?
    
    /// Executes the payment using the current send state
    func executeSend(paymentRequest: PaymentRequest? = nil, destinationId: UUID? = nil, amount: String? = nil) async {
        // Compute ranked destinations from payment request if provided, otherwise use state
        let rankedDestinations: [PaymentDestinationSelector.RankedDestination]
        if let request = paymentRequest {
            rankedDestinations = request.rankedDestinations(context: paymentContext)
        } else {
            rankedDestinations = self.rankedDestinations
        }
        
        // Determine the destination to use
        let destination: PaymentDestination
        if let destId = destinationId,
           let found = rankedDestinations.first(where: { $0.destination.id == destId })?.destination {
            destination = found
        } else if let selected = selectedDestination {
            destination = selected
        } else if let firstViable = rankedDestinations.first(where: { $0.viable })?.destination {
            destination = firstViable
        } else {
            error = "No payment destination selected"
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
            error = nil
            
            do {
                // Pay the Lightning invoice without passing an amount
                _ = try await walletManager.payLightningInvoice(invoice: destination.address, amount: nil)
                sendModalState = .success
                // User will manually dismiss by tapping "Done"
            } catch {
                sendModalState = .error(error.localizedDescription)
                self.error = error.localizedDescription
            }
            return
        }
        
        // Determine the amount to use (parameter override or state)
        let amountString = amount ?? self.amount
        
        // For all other cases, validate the amount field
        guard let amountInt = Int(amountString) else {
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
        
        do {
            // Route to the appropriate payment method based on destination format
            switch destination.format {
            case .bitcoin, .silentPayments:
                _ = try await walletManager.sendOnchain(to: destination.address, amount: amountInt)
                
            case .lightningInvoice, .lightning:
                // Check if the invoice already has an embedded amount
                let invoiceHasAmount = paymentRequest?.amount != nil || currentPaymentRequest?.amount != nil
                if invoiceHasAmount {
                    _ = try await walletManager.payLightningInvoice(invoice: destination.address, amount: nil)
                } else {
                    _ = try await walletManager.payLightningInvoice(invoice: destination.address, amount: amountInt)
                }
                
            case .bolt12:
                // BOLT12 offers use the same payment pathway as BOLT11 invoices
                // Most Lightning implementations handle both transparently
                // Note: BOLT12 offers typically don't have embedded amounts
                _ = try await walletManager.payLightningInvoice(invoice: destination.address, amount: amountInt)
                
            case .ark:
                _ = try await walletManager.send(to: destination.address, amount: amountInt)
                
            case .bip353:
                // BIP-353 should have been resolved to another format by now
                // This is a fallback - try to send as Ark
                _ = try await walletManager.send(to: destination.address, amount: amountInt)
                
            case .bip21:
                // BIP-21 should never be a final destination format
                throw NSError(domain: "SendViewModel", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "BIP-21 is a wrapper format and should be resolved before sending"
                ])
            }
            
            sendModalState = .success
            // User will manually dismiss by tapping "Done"
        } catch {
            sendModalState = .error(error.localizedDescription)
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - State Management
    
    /// Locks in a payment request and switches to manual confirmed mode
    func lockInPaymentRequest(_ paymentRequest: PaymentRequest) {
        print("🔒 [SendViewModel] Locking in payment request with \(paymentRequest.destinations.count) destination(s)")
        
        // Store the payment request
        currentPaymentRequest = paymentRequest
        
        // Rank destinations using the selector
        rankedDestinations = paymentRequest.rankedDestinations(context: paymentContext)
        
        print("🎯 [SendViewModel] Ranked destinations:")
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
            print("✨ [SendViewModel] Auto-selected optimal destination: \(optimal.destination.format.displayName)")
            
            // Clear any previous errors
            error = nil
            
            // Switch to manual confirmed mode
            sendMode = .manual
            recipientState = .valid
        } else {
            selectedDestination = nil
            // Show error explaining why no destinations are viable
            let reasons = rankedDestinations.map { "\($0.destination.format.displayName): \($0.reason)" }
            error = "Cannot send payment. " + reasons.joined(separator: "; ")
            print("⚠️ [SendViewModel] No viable destinations found")
            return
        }
        
        // Pre-fill amount for payment requests with embedded amounts
        if let requestAmount = paymentRequest.amount {
            print("   → Pre-filling amount: \(requestAmount) sats")
            amount = "\(requestAmount)"
        }
    }
    
    /// Clears all state and returns to manual entry mode
    func clearAll() {
        print("🔄 [SendViewModel] Clearing all state, returning to manual entry")
        sendMode = .manual
        manualInput = ""
        amount = ""
        selectedDestination = nil
        rankedDestinations = []
        currentPaymentRequest = nil
        error = nil
        recipientState = .idle
        sendModalState = nil
    }
    
    // MARK: - Helper Methods
    
    /// Checks if a payment request is "simple" (bare address without metadata)
    func isSimplePaymentRequest(_ paymentRequest: PaymentRequest) -> Bool {
        return !paymentRequest.hasAlternatives && 
               paymentRequest.amount == nil && 
               paymentRequest.label == nil && 
               paymentRequest.message == nil
    }
}
