//
//  QuickPaymentView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/24/25.
//

import SwiftUI

struct QuickPaymentView: View {
    let paymentRequest: PaymentRequest
    let onDismiss: () -> Void
    let onSendImmediately: ((UUID?, String?) -> Void)?
    let currentNetwork: NetworkConfig?
    let paymentContext: PaymentDestinationSelector.PaymentContext?
    let minimumSendArk: Int
    let contactLookup: ((String) -> ContactModel?)?
    let maxSpendableAmount: Int
    let availableBalanceText: String
    let feeText: String
    
    @State private var isAlternativesExpanded = false
    @State private var selectedDestinationId: UUID?
    @State private var enteredAmount: String = ""
    @State private var isSending = false
    
    init(
        paymentRequest: PaymentRequest,
        onDismiss: @escaping () -> Void,
        onSendImmediately: ((UUID?, String?) -> Void)? = nil,
        currentNetwork: NetworkConfig? = nil,
        paymentContext: PaymentDestinationSelector.PaymentContext? = nil,
        minimumSendArk: Int = 0,
        contactLookup: ((String) -> ContactModel?)? = nil,
        maxSpendableAmount: Int = 0,
        availableBalanceText: String = "",
        feeText: String = ""
    ) {
        self.paymentRequest = paymentRequest
        self.onDismiss = onDismiss
        self.onSendImmediately = onSendImmediately
        self.currentNetwork = currentNetwork
        self.paymentContext = paymentContext
        self.minimumSendArk = minimumSendArk
        self.contactLookup = contactLookup
        self.maxSpendableAmount = maxSpendableAmount
        self.availableBalanceText = availableBalanceText
        self.feeText = feeText
    }
    
    // MARK: - Computed Properties
    
    /// Ranked destinations using the selector (if context provided)
    private var rankedDestinations: [PaymentDestinationSelector.RankedDestination] {
        guard let context = paymentContext else { return [] }
        return paymentRequest.rankedDestinations(context: context)
    }
    
    /// The optimal (first viable) destination
    private var optimalDestination: PaymentDestinationSelector.RankedDestination? {
        rankedDestinations.first(where: { $0.viable })
    }
    
    /// Other viable destinations (excluding the optimal one)
    private var otherViableDestinations: [PaymentDestinationSelector.RankedDestination] {
        guard let optimal = optimalDestination else { return [] }
        return rankedDestinations.filter { $0.viable && $0.destination.id != optimal.destination.id }
    }
    
    // MARK: - Unified Display Properties
    
    /// All destinations as DisplayDestination objects
    private var allDisplayDestinations: [DisplayDestination] {
        if paymentContext != nil {
            // With context: all ranked destinations
            return rankedDestinations.map { ranked in
                DisplayDestination(
                    destination: ranked.destination,
                    estimatedFee: ranked.estimatedFee,
                    balanceSourceName: ranked.balanceSource.displayName,
                    matchedContact: contactLookup?(ranked.destination.address)
                )
            }
        } else {
            // Without context: primary + alternatives
            var all: [DisplayDestination] = []
            if let primary = paymentRequest.primaryDestination {
                all.append(DisplayDestination(
                    destination: primary,
                    estimatedFee: nil,
                    balanceSourceName: nil,
                    matchedContact: contactLookup?(primary.address)
                ))
            }
            all.append(contentsOf: paymentRequest.alternativeDestinations.map { destination in
                DisplayDestination(
                    destination: destination,
                    estimatedFee: nil,
                    balanceSourceName: nil,
                    matchedContact: contactLookup?(destination.address)
                )
            })
            return all
        }
    }
    
    /// The primary destination to always show (whether expanded or collapsed)
    private var primaryDisplayDestination: DisplayDestination? {
        // If user has selected a destination, show that one
        if let selectedId = selectedDestinationId,
           let selected = allDisplayDestinations.first(where: { $0.destination.id == selectedId }) {
            return selected
        }
        
        // Otherwise, fall back to default logic
        if paymentContext != nil, let firstRanked = rankedDestinations.first {
            // With context: show the first ranked destination (optimal or first non-viable)
            return DisplayDestination(
                destination: firstRanked.destination,
                estimatedFee: firstRanked.estimatedFee,
                balanceSourceName: firstRanked.balanceSource.displayName,
                matchedContact: contactLookup?(firstRanked.destination.address)
            )
        } else if let primary = paymentRequest.primaryDestination {
            // Without context: show the primary destination
            return DisplayDestination(
                destination: primary,
                estimatedFee: nil,
                balanceSourceName: nil,
                matchedContact: contactLookup?(primary.address)
            )
        }
        return nil
    }
    
    /// Alternative destinations to show when expanded
    private var alternativeDisplayDestinations: [DisplayDestination] {
        guard let primary = primaryDisplayDestination else { return [] }
        
        // Return all destinations except the one currently shown as primary
        return allDisplayDestinations.filter { $0.destination.id != primary.destination.id }
    }
    
    /// Whether there are alternatives to show
    private var hasAlternativeDestinations: Bool {
        !alternativeDisplayDestinations.isEmpty
    }
    
    /// Header label for the primary destination section
    private var primaryDestinationLabel: String {
        if primaryDisplayDestination?.balanceSourceName != nil {
            return "Address"
        } else {
            return "Address"
        }
    }
    
    private var isCompatibleWithNetwork: Bool {
        guard let network = currentNetwork else { return true }
        return paymentRequest.isCompatible(with: network)
    }
    
    private var networkMismatchMessage: String? {
        guard let network = currentNetwork,
              !isCompatibleWithNetwork,
              let primaryNetwork = paymentRequest.primaryNetwork else {
            return nil
        }
        return "This address is for \(primaryNetwork.displayName), but you're on \(network.name)"
    }
    
    private var isSimpleAddress: Bool {
        // Consider it a simple address if there's only one destination and no metadata
        return !paymentRequest.hasAlternatives && 
               paymentRequest.amount == nil && 
               paymentRequest.label == nil && 
               paymentRequest.message == nil
    }
    
    /// Check if payment request has all information needed for immediate send
    private var canSendImmediately: Bool {
        // Need an amount embedded in the payment request OR a valid entered amount
        let hasValidAmount = paymentRequest.amount != nil || isEnteredAmountValid
        guard hasValidAmount else { return false }
        
        // Need at least one viable destination
        guard optimalDestination != nil else { return false }
        
        // Need to be compatible with current network
        guard isCompatibleWithNetwork else { return false }
        
        // Need the callback to be provided
        guard onSendImmediately != nil else { return false }
        
        return true
    }
    
    /// Check if the entered amount is valid
    private var isEnteredAmountValid: Bool {
        guard let amount = Int(enteredAmount) else { return false }
        return amount >= minimumSendArk && amount <= maxSpendableAmount
    }
    
    /// Whether to show the amount input section
    private var needsAmountInput: Bool {
        paymentRequest.amount == nil && isCompatibleWithNetwork
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 25) {
                    HStack(spacing: 20) {
                        if !isCompatibleWithNetwork {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                                .padding(15)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                )
                        } else {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.primary)
                                .font(.title2)
                                .padding(15)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        Text(isCompatibleWithNetwork ?
                             (isSimpleAddress ? "Address found in clipboard" : "Payment request found in clipboard") : 
                             (isSimpleAddress ? "Incompatible address in clipboard" : "Incompatible payment request in clipboard"))
                            .font(.title)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear contact")
                    }
                    
                    if let mismatchMessage = networkMismatchMessage {
                        Text(mismatchMessage)
                            .font(.body)
                            .foregroundColor(.orange)
                    }
                    
                    // Show payment request metadata (hide if simple address)
                    if paymentRequest.label != nil || paymentRequest.message != nil || paymentRequest.amount != nil {
                        PaymentRequestMetadataView(
                            label: paymentRequest.label,
                            message: paymentRequest.message,
                            amount: paymentRequest.amount
                        )
                    }
                    
                    // Unified destination display
                    UnifiedDestinationDisplayView(
                        primaryDisplayDestination: primaryDisplayDestination,
                        alternativeDisplayDestinations: alternativeDisplayDestinations,
                        primaryDestinationLabel: primaryDestinationLabel,
                        isSimpleAddress: isSimpleAddress,
                        isAlternativesExpanded: $isAlternativesExpanded,
                        selectedDestinationId: $selectedDestinationId
                    )
                    .disabled(isSending)
                    
                    // Show amount input when payment request has no amount
                    if needsAmountInput {
                        AmountInputSection(
                            amount: $enteredAmount,
                            maxSpendableAmount: maxSpendableAmount,
                            availableBalanceText: availableBalanceText,
                            feeText: feeText,
                            isAmountLocked: false,
                            lockedAmountReason: nil,
                            minimumSendArk: minimumSendArk
                        )
                        .disabled(isSending)
                    }
                }
            }
            
            HStack(alignment: .center, spacing: 20) {
                if isCompatibleWithNetwork {
                    Button("Send") {
                        guard !isSending else { return }
                        isSending = true
                        
                        // Capture state values before async work
                        let destId = selectedDestinationId
                        let amount = enteredAmount.isEmpty ? nil : enteredAmount
                        
                        onSendImmediately?(destId, amount)
                        isSending = false
                    }
                    .buttonStyle(ArkeButtonStyle())
                    .disabled(!canSendImmediately || isSending)
                } else {
                    Text("Cannot use this address on current network")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: 400)
        .onAppear {
            // Auto-select the optimal destination when the view appears
            if selectedDestinationId == nil {
                selectedDestinationId = optimalDestination?.destination.id
            }
        }
        .onChange(of: paymentRequest.id) {
            // Reset selection when payment request changes
            selectedDestinationId = optimalDestination?.destination.id
        }
    }
    
    private func iconForFormat(_ format: AddressFormat) -> String {
        switch format {
        case .bitcoin:
            return "bitcoinsign.circle"
        case .ark:
            return "building.columns.circle"
        case .lightning, .lightningInvoice:
            return "bolt.circle"
        case .silentPayments:
            return "eye.slash.circle"
        case .bip353:
            return "at.circle"
        case .bip21:
            return "link.circle"
        }
    }
}

#Preview("1 address") {
    VStack(spacing: 20) {
        // Bitcoin address
        if let request = AddressValidator.parsePaymentRequest("bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
            QuickPaymentView(
                paymentRequest: request,
                onDismiss: { print("Dismiss") }
            )
        }
        Spacer()
    }
    .padding()
    .frame(width: 450, height: 450)
}

#Preview("2 addresses") {
    VStack(spacing: 20) {
        // BIP-21 URI with amount
        if let request = AddressValidator.parsePaymentRequest("bitcoin:tb1pxks6xl9e05xc3atcewg2tyyzgqm5n6mj6aduss3f0pau27206stsax872h?ark=tark1pm6sr0fpzqqpu4k5llkn6wdswx48fwjjujgu4gm679lqwudrzghz7a2rx7wuup9cpqq6ssw20") {
            QuickPaymentView(
                paymentRequest: request,
                onDismiss: { print("Dismiss") }
            )
        }
        Spacer()
    }
    .padding()
    .frame(width: 450, height: 650)
}

#Preview("B21 w amount") {
    VStack(spacing: 20) {
        // BIP-21 URI with amount
        if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.00100000&label=Test%20Payment") {
            QuickPaymentView(
                paymentRequest: request,
                onDismiss: { print("Dismiss") }
            )
        }
        Spacer()
    }
    .padding()
    .frame(width: 450, height: 450)
}

#Preview("Lightning address") {
    VStack(spacing: 20) {
        Text("Compatible Addresses (No Network Filter)")
            .font(.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
        
        // Lightning address
        if let request = AddressValidator.parsePaymentRequest("user@lightning.network") {
            QuickPaymentView(
                paymentRequest: request,
                onDismiss: { print("Dismiss") }
            )
        }
        Spacer()
    }
    .padding()
    .frame(width: 450, height: 450)
}

#Preview("B21 w lots") {
    VStack(spacing: 20) {
        // BIP-21 URI with multiple addresses (Bitcoin, Ark, Lightning)
        if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.00050000&label=Coffee%20Shop&message=Thanks%20for%20the%20coffee&ark=ark1qwertyuiopasdfghjklzxcvbnm&lightning=lnbc500n1pjq8xyzpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq") {
            QuickPaymentView(
                paymentRequest: request,
                onDismiss: { print("Dismiss") }
            )
        }
        Spacer()
    }
    .padding()
    .frame(width: 450, height: 650)
}

#Preview("Compat x") {
    VStack(spacing: 20) {
        // Mainnet address on Signet network - INCOMPATIBLE
        if let request = AddressValidator.parsePaymentRequest("bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
            QuickPaymentView(
                paymentRequest: request,
                onDismiss: { print("Dismiss") },
                currentNetwork: .signet
            )
        }
        Spacer()
    }
    .padding()
    .frame(width: 450, height: 650)
}

#Preview("Compat 2x") {
    VStack(spacing: 20) {
        // Testnet address on Signet network - INCOMPATIBLE
        if let request = AddressValidator.parsePaymentRequest("tb1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
            QuickPaymentView(
                paymentRequest: request,
                onDismiss: { print("Dismiss") },
                currentNetwork: .signet
            )
        }
        Spacer()
    }
    .padding()
    .frame(width: 450, height: 650)
}

#Preview("Compat 3") {
    VStack(spacing: 20) {
        // Testnet address on Testnet network - COMPATIBLE
        if let request = AddressValidator.parsePaymentRequest("tb1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
            QuickPaymentView(
                paymentRequest: request,
                onDismiss: { print("Dismiss") },
                currentNetwork: .testnet
            )
        }
        Spacer()
    }
    .padding()
    .frame(width: 450, height: 650)
}

#Preview("Compat 4") {
    VStack(spacing: 20) {
        // BIP-21 with mainnet primary but signet ark alternative
        if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.001&ark=tark1signetaddress") {
            QuickPaymentView(
                paymentRequest: request,
                onDismiss: { print("Dismiss") },
                currentNetwork: .signet
            )
        }
        Spacer()
    }
    .padding()
    .frame(width: 450, height: 650)
}

#Preview("Compat 5") {
    VStack(spacing: 20) {
        // Lightning address (network-agnostic) on Signet - COMPATIBLE
        if let request = AddressValidator.parsePaymentRequest("user@lightning.network") {
            QuickPaymentView(
                paymentRequest: request,
                onDismiss: { print("Dismiss") },
                currentNetwork: .signet
            )
        }
        Spacer()
    }
    .padding()
    .frame(width: 450, height: 650)
}

#Preview("Compat 6") {
    VStack(spacing: 20) {
        // BIP-353 address (network-agnostic) on Signet - COMPATIBLE
        if let request = AddressValidator.parsePaymentRequest("₿user.example.com") {
            QuickPaymentView(
                paymentRequest: request,
                onDismiss: { print("Dismiss") },
                currentNetwork: .signet
            )
        }
        Spacer()
    }
    .padding()
    .frame(width: 450, height: 650)
}
