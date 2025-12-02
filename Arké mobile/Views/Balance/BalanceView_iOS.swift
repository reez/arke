//
//  BalanceView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct BalanceView_iOS: View {
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ARK Balance")
                            .font(.headline)
                        if let arkBalance = manager.arkBalance {
                            Text("\(arkBalance.spendableSat) sats")
                                .font(.title2)
                                .foregroundStyle(.primary)
                            Text("\(arkBalance.spendableBTC, format: .number.precision(.fractionLength(8))) BTC")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not available")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Onchain Balance")
                            .font(.headline)
                        if let onchainBalance = manager.onchainBalance {
                            Text("\(onchainBalance.trustedSpendableSat) sats")
                                .font(.title2)
                                .foregroundStyle(.primary)
                            Text("\(onchainBalance.trustedSpendableBTC, format: .number.precision(.fractionLength(8))) BTC")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not available")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .task {
            do {
                try await manager.sync()
                _ = try await manager.getArkBalance()
            } catch {
                print("Failed to sync or get balance: \(error)")
            }
        }
    }
}
