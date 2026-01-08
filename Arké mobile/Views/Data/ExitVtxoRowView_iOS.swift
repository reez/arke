//
//  ExitVtxoRowView_iOS.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//


/**

A VTXO in the exit process

public struct ExitVtxo: Equatable, Hashable {
    /**
     * VTXO ID
     */
    public var vtxoId: String
    /**
     * Amount in sats
     */
    public var amountSats: UInt64
    /**
     * Current exit state
     */
    public var state: String
    /**
     * Whether this exit is claimable
     */
    public var isClaimable: Bool

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(
        /**
         * VTXO ID
         */vtxoId: String,
        /**
         * Amount in sats
         */amountSats: UInt64,
        /**
         * Current exit state
         */state: String,
        /**
         * Whether this exit is claimable
         */isClaimable: Bool) {
        self.vtxoId = vtxoId
        self.amountSats = amountSats
        self.state = state
        self.isClaimable = isClaimable
    }
}
*/

import SwiftUI
import Bark

struct ExitVtxoRowView_iOS: View {
    let exit: ExitVtxo
    let isSelected: Bool
    let latestBlockHeight: Int?
    let swiftDataMatch: OngoingUnilateralExit?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(shortVtxoId)
                            .font(.system(.body, design: .monospaced))
                        
                        // SwiftData correlation indicator
                        /*
                        if swiftDataMatch != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        */
                    }
                    
                    /*
                    VStack(spacing: 8) {
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let blockHeight = latestBlockHeight {
                            Text("• \(formattedTimeRemaining(currentHeight: blockHeight))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    */
                    
                    // Show SwiftData correlation info
                    if let match = swiftDataMatch {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text("Tracked: \(match.status.displayName)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.green)
                    }
                }
                
                Spacer()
                
                Text(formattedAmount)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var shortVtxoId: String {
        let id = exit.vtxoId
        if id.count > 16 {
            return String(id.prefix(8)) + "..." + String(id.suffix(4))
        }
        return id
    }
    
    private var formattedAmount: String {
        BitcoinFormatter.shared.formatAmount(Int(exit.amountSats))
    }
    
    private var statusText: String {
        // Use the state string from ExitVtxo
        // If claimable, show that prominently
        if exit.isClaimable {
            return "Claimable"
        }
        
        // Otherwise show the state from the Bark wallet
        return exit.state.capitalized
    }
    
    private func formattedTimeRemaining(currentHeight: Int) -> String {
        // Since we don't have expiry height, we can only show generic status
        if exit.isClaimable {
            return "Ready to claim"
        }
        
        // For non-claimable exits, we show the state
        return exit.state
    }
}

#Preview("In Progress") {
    VStack(spacing: 16) {
        ExitVtxoRowView_iOS(
            exit: ExitVtxo(
                vtxoId: "abc123def456789xyz",
                amountSats: 100000,
                state: "pending",
                isClaimable: false
            ),
            isSelected: false,
            latestBlockHeight: 850000,
            swiftDataMatch: nil
        )
        
        ExitVtxoRowView_iOS(
            exit: ExitVtxo(
                vtxoId: "abc123def456789xyz",
                amountSats: 250000,
                state: "broadcasting",
                isClaimable: false
            ),
            isSelected: true,
            latestBlockHeight: 850000,
            swiftDataMatch: OngoingUnilateralExit(
                exitTxid: "test123",
                status: .inChallengePeriod,
                challengePeriodEndHeight: 850100,
                vtxoOutpoints: ["abc123def456789xyz"],
                totalAmountSat: 250000
            )
        )
    }
    .padding()
}

#Preview("Claimable") {
    VStack(spacing: 16) {
        ExitVtxoRowView_iOS(
            exit: ExitVtxo(
                vtxoId: "xyz789def456123abc",
                amountSats: 500000,
                state: "claimable",
                isClaimable: true
            ),
            isSelected: false,
            latestBlockHeight: 850100,
            swiftDataMatch: OngoingUnilateralExit(
                exitTxid: "test456",
                status: .claimable,
                challengePeriodEndHeight: 850000,
                vtxoOutpoints: ["xyz789def456123abc"],
                totalAmountSat: 500000
            )
        )
    }
    .padding()
}

