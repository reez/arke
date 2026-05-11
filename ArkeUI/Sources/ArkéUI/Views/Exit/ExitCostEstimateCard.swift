//
//  ExitCostEstimateCard.swift
//  Arke
//
//  Created by Christoph on 4/8/26.
//

import SwiftUI

public struct ExitCostEstimateCard: View {
    let spendableBalance: UInt64
    let estimate: ExitCostEstimate
    let onchainBalance: UInt64
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            /*
            HStack {
                Image(systemName: estimate.canAfford ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(estimate.canAfford ? .green : .orange)
                Text("Fee Estimate")
                    .font(.headline)
                Spacer()
            }
            */
            
            VStack(spacing: 8) {
                /*
                 ExitCostRow(
                    label: "Network fee rate",
                    value: "\(estimate.feeRate) sat/vB"
                )
                */

                ExitCostRow(
                    label: String(localized: "balance_amount_to_recover"),
                    value: BitcoinFormatter.shared.formatAmount(Int(spendableBalance))
                )

                Divider()

                // Show fee range if available, otherwise single estimate
                ExitCostRow(
                    label: "Estimated fee",
                    value: estimate.isRange
                        ? "\(BitcoinFormatter.shared.formatAmount(Int(estimate.lowCost))) – \(BitcoinFormatter.shared.formatAmount(Int(estimate.highCost)))"
                        : BitcoinFormatter.shared.formatAmount(Int(estimate.totalCost))
                )
                
                Divider()

                // Show transaction count
                ExitCostRow(
                    label: "Transactions",
                    value: "\(estimate.transactionRange)"
                )

                /*
                ExitCostRow(
                    label: "Your savings balance",
                    value: BitcoinFormatter.shared.formatAmount(Int(onchainBalance)),
                    color: estimate.canAfford ? .green : .orange
                )
                */

                /*
                if !estimate.canAfford {
                    ExitCostRow(
                        label: "Missing savings funds",
                        value: BitcoinFormatter.shared.formatAmount(Int(estimate.shortfall)),
                        color: .red
                    )
                }
                */
            }
            
            if !estimate.canAfford {                
                Divider()
                
                Text("Increase your savings balance to cover the fee.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                /*
                Text("✓ You have sufficient savings balance.")
                    .font(.body)
                    .foregroundColor(.green)
                    .padding(.top, 4)
                 */
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        }
    }
}
