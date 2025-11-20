//
//  PaymentDestinationRow.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/17/25.
//

import SwiftUI

/// Individual row for a payment destination option
struct PaymentDestinationRow: View {
    let ranked: PaymentDestinationSelector.RankedDestination
    let isRecommended: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Format icon and name
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                
                Text(ranked.destination.format.displayName)
                    .font(.headline)
                
                Spacer()
                
                // Recommended badge
                if isRecommended && ranked.viable {
                    Text("RECOMMENDED")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue, in: Capsule())
                }
            }
            
            // Address preview
            Text(ranked.destination.shortAddress)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospaced()
            
            // Balance source and fee info
            HStack(spacing: 16) {
                Label {
                    Text(ranked.balanceSource.displayName)
                } icon: {
                    Image(systemName: "wallet.pass")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                if let fee = ranked.estimatedFee, fee > 0 {
                    Label {
                        Text("~\(fee) sats")
                    } icon: {
                        Image(systemName: "bitcoinsign.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            
            // Viability reason
            if !ranked.viable {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(ranked.reason)
                }
                .font(.caption)
                .foregroundStyle(.orange)
            } else if !ranked.reason.isEmpty && ranked.reason != "Sufficient balance" {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                    Text(ranked.reason)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch ranked.destination.format {
        case .ark:
            return "cube.fill"
        case .lightning, .lightningInvoice, .bolt12:
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
    
    private var iconColor: Color {
        switch ranked.destination.format {
        case .ark:
            return .purple
        case .lightning, .lightningInvoice, .bolt12:
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

// MARK: - Preview

#Preview("Recommended Viable") {
    let arkDestination = PaymentDestination(
        format: .ark,
        network: .signet,
        address: "tark1qxyzexample1234567890"
    )
    
    let ranked = PaymentDestinationSelector.RankedDestination(
        destination: arkDestination,
        balanceSource: .ark,
        availableBalance: 500_000,
        estimatedFee: 0,
        viable: true,
        reason: "Sufficient balance",
        priority: 0
    )
    
    return List {
        PaymentDestinationRow(ranked: ranked, isRecommended: true)
    }
}

#Preview("Lightning with Fee") {
    let lightningDestination = PaymentDestination(
        format: .lightningInvoice,
        network: .testnet,
        address: "lntb100n1exampleinvoice1234567890"
    )
    
    let ranked = PaymentDestinationSelector.RankedDestination(
        destination: lightningDestination,
        balanceSource: .arkViaServer,
        availableBalance: 500_000,
        estimatedFee: 100,
        viable: true,
        reason: "Sufficient balance",
        priority: 1
    )
    
    return List {
        PaymentDestinationRow(ranked: ranked, isRecommended: false)
    }
}

#Preview("Bitcoin On-chain") {
    let bitcoinDestination = PaymentDestination(
        format: .bitcoin,
        network: .signet,
        address: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"
    )
    
    let ranked = PaymentDestinationSelector.RankedDestination(
        destination: bitcoinDestination,
        balanceSource: .bitcoin,
        availableBalance: 1_000_000,
        estimatedFee: 500,
        viable: true,
        reason: "Sufficient balance",
        priority: 2
    )
    
    return List {
        PaymentDestinationRow(ranked: ranked, isRecommended: false)
    }
}

#Preview("Unavailable - Insufficient Balance") {
    let arkDestination = PaymentDestination(
        format: .ark,
        network: .signet,
        address: "tark1qxyzexample1234567890"
    )
    
    let ranked = PaymentDestinationSelector.RankedDestination(
        destination: arkDestination,
        balanceSource: .ark,
        availableBalance: 100_000,
        estimatedFee: 0,
        viable: false,
        reason: "Insufficient balance (100000 < 600000 sats)",
        priority: 0
    )
    
    return List {
        PaymentDestinationRow(ranked: ranked, isRecommended: false)
            .disabled(true)
            .opacity(0.6)
    }
}

#Preview("Silent Payments") {
    let spDestination = PaymentDestination(
        format: .silentPayments,
        network: .mainnet,
        address: "sp1qqgste7k9hx0qftg6qmwlkqtwuy6cycyavzmzj85c6qdfhjdpdjtdgqjuexzk6murw56suy3e0rd2cgqvycxttddwsvgxe2usfpxumr70xc9pkqwv"
    )
    
    let ranked = PaymentDestinationSelector.RankedDestination(
        destination: spDestination,
        balanceSource: .bitcoin,
        availableBalance: 2_000_000,
        estimatedFee: 300,
        viable: true,
        reason: "Sufficient balance",
        priority: 3
    )
    
    return List {
        PaymentDestinationRow(ranked: ranked, isRecommended: false)
    }
}

#Preview("All Formats") {
    List {
        PaymentDestinationRow(
            ranked: PaymentDestinationSelector.RankedDestination(
                destination: PaymentDestination(format: .ark, network: .signet, address: "tark1qxyzexample1234567890"),
                balanceSource: .ark,
                availableBalance: 1_000_000,
                estimatedFee: 0,
                viable: true,
                reason: "Sufficient balance",
                priority: 0
            ),
            isRecommended: true
        )
        
        PaymentDestinationRow(
            ranked: PaymentDestinationSelector.RankedDestination(
                destination: PaymentDestination(format: .lightningInvoice, network: .testnet, address: "lntb100n1exampleinvoice"),
                balanceSource: .arkViaServer,
                availableBalance: 1_000_000,
                estimatedFee: 100,
                viable: true,
                reason: "Sufficient balance",
                priority: 1
            ),
            isRecommended: false
        )
        
        PaymentDestinationRow(
            ranked: PaymentDestinationSelector.RankedDestination(
                destination: PaymentDestination(format: .bitcoin, network: .signet, address: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"),
                balanceSource: .bitcoin,
                availableBalance: 1_000_000,
                estimatedFee: 500,
                viable: true,
                reason: "Sufficient balance",
                priority: 2
            ),
            isRecommended: false
        )
        
        PaymentDestinationRow(
            ranked: PaymentDestinationSelector.RankedDestination(
                destination: PaymentDestination(format: .silentPayments, network: .mainnet, address: "sp1qqgste7k9hx0qftg6qmwlkqtwuy6cycyavzmzj85c6qdfhjdpdjtdgqjuexzk6murw56suy3e0rd2cgqvycxttddwsvgxe2usfpxumr70xc9pkqwv"),
                balanceSource: .bitcoin,
                availableBalance: 1_000_000,
                estimatedFee: 300,
                viable: false,
                reason: "Insufficient balance",
                priority: 3
            ),
            isRecommended: false
        )
        .disabled(true)
        .opacity(0.6)
        
        PaymentDestinationRow(
            ranked: PaymentDestinationSelector.RankedDestination(
                destination: PaymentDestination(format: .bip353, network: .mainnet, address: "user@example.com"),
                balanceSource: .bitcoin,
                availableBalance: 1_000_000,
                estimatedFee: 250,
                viable: true,
                reason: "Sufficient balance",
                priority: 4
            ),
            isRecommended: false
        )
    }
}
