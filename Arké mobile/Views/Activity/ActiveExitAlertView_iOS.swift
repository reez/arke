//
//  ActiveExitAlertView_iOS.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//

import SwiftUI
import Bark

struct ActiveExitAlertView_iOS: View {
    let exit: OngoingUnilateralExit
    let currentBlockHeight: Int
    let onTap: () -> Void
    
    private var statusColor: Color {
        switch exit.status {
        case .claimable:
            return .green
        case .failed:
            return .red
        default:
            return .orange
        }
    }
    
    private var statusIcon: String {
        switch exit.status {
        case .claimable:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .matured:
            return "hourglass.bottomhalf.filled"
        default:
            return "clock.arrow.circlepath"
        }
    }
    
    private var statusMessage: String {
        switch exit.status {
        case .broadcasted:
            return "Exit transaction broadcasting..."
        case .inChallengePeriod:
            let blocksRemaining = max(0, exit.challengePeriodEndHeight - currentBlockHeight)
            return "\(blocksRemaining) blocks remaining"
        case .matured:
            return "Challenge period complete"
        case .claimable:
            return "Ready to claim"
        case .claimed:
            return "Funds claimed"
        case .failed:
            return "Exit failed"
        }
    }
    
    private var shouldPulse: Bool {
        exit.status == .claimable
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status icon
                Image(systemName: statusIcon)
                    .font(.system(size: 24))
                    .foregroundStyle(statusColor)
                    .symbolEffect(.pulse, options: .repeating, isActive: shouldPulse)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Exit in Progress")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        // Status badge
                        Text(exit.status.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 8) {
                        Text(exit.formattedAmount)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .foregroundStyle(.tertiary)
                        
                        Text(statusMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("In Challenge Period") {
    VStack(spacing: 20) {
        ActiveExitAlertView_iOS(
            exit: OngoingUnilateralExit(
                exitTxid: "abc123def456",
                status: .inChallengePeriod,
                challengePeriodEndHeight: 850000,
                vtxoOutpoints: [],
                totalAmountSat: 100000
            ),
            currentBlockHeight: 849900,
            onTap: { print("Tapped") }
        )
        .padding(.horizontal, 20)
        
        Spacer()
    }
}

#Preview("Claimable") {
    VStack(spacing: 20) {
        ActiveExitAlertView_iOS(
            exit: OngoingUnilateralExit(
                exitTxid: "abc123def456",
                status: .claimable,
                challengePeriodEndHeight: 850000,
                vtxoOutpoints: [],
                totalAmountSat: 250000
            ),
            currentBlockHeight: 850010,
            onTap: { print("Tapped") }
        )
        .padding(.horizontal, 20)
        
        Spacer()
    }
}

#Preview("Failed") {
    VStack(spacing: 20) {
        ActiveExitAlertView_iOS(
            exit: OngoingUnilateralExit(
                exitTxid: "abc123def456",
                status: .failed,
                challengePeriodEndHeight: 850000,
                vtxoOutpoints: [],
                totalAmountSat: 50000
            ),
            currentBlockHeight: 849900,
            onTap: { print("Tapped") }
        )
        .padding(.horizontal, 20)
        
        Spacer()
    }
}
