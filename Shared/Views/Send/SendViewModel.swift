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
import ArkeUI

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
    var showAddressFormatsPopover = false
    var showDestinationPicker = false
    var sendModalState: SendModalState?
    var showFeeSelectionSheet = false
    var selectedFeePriority: FeePriority = .medium
    var onchainFeeRates: OnchainFeeRates = .default
    
    // MARK: - Fee Calculation State
    /// Cached Lightning fee estimate in satoshis
    private var cachedLightningFee: Int?
    /// Amount used for the cached Lightning fee (to invalidate cache when amount changes)
    private var cachedLightningFeeAmount: Int?
    
    // MARK: - Configuration
    
    /// Returns the minimum send amount based on the destination format
    /// - For onchain (Bitcoin): 546 sats (dust limit)
    /// - For Ark: 1000 sats (placeholder - adjust based on actual requirements)
    /// - For Lightning: 1 sat (no meaningful minimum for Lightning)
    var minimumSendAmount: Int {
        guard let destination = selectedDestination else {
            // No destination selected, use conservative default
            return 0
        }
        
        switch destination.format {
        case .bitcoin, .silentPayments:
            // Bitcoin dust limit
            return 546
        case .ark:
            // Ark minimum (placeholder - adjust based on actual requirements)
            return 0
        case .lightning, .lightningInvoice, .bolt12:
            // Lightning has effectively no minimum
            return 0
        case .bip353, .bip21:
            // These are wrappers, default to conservative value
            return 0
        }
    }
    
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
            bitcoinBalance: walletManager.onchainBalance?.spendableSat,
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
    
    /// Returns the balance source name based on the selected destination
    var availableBalanceName: String {
        guard let destination = selectedDestination else {
            return "Total balance"
        }
        
        let balanceSource = PaymentDestinationSelector.balanceSource(for: destination)
        return balanceSource.displayName
    }
    
    /// Returns the formatted balance amount based on the selected destination
    var availableBalanceAmount: String {
        let balance = maxSpendableAmount
        return BitcoinFormatter.shared.formatAmount(balance)
    }

    /// Returns the estimated fee text for the selected destination
    var feeText: String? {
        guard let destination = selectedDestination else {
            return nil
        }
        
        let ranked = rankedDestinations.first { $0.destination.id == destination.id }
        return ranked?.estimatedFee.map { fee in
            fee > 0 ? BitcoinFormatter.shared.formatAmount(fee) : String(localized: "label_no_fee")
        }
    }
    
    /// Returns the estimated fee amount (in satoshis) for the selected destination
    var feeAmount: Int? {
        guard let destination = selectedDestination else {
            return nil
        }
        
        // For on-chain destinations, use the selected fee priority
        if isOnchainDestination {
            let feeRate = onchainFeeRates.rate(for: selectedFeePriority)
            let amountInt = Int(amount)
            return PaymentDestinationSelector.estimateOnchainFee(
                for: destination,
                amount: amountInt,
                feeRate: feeRate
            )
        }
        
        // For Lightning destinations, use the cached fee if available
        if isLightningDestination {
            if let cached = cachedLightningFee {
                return cached
            }
        }
        
        // For other destinations, use the ranked fee estimate
        let ranked = rankedDestinations.first { $0.destination.id == destination.id }
        return ranked?.estimatedFee
    }
    
    /// Returns the number of viable payment destinations
    var viableDestinationCount: Int {
        rankedDestinations.filter { $0.viable }.count
    }
    
    /// Returns whether multiple viable destinations are available
    var hasMultipleViableDestinations: Bool {
        viableDestinationCount > 1
    }
    
    /// Returns whether the selected destination is an on-chain format that supports fee selection
    var isOnchainDestination: Bool {
        guard let destination = selectedDestination else { return false }
        return destination.format == .bitcoin || destination.format == .silentPayments
    }
    
    /// Returns whether the selected destination is a Lightning-based format
    var isLightningDestination: Bool {
        guard let destination = selectedDestination else { return false }
        return destination.format == .lightning || destination.format == .lightningInvoice || destination.format == .bolt12
    }
    
    /// Returns whether to show the fee disclosure indicator
    var shouldShowFeeDisclosure: Bool {
        return isOnchainDestination
    }
    
    // MARK: - Fee Calculation
    
    /// Calculates Lightning send fee for the current amount and destination
    /// Caches the result to avoid repeated API calls for the same amount
    func calculateLightningFee() async {
        print("⚡️ [SendViewModel] calculateLightningFee() called")
        print("   → isLightningDestination: \(isLightningDestination)")
        print("   → selectedDestination: \(selectedDestination?.format.rawValue ?? "nil")")
        
        guard isLightningDestination else {
            print("   → Not a Lightning destination, clearing cache")
            cachedLightningFee = nil
            cachedLightningFeeAmount = nil
            return
        }
        
        // Determine the amount to use for fee estimation
        let amountToEstimate: Int
        if let paymentAmount = currentPaymentRequest?.amount {
            // Use embedded payment request amount (e.g., Lightning invoice)
            print("   → Using payment request amount: \(paymentAmount) sats")
            amountToEstimate = paymentAmount
        } else if let enteredAmount = Int(amount), enteredAmount > 0 {
            // Use manually entered amount
            print("   → Using entered amount: \(enteredAmount) sats")
            amountToEstimate = enteredAmount
        } else {
            // No amount available, clear cache and return
            print("   → No amount available (paymentRequest: \(currentPaymentRequest?.amount?.description ?? "nil"), entered: '\(amount)')")
            cachedLightningFee = nil
            cachedLightningFeeAmount = nil
            return
        }
        
        // Check if we already have a cached fee for this amount
        if cachedLightningFee != nil, cachedLightningFeeAmount == amountToEstimate {
            print("   → Using cached fee: \(cachedLightningFee!) sats")
            return
        }
        
        print("   → Calling walletManager.estimateLightningSendFee(amountSats: \(amountToEstimate))")
        do {
            let feeEstimate = try await walletManager.estimateLightningSendFee(amountSats: UInt64(amountToEstimate))
            cachedLightningFee = Int(feeEstimate)
            cachedLightningFeeAmount = amountToEstimate
            print("   ✅ Lightning fee estimated: \(feeEstimate) sats for \(amountToEstimate) sats")
        } catch {
            print("   ❌ Failed to estimate Lightning fee: \(error)")
            // Fall back to static estimate on error
            cachedLightningFee = nil
            cachedLightningFeeAmount = nil
        }
    }
    
    // MARK: - Initialization & Setup
    
    /// Handles initial setup when view appears
    /// Implements Option C: automatic clipboard check only when SendView is first opened
    func handleInitialSetup(prefilledRecipient: String?, prefilledContact: ContactModel?) async {
        // Check for pre-filled contact first (highest priority)
        if let contact = prefilledContact, let recipient = prefilledRecipient {
            print("📝 [SendViewModel] Pre-filling contact: \(contact.cachedName)")
            print("   → Recipient address: \(recipient)")
            
            // Check if this is a BIP-353 address that needs resolution
            if BIP353Resolver.isBIP353Format(recipient) {
                print("   → Detected BIP-353 address in contact")
                
                do {
                    let resolved = try await BIP353Resolver.resolve(recipient)
                    print("   ✅ BIP-353 resolved successfully!")
                    print("      → Original: \(resolved.originalAddress)")
                    print("      → Resolved URI: \(resolved.bip21URI)")
                    
                    // Parse the resolved BIP-21 URI instead of the original BIP-353 address
                    if var paymentRequest = AddressValidator.parsePaymentRequest(resolved.bip21URI) {
                        print("   → Parsed resolved URI into payment request")
                        print("      → Destinations: \(paymentRequest.destinations.count)")
                        for (index, dest) in paymentRequest.destinations.enumerated() {
                            print("         [\(index)] format: \(dest.format.rawValue), address: \(dest.shortAddress)")
                        }
                        
                        // Preserve the BIP-353 address as the display string
                        paymentRequest = PaymentRequest(
                            destinations: paymentRequest.destinations,
                            amount: paymentRequest.amount,
                            label: paymentRequest.label,
                            message: paymentRequest.message,
                            originalString: resolved.originalAddress
                        )
                        
                        // Lock in the payment request (ranks destinations, selects optimal, pre-fills amount)
                        currentPaymentRequest = paymentRequest
                        rankedDestinations = paymentRequest.rankedDestinations(context: paymentContext)
                        
                        if let optimal = rankedDestinations.first(where: { $0.viable }) {
                            selectedDestination = optimal.destination
                            print("   → Selected optimal destination: \(optimal.destination.format.rawValue)")
                            error = nil
                        } else {
                            error = "Cannot send to this contact - no viable payment methods"
                        }
                        
                        // Pre-fill amount if embedded in the payment request
                        if let requestAmount = paymentRequest.amount {
                            print("   → Pre-filling amount: \(requestAmount) sats")
                            amount = "\(requestAmount)"
                        }
                        
                        // Calculate Lightning fee if applicable
                        await calculateLightningFee()
                        
                        // Switch to contact mode
                        sendMode = .contact(contact)
                        return
                    }
                } catch {
                    print("   ❌ BIP-353 resolution failed: \(error.localizedDescription)")
                    self.error = "Could not resolve BIP-353 address: \(error.localizedDescription)"
                    sendMode = .manual
                    return
                }
            }
            
            // Parse the recipient address (non-BIP-353 or fallback)
            if let paymentRequest = AddressValidator.parsePaymentRequest(recipient) {
                print("   → Parsed payment request")
                print("      → Destinations: \(paymentRequest.destinations.count)")
                for (index, dest) in paymentRequest.destinations.enumerated() {
                    print("         [\(index)] format: \(dest.format.rawValue), address: \(dest.shortAddress)")
                }
                
                // Lock in the payment request (ranks destinations, selects optimal, pre-fills amount)
                currentPaymentRequest = paymentRequest
                rankedDestinations = paymentRequest.rankedDestinations(context: paymentContext)
                
                if let optimal = rankedDestinations.first(where: { $0.viable }) {
                    selectedDestination = optimal.destination
                    print("   → Selected optimal destination: \(optimal.destination.format.rawValue)")
                    error = nil
                } else {
                    error = "Cannot send to this contact - no viable payment methods"
                }
                
                // Pre-fill amount if embedded in the payment request
                if let requestAmount = paymentRequest.amount {
                    print("   → Pre-filling amount: \(requestAmount) sats")
                    amount = "\(requestAmount)"
                }
                
                // Calculate Lightning fee if applicable
                await calculateLightningFee()
                
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
                    await enterQuickMode(paymentRequest: paymentRequest, source: .manual)
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
    /// Returns true if valid payment info was found and processed
    func checkClipboardForAddress() async -> Bool {
        // Only check if we're in manual entry mode
        /*
        guard case .manual = sendMode else {
            print("🔍 [SendViewModel] Not in manual mode, skipping clipboard check")
            return false 
        }
        */
        
        guard let clipboardString = clipboardService.getCurrentString() else { 
            print("🔍 [SendViewModel] No clipboard content found")
            return false 
        }
        
        let trimmedString = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 [SendViewModel] Checking clipboard content: \(trimmedString)")
        
        // Don't clear state yet - only clear after confirming valid payment data
        // This prevents losing user's partial input if clipboard has invalid data
        
        // Check if clipboard contains a BIP-353 address first
        if BIP353Resolver.isBIP353Format(trimmedString) {
            print("🔍 [SendViewModel] Detected BIP-353 address format: \(trimmedString)")
            
            // Resolve BIP-353 address asynchronously
            do {
                let resolved = try await BIP353Resolver.resolve(trimmedString)
                print("✅ [SendViewModel] BIP-353 resolved successfully!")
                print("   → Original BIP-353: \(resolved.originalAddress)")
                print("   → Resolved BIP-21 URI: \(resolved.bip21URI)")
                print("   → DNSSEC verified: \(resolved.dnssecVerified)")
                
                if !resolved.dnssecVerified {
                    print("⚠️ [SendViewModel] Warning: DNSSEC validation failed for \(trimmedString)")
                    // For v1, just log - future: show security warning to user
                }
                
                // Process the resolved BIP-21 URI, preserving the original BIP-353 address
                print("   → Processing resolved URI...")
                return await processClipboardPaymentRequest(resolved.bip21URI, originalBIP353Address: resolved.originalAddress)
            } catch {
                print("❌ [SendViewModel] BIP-353 resolution failed: \(error.localizedDescription)")
                
                // Fallback: Try Lightning Address resolution if format matches
                return await tryLightningAddressFallback(trimmedString)
            }
        }
        
        // Check if clipboard contains a Lightning Address (user@domain format, non-BIP-353)
        if LightningAddressResolver.isLightningAddressFormat(trimmedString) {
            print("🔍 [SendViewModel] Detected Lightning Address format: \(trimmedString)")
            
            return await tryLightningAddressFallback(trimmedString)
        }
        
        // Not BIP-353, process normally
        return await processClipboardPaymentRequest(trimmedString)
    }
    
    /// Attempts to resolve a Lightning Address, falling back to basic parsing if resolution fails
    /// Returns true if address was successfully processed
    private func tryLightningAddressFallback(_ address: String) async -> Bool {
        do {
            let resolved = try await LightningAddressResolver.resolve(address)
            print("✅ [SendViewModel] Lightning Address validated: \(resolved.originalAddress)")
            print("   → Min: \(resolved.minSendableSats) sats, Max: \(resolved.maxSendableSats) sats")
            
            // Lightning Address is valid, process it
            return await processClipboardPaymentRequest(address)
        } catch {
            print("❌ [SendViewModel] Lightning Address resolution failed: \(error.localizedDescription)")
            
            // Final fallback: Try parsing as a regular address without validation
            if AddressValidator.parsePaymentRequest(address) != nil {
                print("🔄 [SendViewModel] Falling back to parsing as unvalidated Lightning Address")
                return await processClipboardPaymentRequest(address)
            } else {
                print("🔍 [SendViewModel] Address is not a valid payment request")
                return false
            }
        }
    }
    
    /// Processes a payment request string from clipboard and shows it in the UI
    /// - Parameters:
    ///   - paymentString: The payment request string (BIP-21 URI, address, invoice, etc.)
    ///   - originalBIP353Address: The original BIP-353 address if this was resolved from one
    /// - Returns: true if payment request was successfully processed
    private func processClipboardPaymentRequest(_ paymentString: String, originalBIP353Address: String? = nil) async -> Bool {
        print("📋 [SendViewModel] processClipboardPaymentRequest()")
        print("   → paymentString: \(paymentString)")
        print("   → originalBIP353Address: \(originalBIP353Address ?? "nil")")
        
        // Check if clipboard contains a valid payment request
        guard var paymentRequest = AddressValidator.parsePaymentRequest(paymentString) else {
            print("   ❌ Clipboard content is not a valid payment request")
            return false
        }
        
        print("   ✅ Payment request parsed successfully")
        
        // Now that we have valid payment data, clear existing state
        print("🧹 [SendViewModel] Clearing existing state before applying clipboard data")
        manualInput = ""
        amount = ""
        error = nil
        selectedDestination = nil
        rankedDestinations = []
        currentPaymentRequest = nil
        recipientState = .idle
        print("   → Initial destinations count: \(paymentRequest.destinations.count)")
        for (index, dest) in paymentRequest.destinations.enumerated() {
            print("      [\(index)] format: \(dest.format.rawValue), address: \(dest.shortAddress)")
        }
        
        // If this was resolved from a BIP-353 address, preserve that as the original string
        if let bip353Address = originalBIP353Address {
            print("   → Preserving BIP-353 address as originalString: \(bip353Address)")
            paymentRequest = PaymentRequest(
                destinations: paymentRequest.destinations,
                amount: paymentRequest.amount,
                label: paymentRequest.label,
                message: paymentRequest.message,
                originalString: bip353Address  // Store the human-readable BIP-353 address
            )
        }
        
        // Debug log all payment request details from clipboard
        print("   📦 Final payment request details:")
        if let bip353 = originalBIP353Address {
            print("      Resolved from BIP-353: \(bip353)")
        }
        print("      Destinations: \(paymentRequest.destinations.count)")
        if let primary = paymentRequest.primaryDestination {
            print("      Primary format: \(primary.format.rawValue) (\(primary.format.displayName))")
            print("      Primary network: \(primary.network?.displayName ?? "N/A")")
            print("      Primary address: \(primary.address)")
        }
        print("      Amount: \(paymentRequest.amount?.description ?? "N/A") sats")
        print("      Label: \(paymentRequest.label ?? "N/A")")
        print("      Message: \(paymentRequest.message ?? "N/A")")
        print("      Has alternatives: \(paymentRequest.hasAlternatives)")
        
        if paymentRequest.hasAlternatives {
            print("      Alternative destinations:")
            for (index, dest) in paymentRequest.alternativeDestinations.enumerated() {
                print("         [\(index + 1)] \(dest.format.displayName): \(dest.shortAddress)")
            }
        }
        
        // Determine which mode to use based on payment request complexity
        // Match the QR scanner behavior for consistency
        if isSimplePaymentRequest(paymentRequest) {
            // Simple bare address - use manual mode for traditional flow
            print("   → Using manual mode (simple address)")
            lockInPaymentRequest(paymentRequest)
        } else {
            // Rich payment request with metadata - use quick mode for better UX
            print("   → Using quick mode (rich payment request)")
            await enterQuickMode(paymentRequest: paymentRequest, source: .clipboard)
        }
        
        return true
    }
    
    // MARK: - Payment Execution
    
    /// Callback to dismiss the view after successful payment
    var onDismiss: (() -> Void)?
    
    /// Requests a Lightning invoice from an LNURL-pay callback URL
    private func requestLightningInvoice(callback: String, amountMillisats: Int, comment: String?) async throws -> String {
        // Construct the callback URL with amount parameter
        guard var urlComponents = URLComponents(string: callback) else {
            throw SendError.invalidFormat("Invalid LNURL-pay callback URL")
        }
        
        // Add amount parameter (in millisatoshis)
        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "amount", value: String(amountMillisats)))
        
        // Add comment if provided
        if let comment = comment, !comment.isEmpty {
            queryItems.append(URLQueryItem(name: "comment", value: comment))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw SendError.invalidFormat("Failed to construct LNURL-pay callback URL")
        }
        
        // Make the HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30  // Increased to 30 seconds for slow LNURL servers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("   → Requesting invoice from: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("   → Received response (\(data.count) bytes)")
        
        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                print("   ❌ HTTP \(httpResponse.statusCode): \(body)")
                throw SendError.invalidFormat("LNURL-pay callback returned HTTP \(httpResponse.statusCode)")
            }
        }
        
        // Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let body = String(data: data, encoding: .utf8) ?? "(binary data)"
            print("   ❌ Invalid JSON response: \(body)")
            throw SendError.invalidFormat("Invalid JSON response from LNURL-pay callback")
        }
        
        print("   → Response JSON: \(json)")
        
        // Check for error response
        if let status = json["status"] as? String, status == "ERROR" {
            let reason = json["reason"] as? String ?? "Unknown error"
            throw SendError.invalidFormat("LNURL-pay error: \(reason)")
        }
        
        // Extract the invoice (pr = payment request)
        guard let invoice = json["pr"] as? String else {
            throw SendError.invalidFormat("No invoice returned from LNURL-pay callback")
        }
        
        return invoice
    }
    
    /// Executes the payment using the current send state
    func executeSend(paymentRequest: PaymentRequest? = nil, destinationId: UUID? = nil, amount: String? = nil) async throws {
        print("💸 [SendViewModel] executeSend() called")
        print("   → paymentRequest provided: \(paymentRequest != nil)")
        print("   → destinationId provided: \(destinationId?.uuidString ?? "nil")")
        print("   → amount provided: \(amount ?? "nil")")
        
        // Compute ranked destinations from payment request if provided, otherwise use state
        let rankedDestinations: [PaymentDestinationSelector.RankedDestination]
        if let request = paymentRequest {
            rankedDestinations = request.rankedDestinations(context: paymentContext)
            print("   → Using payment request with \(request.destinations.count) destination(s)")
            for (index, dest) in request.destinations.enumerated() {
                print("      [\(index)] format: \(dest.format.rawValue), address: \(dest.shortAddress)")
            }
        } else {
            rankedDestinations = self.rankedDestinations
            print("   → Using state rankedDestinations: \(rankedDestinations.count)")
        }
        
        // Determine the destination to use
        let destination: PaymentDestination
        if let destId = destinationId,
           let found = rankedDestinations.first(where: { $0.destination.id == destId })?.destination {
            destination = found
            print("   → Selected destination by ID: \(destination.format.rawValue)")
        } else if let selected = selectedDestination {
            destination = selected
            print("   → Using selectedDestination: \(destination.format.rawValue)")
        } else if let firstViable = rankedDestinations.first(where: { $0.viable })?.destination {
            destination = firstViable
            print("   → Using first viable destination: \(destination.format.rawValue)")
        } else {
            print("   ❌ No viable destination found!")
            throw SendError.noDestinationSelected
        }
        
        print("   → Final destination format: \(destination.format.rawValue)")
        print("   → Final destination address: \(destination.address)")
        print("   → Final destination network: \(destination.network?.displayName ?? "N/A")")
        
        // Check if amount is locked (Lightning invoice with embedded amount)
        let amountLocked: Bool
        if let request = paymentRequest {
            amountLocked = destination.format == .lightningInvoice && request.amount != nil
        } else {
            amountLocked = isAmountLocked
        }
        
        // For Lightning invoices with embedded amounts, we don't need to validate the amount field
        if amountLocked {
            error = nil
            
            // Pay the Lightning invoice without passing an amount
            _ = try await walletManager.payLightningInvoice(invoice: destination.address, amount: nil)
            return
        }
        
        // Determine the amount to use (parameter override or state)
        let amountString = amount ?? self.amount
        
        // For all other cases, validate the amount field
        guard let amountInt = Int(amountString) else {
            throw SendError.invalidAmount
        }
        
        // Validate amount against viability
        if let ranked = rankedDestinations.first(where: { $0.destination.id == destination.id }) {
            if !ranked.viable {
                throw SendError.destinationNotViable(ranked.reason)
            }
            
            // Check if amount + fee exceeds available balance
            let totalRequired = amountInt + (ranked.estimatedFee ?? 0)
            if let availableBalance = ranked.availableBalance, totalRequired > availableBalance {
                throw SendError.insufficientBalance(required: totalRequired, available: availableBalance)
            }
        }
        
        error = nil
        
        // Route to the appropriate payment method based on destination format
        print("   → Routing payment to format: \(destination.format.rawValue)")
        
        switch destination.format {
        case .bitcoin, .silentPayments:
            print("   → Sending onchain to: \(destination.address)")
            _ = try await walletManager.sendOnchain(to: destination.address, amount: amountInt)
            
        case .lightningInvoice:
            // Check if the invoice already has an embedded amount
            let invoiceHasAmount = paymentRequest?.amount != nil || currentPaymentRequest?.amount != nil
            print("   → Paying Lightning invoice: \(destination.shortAddress)")
            print("   → Invoice has embedded amount: \(invoiceHasAmount)")
            if invoiceHasAmount {
                _ = try await walletManager.payLightningInvoice(invoice: destination.address, amount: nil)
            } else {
                _ = try await walletManager.payLightningInvoice(invoice: destination.address, amount: amountInt)
            }
            
        case .lightning:
            // Lightning address requires two-step LNURL-pay process
            print("   → Paying Lightning address: \(destination.address)")
            print("   → Step 1: Resolving Lightning address to get callback URL...")
            
            // Resolve the Lightning address to get the LNURL-pay endpoint
            let resolved = try await LightningAddressResolver.resolve(destination.address)
            
            print("   → Step 2: Requesting invoice for \(amountInt) sats...")
            
            // Request an invoice from the callback URL with the specified amount
            let invoice = try await requestLightningInvoice(
                callback: resolved.callback,
                amountMillisats: amountInt * 1000,
                comment: nil
            )
            
            print("   → Step 3: Paying invoice: \(invoice.prefix(20))...")
            
            // Pay the invoice
            _ = try await walletManager.payLightningInvoice(invoice: invoice, amount: nil)
            
        case .bolt12:
            // BOLT12 offers use the same payment pathway as BOLT11 invoices
            // Most Lightning implementations handle both transparently
            // Note: BOLT12 offers typically don't have embedded amounts
            print("   → Paying BOLT12 offer: \(destination.shortAddress)")
            _ = try await walletManager.payLightningInvoice(invoice: destination.address, amount: amountInt)
            
        case .ark:
            print("   → Sending Ark to: \(destination.address)")
            _ = try await walletManager.send(to: destination.address, amount: amountInt)
            
        case .bip353:
            // BIP-353 should have been resolved to another format by now
            // This is a fallback - try to send as Ark
            print("   ⚠️ WARNING: BIP-353 destination reached executeSend without resolution!")
            print("   → BIP-353 address: \(destination.address)")
            print("   → Attempting to send as Ark (this will likely fail)")
            _ = try await walletManager.send(to: destination.address, amount: amountInt)
            
        case .bip21:
            // BIP-21 should never be a final destination format
            print("   ❌ ERROR: BIP-21 destination reached executeSend!")
            throw SendError.invalidFormat("BIP-21 is a wrapper format and should be resolved before sending")
        }
    }
    
    /// Custom errors for send operations
    enum SendError: LocalizedError {
        case noDestinationSelected
        case invalidAmount
        case destinationNotViable(String)
        case insufficientBalance(required: Int, available: Int)
        case invalidFormat(String)
        
        var errorDescription: String? {
            switch self {
            case .noDestinationSelected:
                return "No payment destination selected"
            case .invalidAmount:
                return "Invalid amount"
            case .destinationNotViable(let reason):
                return "Cannot send: \(reason)"
            case .insufficientBalance(let required, let available):
                return "Amount + fees (\(required) sats) exceeds available balance (\(available) sats)"
            case .invalidFormat(let message):
                return message
            }
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
            
            // Populate manualInput with the address so it shows in the UI
            let addressToDisplay = paymentRequest.originalString
            manualInput = addressToDisplay
            print("   → Set manualInput to: \(addressToDisplay)")
            
            // Clear any previous errors
            error = nil
            
            // Switch to manual confirmed mode
            sendMode = .manual
            recipientState = .valid
            
            // Calculate Lightning fee if this is a Lightning destination
            Task {
                await calculateLightningFee()
            }
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
    
    /// Ranks a single destination for manual entry mode
    /// This ensures fee calculation and viability checking work when typing addresses manually
    func rankManualDestination(_ destination: PaymentDestination) {
        print("🔍 [SendViewModel] Ranking manual destination: \(destination.format.displayName)")
        
        // Create a minimal payment request with just this destination
        let paymentRequest = PaymentRequest(
            destinations: [destination],
            amount: nil,
            label: nil,
            message: nil,
            originalString: destination.address
        )
        
        // Rank the destination
        rankedDestinations = paymentRequest.rankedDestinations(context: paymentContext)
        
        print("   → Ranked with fee: \(rankedDestinations.first?.estimatedFee?.description ?? "N/A") sats")
        print("   → Viable: \(rankedDestinations.first?.viable ?? false)")
        if let reason = rankedDestinations.first?.reason {
            print("   → Reason: \(reason)")
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
        cachedLightningFee = nil
        cachedLightningFeeAmount = nil
    }
    
    /// Updates the amount and recalculates Lightning fees if needed
    /// Should be called when the user changes the amount in the UI
    func updateAmount(_ newAmount: String) async {
        amount = newAmount
        
        // Recalculate Lightning fee if we have a Lightning destination
        if isLightningDestination {
            await calculateLightningFee()
        }
    }
    
    /// Enters quick mode with a payment request and calculates fees
    func enterQuickMode(paymentRequest: PaymentRequest, source: PaymentRequestSource) async {
        // Store the payment request
        currentPaymentRequest = paymentRequest
        
        // Rank destinations
        rankedDestinations = paymentRequest.rankedDestinations(context: paymentContext)
        
        // Select the optimal destination
        if let optimal = rankedDestinations.first(where: { $0.viable }) {
            selectedDestination = optimal.destination
            
            // Pre-fill amount if embedded in the payment request
            if let requestAmount = paymentRequest.amount {
                amount = "\(requestAmount)"
            }
            
            // Calculate Lightning fee if applicable
            await calculateLightningFee()
        }
        
        // Set the mode
        sendMode = .quick(paymentRequest, source: source)
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
