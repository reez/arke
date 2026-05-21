//
//  TransactionClaimExitBanner.swift
//  Arké
//
//  Created by Assistant on 2/6/26.
//

import SwiftUI
import ArkeUI
import Bark

/// Banner displayed when a unilateral exit transaction is in progress.
/// Shows automatic exit progression through steps, matching the live activity design.
struct TransactionClaimExitBanner: View {
    let exitVtxos: [ExitVtxo]
    let currentBlockHeight: UInt32?
    
    @State private var showClaimConfirmation = false
    
    var body: some View {
        if !exitVtxos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon and "Moving to Savings"
                HStack(spacing: 8) {
                    /*
                    Image(systemName: currentStepIcon)
                        .font(.title3)
                        .foregroundColor(.white)
                    */
                    
                    Text("Step \(currentStep) of \(totalSteps)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                // Segmented progress bar
                HStack(spacing: 5) {
                    ForEach(1...totalSteps, id: \.self) { step in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(step <= currentStep ? progressTint : Color.clear)
                            .frame(height: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(progressTint)
                            )
                    }
                }
                /*
                // Status row - step count and detailed status
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Step \(currentStep) of \(totalSteps)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                        
                        if let statusText = detailedStatusText {
                            Text(statusText)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                }
                */
            }
            //.padding(16)
            //.background(backgroundColor)
            //.cornerRadius(16)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Determine the current step based on exit states
    private var currentStep: Int {
        // Check if all exits are claimed (complete)
        if exitVtxos.allSatisfy({ $0.isClaimed }) {
            return 6 // Completed
        }
        
        // Check if any exit is in claim progress
        if exitVtxos.contains(where: { $0.isClaimInProgress }) {
            return 5 // Claiming
        }
        
        // Check if any exit is claimable
        if exitVtxos.contains(where: { $0.isClaimable }) {
            return 4 // AwaitingDelta (claiming happens automatically, so claimable means waiting for auto-claim)
        }
        
        // Check if exits are confirming (waiting for blocks)
        // If we have exits that are not yet claimable, they're in earlier stages
        let caseName = extractStateCaseName(exitVtxos.first?.state)
        switch caseName.lowercased() {
        case "start":
            return 1 // Start
        case "processing":
            return 2 // Broadcasting
        case "awaitingdelta":
            return 3 // Confirming
        default:
            return 3 // Default to confirming
        }
    }
    
    private var totalSteps: Int {
        return 6
    }
    
    private var currentStepIcon: String {
        if exitVtxos.allSatisfy({ $0.isClaimed }) {
            return "checkmark.circle.fill"
        }
        return "arrow.down.circle"
    }
    
    private var detailedStatusText: String? {
        // Show blocks remaining if we have that info and exits are waiting
        if currentBlockHeight != nil,
           let firstExit = exitVtxos.first,
           !firstExit.isClaimable && !firstExit.isClaimed {
            
            // Try to calculate blocks remaining (this would require claimableHeight from the exit)
            // For now, show generic status based on state
            let caseName = extractStateCaseName(firstExit.state)
            switch caseName.lowercased() {
            case "start":
                return "Initiating exit"
            case "processing":
                return "Broadcasting transaction"
            case "awaitingdelta":
                return "Waiting for confirmation"
            default:
                return "Processing"
            }
        }
        
        // Check if claim is in progress
        if exitVtxos.contains(where: { $0.isClaimInProgress }) {
            return "Finalizing withdrawal"
        }
        
        // Check if claimable (auto-claiming)
        if exitVtxos.contains(where: { $0.isClaimable }) {
            return "Auto-claiming soon"
        }
        
        // Check if complete
        if exitVtxos.allSatisfy({ $0.isClaimed }) {
            return "Withdrawal complete"
        }
        
        return "Processing exit"
    }
    
    private var progressTint: Color {
        if exitVtxos.allSatisfy({ $0.isClaimed }) {
            return .Arke.green
        } else if currentStep >= 4 {
            return .Arke.orange
        } else {
            return .Arke.purple
        }
    }
    
    private var backgroundColor: Color {
        if exitVtxos.allSatisfy({ $0.isClaimed }) {
            return .Arke.green
        } else if currentStep >= 4 {
            return .Arke.orange
        } else {
            return .Arke.blue
        }
    }
}

// MARK: - Helper Functions

/// Extract the enum case name from a state description
private func extractStateCaseName<T>(_ state: T?) -> String {
    guard let state = state else { return "unknown" }
    let stateString = String(describing: state)
    
    // Extract the enum case name (before any parentheses)
    if let parenIndex = stateString.firstIndex(of: "(") {
        return String(stateString[..<parenIndex])
    } else {
        return stateString
    }
}

// MARK: - Preview

// Note: Previews require mock ExitVtxo objects which would need to be constructed with Bark SDK types
// Commented out for now since we can't easily create mock Bark types in previews

/*
#Preview("Processing") {
    VStack(spacing: 20) {
        TransactionClaimExitBanner(
            exitVtxos: [], // Would need mock ExitVtxo objects
            currentBlockHeight: 800000
        )
        
        Text("Processing state")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}

#Preview("Claimable") {
    VStack(spacing: 20) {
        TransactionClaimExitBanner(
            exitVtxos: [], // Would need mock ExitVtxo objects
            currentBlockHeight: 800010
        )
        
        Text("Claimable state")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}

#Preview("Complete") {
    VStack(spacing: 20) {
        TransactionClaimExitBanner(
            exitVtxos: [], // Would need mock ExitVtxo objects
            currentBlockHeight: 800020
        )
        
        Text("Complete state")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
*/

