//
//  Arke_WidgetsLiveActivity.swift
//  Arke​Widgets
//
//  Exit progression Live Activity
//  Created by Christoph on 5/12/26.
//

import ActivityKit
import WidgetKit
import SwiftUI
import ArkeUI

struct ExitProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExitProgressActivityAttributes.self) { context in
            // Lock screen / banner UI
            ExitProgressLockScreenView(context: context)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region - when user long-presses the island
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.needsCheckIn ? 
                        "exclamationmark.circle.fill" : context.state.currentStep.iconName)
                        .foregroundColor(context.state.needsCheckIn ? .orange : stepColor(context.state.currentStep))
                        .font(.title2)
                        .symbolEffect(.bounce, value: context.state.needsCheckIn)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.stepDescription)
                            .font(.headline)
                            .lineLimit(1)
                        
                        if context.state.needsCheckIn {
                            Text("Check app to continue")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else if context.state.isWaitingForBlocks, let remaining = context.state.blocksRemaining {
                            Text("\(remaining) blocks remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.totalTransactions > 0 {
                            Text("\(context.state.transactionsConfirmed)/\(context.state.totalTransactions)")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("confirmed")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(context.state.currentStep.rawValue)/\(context.state.totalSteps)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        ProgressView(value: Double(context.state.currentStep.rawValue), 
                                    total: Double(context.state.totalSteps))
                            .tint(context.state.needsCheckIn ? .orange : stepColor(context.state.currentStep))
                        
                        Text("\(context.state.currentStep.rawValue)/\(context.state.totalSteps)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.top, 4)
                }
                
            } compactLeading: {
                // Compact state - when island is small
                Image(systemName: context.state.needsCheckIn ? 
                    "exclamationmark.triangle.fill" : context.state.currentStep.iconName)
                    .foregroundColor(context.state.needsCheckIn ? .orange : stepColor(context.state.currentStep))
                
            } compactTrailing: {
                Text("\(context.state.currentStep.rawValue)/\(context.state.totalSteps)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .monospacedDigit()
                
            } minimal: {
                // Minimal state - when island is smallest (multiple activities)
                Image(systemName: context.state.needsCheckIn ? 
                    "exclamationmark.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(context.state.needsCheckIn ? .orange : stepColor(context.state.currentStep))
            }
            .keylineTint(stepColor(context.state.currentStep))
        }
    }
    
    // MARK: - Helper Functions
    
    private func stepColor(_ step: ExitStep) -> Color {
        switch step.color {
        case "blue": return .Arke.blue
        case "orange": return .Arke.orange
        case "green": return .Arke.green
        case "red": return .Arke.red
        default: return .Arke.blue
        }
    }
}

// MARK: - Preview Support

extension ExitProgressActivityAttributes {
    fileprivate static var preview: ExitProgressActivityAttributes {
        ExitProgressActivityAttributes(
            exitId: "preview-exit-id",
            exitCount: 1,
            startTime: Date()
        )
    }
}

extension ExitProgressActivityAttributes.ContentState {
    fileprivate static var starting: ExitProgressActivityAttributes.ContentState {
        ExitProgressActivityAttributes.ContentState(
            currentStep: .start,
            totalSteps: 6,
            stepDescription: "Starting move to savings",
            transactionsConfirmed: 0,
            totalTransactions: 5,
            lastUpdated: Date(),
            needsCheckIn: false,
            isWaitingForBlocks: false,
            isClaimable: false,
            hasError: false
        )
    }
    
    fileprivate static var confirming: ExitProgressActivityAttributes.ContentState {
        ExitProgressActivityAttributes.ContentState(
            currentStep: .confirming,
            totalSteps: 6,
            stepDescription: "Confirming transactions",
            transactionsConfirmed: 2,
            totalTransactions: 5,
            lastUpdated: Date().addingTimeInterval(-300), // 5 min ago
            needsCheckIn: false,
            isWaitingForBlocks: false,
            isClaimable: false,
            hasError: false
        )
    }
    
    fileprivate static var needsCheckIn: ExitProgressActivityAttributes.ContentState {
        ExitProgressActivityAttributes.ContentState(
            currentStep: .awaitingDelta,
            totalSteps: 6,
            stepDescription: "Waiting for blocks",
            transactionsConfirmed: 4,
            totalTransactions: 5,
            lastUpdated: Date().addingTimeInterval(-5400), // 90 min ago
            needsCheckIn: true,
            currentBlockHeight: 850000,
            targetBlockHeight: 850012,
            blocksRemaining: 12,
            isWaitingForBlocks: true,
            isClaimable: false,
            hasError: false
        )
    }
    
    fileprivate static var complete: ExitProgressActivityAttributes.ContentState {
        ExitProgressActivityAttributes.ContentState(
            currentStep: .completed,
            totalSteps: 6,
            stepDescription: "Move complete!",
            transactionsConfirmed: 5,
            totalTransactions: 5,
            lastUpdated: Date(),
            needsCheckIn: false,
            isWaitingForBlocks: false,
            isClaimable: false,
            hasError: false
        )
    }
}

#Preview("Notification", as: .content, using: ExitProgressActivityAttributes.preview) {
    ExitProgressLiveActivity()
} contentStates: {
    ExitProgressActivityAttributes.ContentState.starting
    ExitProgressActivityAttributes.ContentState.confirming
    ExitProgressActivityAttributes.ContentState.needsCheckIn
    ExitProgressActivityAttributes.ContentState.complete
}
