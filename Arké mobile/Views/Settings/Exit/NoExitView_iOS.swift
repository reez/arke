//
//  NoExitView.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//

import SwiftUI
import ArkeUI

struct NoExitView_iOS: View {
    let spendableBalance: Int
    let isProcessing: Bool
    let onStartExit: () -> Void
    let exitCostEstimate: ExitCostEstimate?
    let onchainBalance: UInt64
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image("exit")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(25)
                .clipped()
            
            // Icon and title
            VStack(alignment: .leading, spacing: 10) {
                Text("action_start_forced_move")
                    .font(.system(.title, design: .serif))
                
                Text(String(localized: "balance_emergency_move_help"))
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("symbol_bullet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("message_takes_24_hours")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("symbol_bullet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("message_cannot_cancel")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("symbol_bullet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("balance_final_step_fee")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .lineSpacing(6)
            }
            
            if spendableBalance > 0 {
                // Amount card
                /*
                VStack(spacing: 6) {
                    Text("balance_amount_to_recover")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(BitcoinFormatter.shared.formatAmount(spendableBalance))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                */
                
                // Exit cost estimate card (if available)
                if let estimate = exitCostEstimate {
                    ExitCostEstimateCard_iOS(
                        spendableBalance: spendableBalance,
                        estimate: estimate,
                        onchainBalance: onchainBalance
                    )
                }
                
                // Start button
                Button {
                    onStartExit()
                } label: {
                    if let estimate = exitCostEstimate, !estimate.canAfford {
                        Label("Insufficient Balance", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 21, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                    } else {
                        Text("button_start")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Color.Arke.gold3)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(exitCostEstimate?.canAfford == false ? .red : Color.Arke.gold)
                .disabled(spendableBalance == 0 || isProcessing || (exitCostEstimate?.canAfford == false))
            }
            
            if spendableBalance == 0 {
                Text(String(localized: "balance_no_bitcoin_payments"))
                    .font(.title3)
                    .foregroundColor(.primary)
                    .padding(.top, 10)
            }
            
            Spacer()
        }
    }
}

struct ExitCostRow_iOS: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(color)
        }
    }
}

// MARK: - Supporting Types

struct ExitCostEstimate {
    let totalCost: UInt64
    let feeRate: UInt64
    let canAfford: Bool
    let onchainBalance: UInt64
    
    var shortfall: UInt64 {
        canAfford ? 0 : totalCost - onchainBalance
    }
}

// MARK: - Previews

#Preview("Can Afford") {
    NoExitView_iOS(
        spendableBalance: 100000,
        isProcessing: false,
        onStartExit: {},
        exitCostEstimate: ExitCostEstimate(
            totalCost: 15000,
            feeRate: 8,
            canAfford: true,
            onchainBalance: 50000
        ),
        onchainBalance: 50000
    )
    .padding()
}
#Preview("Cannot Afford") {
    NoExitView_iOS(
        spendableBalance: 100000,
        isProcessing: false,
        onStartExit: {},
        exitCostEstimate: ExitCostEstimate(
            totalCost: 15000,
            feeRate: 8,
            canAfford: false,
            onchainBalance: 10000
        ),
        onchainBalance: 10000
    )
    .padding()
}

#Preview("No Estimate") {
    NoExitView_iOS(
        spendableBalance: 100000,
        isProcessing: false,
        onStartExit: {},
        exitCostEstimate: nil,
        onchainBalance: 10000
    )
    .padding()
}

