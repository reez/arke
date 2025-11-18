//
//  QuickPaymentView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/24/25.
//

import SwiftUI

struct QuickPaymentView: View {
    let paymentRequest: PaymentRequest
    let onUseAddress: () -> Void
    let onDismiss: () -> Void
    let onSendImmediately: ((UUID?) -> Void)?
    let currentNetwork: NetworkConfig?
    let paymentContext: PaymentDestinationSelector.PaymentContext?
    
    @State private var isAlternativesExpanded = false
    @State private var selectedDestinationId: UUID?
    
    init(
        paymentRequest: PaymentRequest,
        onUseAddress: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onSendImmediately: ((UUID?) -> Void)? = nil,
        currentNetwork: NetworkConfig? = nil,
        paymentContext: PaymentDestinationSelector.PaymentContext? = nil
    ) {
        self.paymentRequest = paymentRequest
        self.onUseAddress = onUseAddress
        self.onDismiss = onDismiss
        self.onSendImmediately = onSendImmediately
        self.currentNetwork = currentNetwork
        self.paymentContext = paymentContext
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
    
    /// Helper struct to unify destination display data
    private struct DisplayDestination {
        let destination: PaymentDestination
        let estimatedFee: Int?
        let balanceSourceName: String?
    }
    
    /// All destinations as DisplayDestination objects
    private var allDisplayDestinations: [DisplayDestination] {
        if paymentContext != nil {
            // With context: all ranked destinations
            return rankedDestinations.map { ranked in
                DisplayDestination(
                    destination: ranked.destination,
                    estimatedFee: ranked.estimatedFee,
                    balanceSourceName: ranked.balanceSource.displayName
                )
            }
        } else {
            // Without context: primary + alternatives
            var all: [DisplayDestination] = []
            if let primary = paymentRequest.primaryDestination {
                all.append(DisplayDestination(
                    destination: primary,
                    estimatedFee: nil,
                    balanceSourceName: nil
                ))
            }
            all.append(contentsOf: paymentRequest.alternativeDestinations.map { destination in
                DisplayDestination(
                    destination: destination,
                    estimatedFee: nil,
                    balanceSourceName: nil
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
                balanceSourceName: firstRanked.balanceSource.displayName
            )
        } else if let primary = paymentRequest.primaryDestination {
            // Without context: show the primary destination
            return DisplayDestination(
                destination: primary,
                estimatedFee: nil,
                balanceSourceName: nil
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
        if let balanceSourceName = primaryDisplayDestination?.balanceSourceName {
            //return "Pay via \(balanceSourceName)"
            return "Payment Destination"
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
        // Need an amount embedded in the payment request
        guard paymentRequest.amount != nil else { return false }
        
        // Need at least one viable destination
        guard optimalDestination != nil else { return false }
        
        // Need to be compatible with current network
        guard isCompatibleWithNetwork else { return false }
        
        // Need the callback to be provided
        guard onSendImmediately != nil else { return false }
        
        return true
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
                    if !isSimpleAddress {
                        VStack(alignment: .leading, spacing: 2) {
                            if let label = paymentRequest.label {
                                HStack(spacing: 10) {
                                    Text("Label:")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    Text(label)
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                Divider()
                            }
                            if let message = paymentRequest.message {
                                HStack(spacing: 10) {
                                    Text("Message:")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    Text(message)
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                Divider()
                            }
                            if let amount = paymentRequest.amount {
                                HStack(spacing: 10) {
                                    Text("Amount to pay:")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    Text(BitcoinFormatter.shared.formatAmount(amount))
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                Divider()
                            }
                            
                            // Total addresses count
                            HStack(spacing: 10) {
                                Text("\(paymentRequest.destinations.count) addresses included")
                                    .font(.body)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                        .background(.ultraThinMaterial)
                        .cornerRadius(25)
                    }
                    
                    // Unified destination display
                    if let primaryDisplay = primaryDisplayDestination {
                        VStack(spacing: 10) {
                            // Header with label and optional expand button (skip for simple addresses)
                            if !isSimpleAddress {
                                HStack {
                                    Text(primaryDestinationLabel)
                                        .font(.title2)
                                    
                                    Spacer()
                                    
                                    if hasAlternativeDestinations {
                                        Button(action: {
                                            withAnimation {
                                                isAlternativesExpanded.toggle()
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: isAlternativesExpanded ? "chevron.up" : "chevron.down")
                                                    .font(.body)
                                                    .foregroundColor(.secondary)
                                                Text("View options (\(alternativeDisplayDestinations.count))")
                                                    .font(.body)
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            VStack(spacing: 10) {
                                // Primary destination row
                                PaymentDestinationItem(
                                    formatName: primaryDisplay.destination.format.displayName,
                                    shortAddress: primaryDisplay.destination.shortAddress,
                                    estimatedFee: primaryDisplay.estimatedFee,
                                    isSelectable: isAlternativesExpanded,
                                    isSelected: selectedDestinationId == primaryDisplay.destination.id,
                                    onTap: {
                                        selectedDestinationId = primaryDisplay.destination.id
                                    }
                                )
                                
                                // Alternative destinations (when expanded)
                                if isAlternativesExpanded {
                                    ForEach(alternativeDisplayDestinations, id: \.destination.id) { displayDest in
                                        PaymentDestinationItem(
                                            formatName: displayDest.destination.format.displayName,
                                            shortAddress: displayDest.destination.shortAddress,
                                            estimatedFee: displayDest.estimatedFee,
                                            isSelectable: true,
                                            isSelected: selectedDestinationId == displayDest.destination.id,
                                            onTap: {
                                                withAnimation {
                                                    selectedDestinationId = displayDest.destination.id
                                                    isAlternativesExpanded = false
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            HStack(spacing: 20) {
                if isCompatibleWithNetwork {
                    if canSendImmediately {
                        // Complete payment request - show "Send Now" button
                        Button("Send Now") {
                            onSendImmediately?(selectedDestinationId)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        // Incomplete payment request - show "Use Address/Payment Request" button
                        Button(isSimpleAddress ? "Use Address" : "Use Payment Request") {
                            onUseAddress()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Text("Cannot use this address on current network")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Spacer()
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: 400)
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

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Compatible Addresses (No Network Filter)")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Bitcoin address
            if let request = AddressValidator.parsePaymentRequest("bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
                QuickPaymentView(
                    paymentRequest: request,
                    onUseAddress: { print("Use Bitcoin address") },
                    onDismiss: { print("Dismiss") }
                )
            }
            
            Divider()
                .padding(.vertical)
            
            // Lightning address
            if let request = AddressValidator.parsePaymentRequest("user@lightning.network") {
                QuickPaymentView(
                    paymentRequest: request,
                    onUseAddress: { print("Use Lightning address") },
                    onDismiss: { print("Dismiss") }
                )
            }
            
            Divider()
                .padding(.vertical)
            
            // BIP-21 URI with amount
            if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.00100000&label=Test%20Payment") {
                QuickPaymentView(
                    paymentRequest: request,
                    onUseAddress: { print("Use BIP-21 URI") },
                    onDismiss: { print("Dismiss") }
                )
            }
            
            Divider()
                .padding(.vertical)
            
            // BIP-21 URI with multiple addresses (Bitcoin, Ark, Lightning)
            if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.00050000&label=Coffee%20Shop&message=Thanks%20for%20the%20coffee&ark=ark1qwertyuiopasdfghjklzxcvbnm&lightning=lnbc500n1pjq8xyzpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq") {
                QuickPaymentView(
                    paymentRequest: request,
                    onUseAddress: { print("Use Unified BIP-21 URI") },
                    onDismiss: { print("Dismiss") }
                )
            }
            
            Divider()
                .padding(.vertical)
            
            Text("Network Mismatch Scenarios")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Mainnet address on Signet network - INCOMPATIBLE
            if let request = AddressValidator.parsePaymentRequest("bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
                QuickPaymentView(
                    paymentRequest: request,
                    onUseAddress: { print("Use mainnet address") },
                    onDismiss: { print("Dismiss") },
                    currentNetwork: .signet
                )
            }
            
            Divider()
                .padding(.vertical)
            
            // Testnet address on Signet network - INCOMPATIBLE
            if let request = AddressValidator.parsePaymentRequest("tb1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
                QuickPaymentView(
                    paymentRequest: request,
                    onUseAddress: { print("Use testnet address") },
                    onDismiss: { print("Dismiss") },
                    currentNetwork: .signet
                )
            }
            
            Divider()
                .padding(.vertical)
            
            // Testnet address on Testnet network - COMPATIBLE
            if let request = AddressValidator.parsePaymentRequest("tb1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
                QuickPaymentView(
                    paymentRequest: request,
                    onUseAddress: { print("Use testnet address") },
                    onDismiss: { print("Dismiss") },
                    currentNetwork: .testnet
                )
            }
            
            Divider()
                .padding(.vertical)
            
            // BIP-21 with mainnet primary but signet ark alternative
            if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.001&ark=tark1signetaddress") {
                QuickPaymentView(
                    paymentRequest: request,
                    onUseAddress: { print("Use mixed network URI") },
                    onDismiss: { print("Dismiss") },
                    currentNetwork: .signet
                )
            }
            
            Divider()
                .padding(.vertical)
            
            // Lightning address (network-agnostic) on Signet - COMPATIBLE
            if let request = AddressValidator.parsePaymentRequest("user@lightning.network") {
                QuickPaymentView(
                    paymentRequest: request,
                    onUseAddress: { print("Use Lightning address") },
                    onDismiss: { print("Dismiss") },
                    currentNetwork: .signet
                )
            }
            
            Divider()
                .padding(.vertical)
            
            // BIP-353 address (network-agnostic) on Signet - COMPATIBLE
            if let request = AddressValidator.parsePaymentRequest("₿user.example.com") {
                QuickPaymentView(
                    paymentRequest: request,
                    onUseAddress: { print("Use BIP-353 address") },
                    onDismiss: { print("Dismiss") },
                    currentNetwork: .signet
                )
            }
            
            Spacer()
        }
        .padding()
    }
    .frame(width: 600, height: 1400)
}
