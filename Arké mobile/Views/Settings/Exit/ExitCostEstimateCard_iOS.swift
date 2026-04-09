//
//  ExitCostEstimateCard.swift
//  Arke
//
//  Created by Christoph on 4/8/26.
//

import SwiftUI
import ArkeUI

struct ExitCostEstimateCard_iOS: View {
    let spendableBalance: Int
    let estimate: ExitCostEstimate
    let onchainBalance: UInt64
    
    var body: some View {
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
                 ExitCostRow_iOS(
                    label: "Network fee rate",
                    value: "\(estimate.feeRate) sat/vB"
                )
                */
                
                ExitCostRow_iOS(
                    label: String(localized: "balance_amount_to_recover"),
                    value: BitcoinFormatter.shared.formatAmount(spendableBalance)
                )
                
                Divider()
                
                ExitCostRow_iOS(
                    label: "Estimated fee",
                    value: BitcoinFormatter.shared.formatAmount(Int(estimate.totalCost))
                )
                
                /*
                ExitCostRow_iOS(
                    label: "Your savings balance",
                    value: BitcoinFormatter.shared.formatAmount(Int(onchainBalance)),
                    color: estimate.canAfford ? .green : .orange
                )
                */
                
                /*
                if !estimate.canAfford {
                    ExitCostRow_iOS(
                        label: "Missing savings funds",
                        value: BitcoinFormatter.shared.formatAmount(Int(estimate.shortfall)),
                        color: .red
                    )
                }
                */
            }
            
            if !estimate.canAfford {
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
