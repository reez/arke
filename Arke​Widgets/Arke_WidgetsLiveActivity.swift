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
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 8) {
                        // Logo and title inline, centered
                        HStack(spacing: 8) {
                            if context.state.needsCheckIn {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.title3)
                                    .symbolEffect(.bounce, value: context.state.needsCheckIn)
                            } else {
                                Image("arke-icon")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .cornerRadius(4)
                            }
                            
                            Text("Moving to Savings")
                                .font(.headline)
                                .lineLimit(1)
                        }
                        
                        if context.state.needsCheckIn {
                            Text("Check app to continue")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // Segmented progress bar matching lock screen design
                    HStack(spacing: 4) {
                        ForEach(1...context.state.totalSteps, id: \.self) { step in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(step <= context.state.currentStep.rawValue ? progressTint(context.state) : Color.clear)
                                .frame(height: 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(progressTint(context.state), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                
            } compactLeading: {
                // Compact state - when island is small
                if context.state.needsCheckIn {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                } else {
                    Image("arke-icon")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .cornerRadius(3)
                }
                
            } compactTrailing: {
                Text("\(context.state.currentStep.rawValue)/\(context.state.totalSteps)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .monospacedDigit()
                
            } minimal: {
                // Minimal state - when island is smallest (multiple activities)
                if context.state.needsCheckIn {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                } else {
                    Image("arke-icon")
                        .resizable()
                        .frame(width: 14, height: 14)
                        .cornerRadius(3)
                }
            }
            .keylineTint(stepColor(context.state.currentStep))
        }
    }
    
    // MARK: - Helper Functions
    
    private func stepColor(_ step: ExitStep) -> Color {
        switch step.color {
        case "blue": return .Arke.indigo
        case "orange": return .Arke.orange
        case "green": return .Arke.green
        case "red": return .Arke.red
        default: return .Arke.blue
        }
    }
    
    private func progressTint(_ state: ExitProgressActivityAttributes.ContentState) -> Color {
        if state.needsCheckIn {
            return .orange
        } else {
            return stepColor(state.currentStep)
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
