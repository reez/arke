//
//  ExitProgressActivityAttributes.swift
//  Arké
//
//  Live Activity attributes for exit progression
//  Created by Claude on 5/12/26.
//

#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Activity attributes for exit progression Live Activity
struct ExitProgressActivityAttributes: ActivityAttributes {
    
    /// Dynamic state that updates during the exit process
    public struct ContentState: Codable, Hashable {
        // Current exit state
        var currentStep: ExitStep
        var totalSteps: Int
        var stepDescription: String
        
        // Transaction progress
        var transactionsConfirmed: Int
        var totalTransactions: Int
        
        // Timing information
        var lastUpdated: Date
        var needsCheckIn: Bool  // Indicates staleness, user should check in
        
        // Block information (optional, for advanced users)
        var currentBlockHeight: UInt32?
        var targetBlockHeight: UInt32?
        var blocksRemaining: Int?
        
        // Status indicators
        var isWaitingForBlocks: Bool
        var isClaimable: Bool
        var hasError: Bool
        var errorMessage: String?
    }
    
    // Static data (doesn't change during the activity)
    var exitId: String  // Primary VTXO ID or exit batch identifier
    var exitCount: Int  // Number of VTXOs being exited (for multiple exits)
    var startTime: Date
}

/// Steps in the exit process
enum ExitStep: Int, Codable, Hashable {
    case start = 1
    case broadcasting = 2
    case confirming = 3
    case awaitingDelta = 4
    case claiming = 5
    case completed = 6
    
    var displayName: String {
        switch self {
        case .start: return "Starting"
        case .broadcasting: return "Broadcasting"
        case .confirming: return "Confirming"
        case .awaitingDelta: return "Waiting"
        case .claiming: return "Claiming"
        case .completed: return "Complete"
        }
    }
    
    var iconName: String {
        switch self {
        case .start: return "arrow.down.circle"
        case .broadcasting: return "wifi.circle"
        case .confirming: return "checkmark.circle"
        case .awaitingDelta: return "clock.circle"
        case .claiming: return "arrow.down.circle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .start: return "blue"
        case .broadcasting: return "orange"
        case .confirming: return "orange"
        case .awaitingDelta: return "blue"
        case .claiming: return "orange"
        case .completed: return "green"
        }
    }
}

#endif
