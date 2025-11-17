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
    
    init(
        paymentRequest: PaymentRequest,
        onUseAddress: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        currentNetwork: NetworkConfig? = nil
    ) {
        self.paymentRequest = paymentRequest
        self.onUseAddress = onUseAddress
        self.onDismiss = onDismiss
        self.currentNetwork = currentNetwork
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
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if !isCompatibleWithNetwork {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.headline)
                        }
                        Text(isCompatibleWithNetwork ? "Payment request found in clipboard" : "Incompatible payment request in clipboard")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    if let mismatchMessage = networkMismatchMessage {
                        Text(mismatchMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                    
                    if let primary = paymentRequest.primaryDestination {
                        Text(primary.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text(primary.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Show payment request metadata
                    VStack(alignment: .leading, spacing: 2) {
                        if let amount = paymentRequest.amount {
                            Text("Amount: \(amount) sats")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let label = paymentRequest.label {
                            Text("Label: \(label)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let message = paymentRequest.message {
                            Text("Message: \(message)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Show alternative payment options if available
                    if paymentRequest.hasAlternatives {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Alternative payment options:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            ForEach(paymentRequest.alternativeDestinations) { destination in
                                HStack(spacing: 4) {
                                    Image(systemName: iconForFormat(destination.format))
                                        .font(.caption2)
                                    Text("\(destination.format.displayName): \(destination.shortAddress)")
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            HStack {
                if isCompatibleWithNetwork {
                    Button("Use Payment Request") {
                        onUseAddress()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Cannot use this address on current network")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
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
