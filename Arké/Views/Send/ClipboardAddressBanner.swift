//
//  ClipboardAddressBanner.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/24/25.
//

import SwiftUI

struct ClipboardAddressBanner: View {
    let paymentRequest: PaymentRequest
    let onUseAddress: () -> Void
    let onDismiss: () -> Void
    let currentNetwork: NetworkConfig?
    let paymentContext: PaymentDestinationSelector.PaymentContext?
    
    @State private var isAlternativesExpanded = false
    @State private var selectedDestinationId: UUID?
    
    init(
        paymentRequest: PaymentRequest,
        onUseAddress: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        currentNetwork: NetworkConfig? = nil,
        paymentContext: PaymentDestinationSelector.PaymentContext? = nil
    ) {
        self.paymentRequest = paymentRequest
        self.onUseAddress = onUseAddress
        self.onDismiss = onDismiss
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
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 12) {
                        if !isCompatibleWithNetwork {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
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
                    }
                    .padding(.bottom, 10)
                    
                    if let mismatchMessage = networkMismatchMessage {
                        Text(mismatchMessage)
                            .font(.body)
                            .foregroundColor(.orange)
                    }
                    
                    // Show payment request metadata
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
                    
                    // Show optimal destination if context is available
                    if let optimal = optimalDestination {
                        HStack {
                            Text("Pay via \(optimal.balanceSource.displayName)")
                                .font(.body)
                                .foregroundColor(.primary)
                                .fontWeight(.semibold)
                                .padding(.top, 12)
                                .padding(.bottom, 6)

                            Spacer()
                            
                            if !otherViableDestinations.isEmpty {
                                Button(action: {
                                    withAnimation {
                                        isAlternativesExpanded.toggle()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: isAlternativesExpanded ? "chevron.up" : "chevron.down")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                        Text("View other options (\(otherViableDestinations.count))")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        ClipboardPaymentDestinationRow(
                            formatName: optimal.destination.format.displayName,
                            shortAddress: optimal.destination.shortAddress,
                            estimatedFee: optimal.estimatedFee,
                            isSelectable: isAlternativesExpanded,
                            isSelected: selectedDestinationId == optimal.destination.id,
                            onTap: {
                                selectedDestinationId = optimal.destination.id
                            }
                        )
                    } else if let primary = paymentRequest.primaryDestination {
                        // Fallback to primary destination if no context available
                        Text("Address")
                            .font(.body)
                            .foregroundColor(.primary)
                            .fontWeight(.semibold)
                            .padding(.top, 12)
                            .padding(.bottom, 6)
                        
                        ClipboardPaymentDestinationRow(
                            formatName: primary.format.displayName,
                            shortAddress: primary.shortAddress,
                            estimatedFee: nil,
                            isSelectable: isAlternativesExpanded,
                            isSelected: selectedDestinationId == primary.id,
                            onTap: {
                                selectedDestinationId = primary.id
                            }
                        )
                    }
                    
                    // Show other viable alternatives if available
                    if !otherViableDestinations.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            if isAlternativesExpanded {
                                ForEach(otherViableDestinations, id: \.destination.id) { ranked in
                                    ClipboardPaymentDestinationRow(
                                        formatName: ranked.destination.format.displayName,
                                        shortAddress: ranked.destination.shortAddress,
                                        estimatedFee: ranked.estimatedFee,
                                        isSelectable: true,
                                        isSelected: selectedDestinationId == ranked.destination.id,
                                        onTap: {
                                            selectedDestinationId = ranked.destination.id
                                            // TODO: You may want to call a callback here to notify the parent
                                        }
                                    )
                                }
                            }
                        }
                    } else if paymentRequest.hasAlternatives && paymentContext == nil {
                        // Fallback: show all alternatives without ranking if no context
                        VStack(alignment: .leading, spacing: 2) {
                            Button(action: {
                                withAnimation {
                                    isAlternativesExpanded.toggle()
                                }
                            }) {
                                HStack {
                                    Text("Alternative addresses (\(paymentRequest.alternativeDestinations.count))")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: isAlternativesExpanded ? "chevron.up" : "chevron.down")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 6)
                            
                            if isAlternativesExpanded {
                                ForEach(paymentRequest.alternativeDestinations) { destination in
                                    ClipboardPaymentDestinationRow(
                                        formatName: destination.format.displayName,
                                        shortAddress: destination.shortAddress,
                                        estimatedFee: nil,
                                        isSelectable: true,
                                        isSelected: selectedDestinationId == destination.id,
                                        onTap: {
                                            selectedDestinationId = destination.id
                                            // TODO: You may want to call a callback here to notify the parent
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            
            HStack(spacing: 20) {
                if isCompatibleWithNetwork {
                    Button(isSimpleAddress ? "Use Address" : "Use Payment Request") {
                        onUseAddress()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Dismiss") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
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
                ClipboardAddressBanner(
                    paymentRequest: request,
                    onUseAddress: { print("Use Bitcoin address") },
                    onDismiss: { print("Dismiss") }
                )
            }
            
            // Lightning address
            if let request = AddressValidator.parsePaymentRequest("user@lightning.network") {
                ClipboardAddressBanner(
                    paymentRequest: request,
                    onUseAddress: { print("Use Lightning address") },
                    onDismiss: { print("Dismiss") }
                )
            }
            
            // BIP-21 URI with amount
            if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.00100000&label=Test%20Payment") {
                ClipboardAddressBanner(
                    paymentRequest: request,
                    onUseAddress: { print("Use BIP-21 URI") },
                    onDismiss: { print("Dismiss") }
                )
            }
            
            // BIP-21 URI with multiple addresses (Bitcoin, Ark, Lightning)
            if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.00050000&label=Coffee%20Shop&message=Thanks%20for%20the%20coffee&ark=ark1qwertyuiopasdfghjklzxcvbnm&lightning=lnbc500n1pjq8xyzpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq") {
                ClipboardAddressBanner(
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
                ClipboardAddressBanner(
                    paymentRequest: request,
                    onUseAddress: { print("Use mainnet address") },
                    onDismiss: { print("Dismiss") },
                    currentNetwork: .signet
                )
            }
            
            // Testnet address on Signet network - INCOMPATIBLE
            if let request = AddressValidator.parsePaymentRequest("tb1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
                ClipboardAddressBanner(
                    paymentRequest: request,
                    onUseAddress: { print("Use testnet address") },
                    onDismiss: { print("Dismiss") },
                    currentNetwork: .signet
                )
            }
            
            // Testnet address on Testnet network - COMPATIBLE
            if let request = AddressValidator.parsePaymentRequest("tb1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
                ClipboardAddressBanner(
                    paymentRequest: request,
                    onUseAddress: { print("Use testnet address") },
                    onDismiss: { print("Dismiss") },
                    currentNetwork: .testnet
                )
            }
            
            // BIP-21 with mainnet primary but signet ark alternative
            if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.001&ark=tark1signetaddress") {
                ClipboardAddressBanner(
                    paymentRequest: request,
                    onUseAddress: { print("Use mixed network URI") },
                    onDismiss: { print("Dismiss") },
                    currentNetwork: .signet
                )
            }
            
            // Lightning address (network-agnostic) on Signet - COMPATIBLE
            if let request = AddressValidator.parsePaymentRequest("user@lightning.network") {
                ClipboardAddressBanner(
                    paymentRequest: request,
                    onUseAddress: { print("Use Lightning address") },
                    onDismiss: { print("Dismiss") },
                    currentNetwork: .signet
                )
            }
            
            // BIP-353 address (network-agnostic) on Signet - COMPATIBLE
            if let request = AddressValidator.parsePaymentRequest("₿user.example.com") {
                ClipboardAddressBanner(
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
