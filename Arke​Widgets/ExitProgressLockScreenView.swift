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

/// Lock screen view for exit progression Live Activity
struct ExitProgressLockScreenView: View {
    let context: ActivityViewContext<ExitProgressActivityAttributes>
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with icon and description
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.title3)
                
                Text(context.state.stepDescription)
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
            
            // Progress bar
            ProgressView(value: Double(context.state.currentStep.rawValue), 
                        total: Double(context.state.totalSteps))
                .tint(progressTint)
            
            // Status row
            HStack {
                Text("Step \(context.state.currentStep.rawValue) of \(context.state.totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if context.state.needsCheckIn {
                    Text("⚠️ Check-in needed")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                } else if context.state.totalTransactions > 0 {
                    Text("\(context.state.transactionsConfirmed)/\(context.state.totalTransactions) confirmed")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
    
    private var iconName: String {
        if context.state.needsCheckIn {
            return "exclamationmark.circle.fill"
        } else if context.state.hasError {
            return "xmark.circle.fill"
        } else {
            return context.state.currentStep.iconName
        }
    }
    
    private var iconColor: Color {
        if context.state.needsCheckIn {
            return .orange
        } else if context.state.hasError {
            return .red
        } else {
            return colorForStep(context.state.currentStep)
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
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        default: return .blue
        }
    }
}
