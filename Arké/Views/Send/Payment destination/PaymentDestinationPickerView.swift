//
//  PaymentDestinationPickerView.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/17/25.
//

import SwiftUI

/// View for selecting between multiple payment destinations when a BIP-21 URI provides alternatives
struct PaymentDestinationPickerView: View {
    let rankedDestinations: [PaymentDestinationSelector.RankedDestination]
    let onSelect: (PaymentDestination) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var viableDestinations: [PaymentDestinationSelector.RankedDestination] {
        rankedDestinations.filter { $0.viable }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose Payment Method")
                    .font(.headline)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Viable destinations
                    if !viableDestinations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Payment Methods")
                                .font(.headline)
                            
                            ForEach(viableDestinations.indices, id: \.self) { index in
                                let ranked = viableDestinations[index]
                                
                                Button(action: {
                                    print("Selected: \(ranked.destination.format.displayName)")
                                    onSelect(ranked.destination)
                                    dismiss()
                                }) {
                                    PaymentDestinationRow(
                                        ranked: ranked,
                                        isRecommended: index == 0
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if viableDestinations.count > 1 {
                                Text("The recommended method is selected based on lowest fees and fastest settlement.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Non-viable destinations
                    let unviableDestinations = rankedDestinations.filter { !$0.viable }
                    if !unviableDestinations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Unavailable")
                                .font(.headline)
                            
                            ForEach(unviableDestinations, id: \.destination.id) { ranked in
                                PaymentDestinationRow(
                                    ranked: ranked,
                                    isRecommended: false
                                )
                                .opacity(0.6)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Preview

#Preview("Multiple Options") {
    let arkDestination = PaymentDestination(
        format: .ark,
        network: .signet,
        address: "tark1qxyzexample1234567890"
    )
    
    let lightningDestination = PaymentDestination(
        format: .lightningInvoice,
        network: .testnet,
        address: "lntb100n1exampleinvoice1234567890"
    )
    
    let bitcoinDestination = PaymentDestination(
        format: .bitcoin,
        network: .signet,
        address: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"
    )
    
    let ranked = [
        PaymentDestinationSelector.RankedDestination(
            destination: arkDestination,
            balanceSource: .ark,
            availableBalance: 500_000,
            estimatedFee: 0,
            viable: true,
            reason: "Sufficient balance",
            priority: 0
        ),
        PaymentDestinationSelector.RankedDestination(
            destination: lightningDestination,
            balanceSource: .arkViaServer,
            availableBalance: 500_000,
            estimatedFee: 100,
            viable: true,
            reason: "Sufficient balance",
            priority: 1
        ),
        PaymentDestinationSelector.RankedDestination(
            destination: bitcoinDestination,
            balanceSource: .bitcoin,
            availableBalance: 1_000_000,
            estimatedFee: 500,
            viable: true,
            reason: "Sufficient balance",
            priority: 2
        )
    ]
    
    return PaymentDestinationPickerView(rankedDestinations: ranked) { destination in
        print("Selected: \(destination.format.displayName)")
    }
}

#Preview("With Unavailable Options") {
    let arkDestination = PaymentDestination(
        format: .ark,
        network: .signet,
        address: "tark1qxyzexample1234567890"
    )
    
    let bitcoinDestination = PaymentDestination(
        format: .bitcoin,
        network: .signet,
        address: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"
    )
    
    let ranked = [
        PaymentDestinationSelector.RankedDestination(
            destination: bitcoinDestination,
            balanceSource: .bitcoin,
            availableBalance: 1_000_000,
            estimatedFee: 500,
            viable: true,
            reason: "Sufficient balance",
            priority: 2
        ),
        PaymentDestinationSelector.RankedDestination(
            destination: arkDestination,
            balanceSource: .ark,
            availableBalance: 100_000,
            estimatedFee: 0,
            viable: false,
            reason: "Insufficient balance (100000 < 600000 sats)",
            priority: 0
        )
    ]
    
    return PaymentDestinationPickerView(rankedDestinations: ranked) { destination in
        print("Selected: \(destination.format.displayName)")
    }
}
