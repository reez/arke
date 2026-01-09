//
//  ActiveExitView.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//

import SwiftUI
import Bark

struct ActiveExitView_iOS: View {
    let exit: ExitVtxo
    let currentBlockHeight: Int
    let claimableHeight: Int
    
    var body: some View {
        VStack(spacing: 24) {
            
            Text("Exit In Progress")
                .font(.system(.title, design: .serif))
            
            // Status badge
            HStack {
                Image(systemName: exit.stateIcon)
                    .foregroundColor(Color(exit.stateColor))
                Text(exit.stateDisplayName)
                    .font(.headline)
                    .foregroundColor(Color(exit.stateColor))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(exit.stateColor).opacity(0.15))
            .cornerRadius(20)
            .padding(.top, 20)
            
            // Amount
            VStack(spacing: 8) {
                Text("Amount being exited")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(exit.formattedAmount)
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            // Progress section
            if !exit.isClaimable && claimableHeight > 0 {
                VStack(spacing: 16) {
                    // Progress bar
                    ExitProgressBar_iOS(
                        currentBlockHeight: currentBlockHeight,
                        claimableHeight: claimableHeight
                    )
                    
                    // Countdown
                    ExitCountdownView_iOS(
                        blocksRemaining: exit.blocksRemaining(
                            currentHeight: currentBlockHeight,
                            claimableHeight: claimableHeight
                        )
                    )
                    
                    // Info
                    Text("Your funds are locked during the challenge period. Once the period ends, you'll be able to claim them.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // VTXO ID
            VStack(alignment: .leading, spacing: 8) {
                Text("VTXO ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(exit.shortVtxoId)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Current state
            VStack(alignment: .leading, spacing: 8) {
                Text("Current State")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(exit.state)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Spacer()
        }
    }
}

// MARK: - Supporting Views

struct ExitProgressBar_iOS: View {
    let currentBlockHeight: Int
    let claimableHeight: Int
    
    private var progress: Double {
        let totalBlocks = 144 // Approximate challenge period
        let blocksElapsed = max(0, totalBlocks - (claimableHeight - currentBlockHeight))
        return min(1.0, max(0, Double(blocksElapsed) / Double(totalBlocks)))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Challenge Period")
                .font(.subheadline)
                .fontWeight(.medium)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct ExitCountdownView_iOS: View {
    let blocksRemaining: Int
    
    private var hoursRemaining: Int {
        (blocksRemaining * 10) / 60 // 10 minutes per block
    }
    
    var body: some View {
        VStack(spacing: 4) {
            if hoursRemaining > 0 {
                Text("≈ \(hoursRemaining) hour\(hoursRemaining == 1 ? "" : "s")")
                    .font(.title3)
                    .fontWeight(.semibold)
            } else {
                Text("< 1 hour")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            Text("\(blocksRemaining) blocks remaining")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview("In Progress") {
    ActiveExitView_iOS(
        exit: ExitVtxo(
            vtxoId: "abc123def456789xyz0123456789",
            amountSats: 100000,
            state: "Processing",
            isClaimable: false
        ),
        currentBlockHeight: 849900,
        claimableHeight: 850000
    )
    .padding()
}

#Preview("Near Completion") {
    ActiveExitView_iOS(
        exit: ExitVtxo(
            vtxoId: "abc123def456789xyz0123456789",
            amountSats: 250000,
            state: "AwaitingDelta",
            isClaimable: false
        ),
        currentBlockHeight: 849990,
        claimableHeight: 850000
    )
    .padding()
}
