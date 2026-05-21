//
//  ExitProgressLockScreenView.swift
//  Arké
//
//  Lock screen UI for exit progression Live Activity
//  Created by Claude on 5/12/26.
//

import ActivityKit
import WidgetKit
import SwiftUI
import ArkeUI

/// Lock screen view for exit progression Live Activity
struct ExitProgressLockScreenView: View {
    let context: ActivityViewContext<ExitProgressActivityAttributes>
    
    var body: some View {
        VStack(spacing: 10) {
            // Header with app icon and "Moving to Savings"
            HStack {
                Image("arke-icon")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .cornerRadius(4)
                
                Text("Moving to Savings")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // Show warning if check-in needed
                if context.state.needsCheckIn {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.body)
                }
            }
            
            // Segmented progress bar
            HStack(spacing: 3) {
                ForEach(1...context.state.totalSteps, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step <= context.state.currentStep.rawValue ? progressTint : Color.gray.opacity(0.3))
                        .frame(height: 6)
                }
            }
            
            // Status row - step count on left, detailed status on right
            HStack {
                Text("Step \(context.state.currentStep.rawValue) of \(context.state.totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let statusText = detailedStatusText {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(context.state.needsCheckIn ? .orange : .secondary)
                        .fontWeight(context.state.needsCheckIn ? .medium : .regular)
                }
            }
            
            // Time since last update
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Updated \(context.state.lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if context.state.needsCheckIn {
                    Text("Tap notification to update")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .activityBackgroundTint(Color(white: 0.1))
    }
    
    // MARK: - Helper Properties
    
    private var detailedStatusText: String? {
        // Priority: check-in warning > block waiting > transaction confirmations > step description
        if context.state.needsCheckIn {
            return "⚠️ Check-in needed"
        } else if context.state.isWaitingForBlocks, let remaining = context.state.blocksRemaining {
            return "Waiting for \(remaining) block\(remaining == 1 ? "" : "s")"
        } else if context.state.totalTransactions > 0 {
            return "\(context.state.transactionsConfirmed)/\(context.state.totalTransactions) confirmed"
        } else {
            return context.state.stepDescription
        }
    }
    
    private var progressTint: Color {
        if context.state.needsCheckIn {
            return .orange
        } else if context.state.hasError {
            return .red
        } else {
            return colorForStep(context.state.currentStep)
        }
    }
    
    private func colorForStep(_ step: ExitStep) -> Color {
        switch step.color {
        case "blue": return .Arke.blue
        case "orange": return .Arke.orange
        case "green": return .Arke.green
        case "red": return .Arke.red
        default: return .Arke.blue
        }
    }
}
