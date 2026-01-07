//
//  ActiveExitView.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//

import SwiftUI
import Bark

struct ActiveExitView_iOS: View {
    let exit: OngoingUnilateralExit
    let currentBlockHeight: Int
    
    var body: some View {
        VStack(spacing: 24) {
            // Status badge
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                Text(exit.status.displayName)
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(20)
            .padding(.top, 20)
            
            // Amount
            VStack(spacing: 8) {
                Text("Exiting")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(exit.formattedAmount)
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            // Progress section
            if exit.status == .inChallengePeriod || exit.status == .broadcasted {
                VStack(spacing: 16) {
                    // Progress bar
                    ExitProgressBar_iOS(exit: exit, currentBlockHeight: currentBlockHeight)
                    
                    // Countdown
                    ExitCountdownView_iOS(exit: exit, currentBlockHeight: currentBlockHeight)
                    
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
            } else if exit.status == .matured {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("Challenge Period Complete")
                        .font(.headline)
                    
                    Text("Processing claim status...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Transaction ID
            VStack(alignment: .leading, spacing: 8) {
                Text("Exit Transaction")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(exit.shortTxid)
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
    let exit: OngoingUnilateralExit
    let currentBlockHeight: Int
    
    private var progress: Double {
        let blocksRemaining = max(0, exit.challengePeriodEndHeight - currentBlockHeight)
        let totalBlocks = 144 // Approximate challenge period (can be refined)
        return blocksRemaining == 0 ? 1.0 : max(0, 1.0 - Double(blocksRemaining) / Double(totalBlocks))
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
    let exit: OngoingUnilateralExit
    let currentBlockHeight: Int
    
    private var blocksRemaining: Int {
        max(0, exit.challengePeriodEndHeight - currentBlockHeight)
    }
    
    private var hoursRemaining: Int {
        (blocksRemaining * 10) / 60 // 10 minutes per block
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(blocksRemaining) blocks remaining")
                .font(.title3)
                .fontWeight(.semibold)
            
            if hoursRemaining > 0 {
                Text("≈ \(hoursRemaining) hour\(hoursRemaining == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("< 1 hour")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview("In Progress") {
    ActiveExitView_iOS(
        exit: OngoingUnilateralExit(
            exitTxid: "abc123def456",
            status: .inChallengePeriod,
            challengePeriodEndHeight: 850000,
            vtxoOutpoints: [],
            totalAmountSat: 100000
        ),
        currentBlockHeight: 849900
    )
    .padding()
}

#Preview("Matured") {
    ActiveExitView_iOS(
        exit: OngoingUnilateralExit(
            exitTxid: "abc123def456",
            status: .matured,
            challengePeriodEndHeight: 850000,
            vtxoOutpoints: [],
            totalAmountSat: 100000
        ),
        currentBlockHeight: 850010
    )
    .padding()
}
