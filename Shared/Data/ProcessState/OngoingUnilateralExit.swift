//
//  OngoingUnilateralExit.swift
//  Ark wallet prototype
//
//  Created by Christoph on 1/6/26.
//

import Foundation
import SwiftData

/// Represents the current status of a unilateral exit process
enum UnilateralExitStatus: String, Codable, CaseIterable, Sendable {
    case broadcasted = "broadcasted"
    case inChallengePeriod = "in_challenge_period"
    case matured = "matured"
    case claimable = "claimable"
    case claimed = "claimed"
    case failed = "failed"
}

extension UnilateralExitStatus {
    var displayName: String {
        switch self {
        case .broadcasted:
            return "Broadcasted"
        case .inChallengePeriod:
            return "In Challenge Period"
        case .matured:
            return "Matured"
        case .claimable:
            return "Claimable"
        case .claimed:
            return "Claimed"
        case .failed:
            return "Failed"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .broadcasted, .inChallengePeriod, .matured, .claimable:
            return true
        case .claimed, .failed:
            return false
        }
    }
    
    var requiresUserAction: Bool {
        switch self {
        case .claimable:
            return true
        default:
            return false
        }
    }
}

/// Persistent model for tracking ongoing unilateral exit processes
@Model
final class OngoingUnilateralExit {
    /// Unique identifier for this exit process
    /// Note: Removed @Attribute(.unique) for CloudKit compatibility
    var id: UUID = UUID()
    
    /// The transaction ID of the exit transaction
    var exitTxid: String = ""
    
    /// When the exit was initiated
    var initiatedDate: Date = Date()
    
    /// Current status of the exit (stored as raw String value for SwiftData compatibility)
    private var statusRawValue: String = UnilateralExitStatus.broadcasted.rawValue
    
    /// Current status of the exit
    var status: UnilateralExitStatus {
        get {
            UnilateralExitStatus(rawValue: statusRawValue) ?? .broadcasted
        }
        set {
            statusRawValue = newValue.rawValue
        }
    }
    
    /// Block height when the challenge period ends (exit matures)
    var challengePeriodEndHeight: Int = 0
    
    /// VTXOs being exited (stored as outpoint strings)
    var vtxoOutpoints: [String] = []
    
    /// Total amount being exited (in satoshis)
    var totalAmountSat: Int = 0
    
    /// Optional error message if failed
    var errorMessage: String?
    
    /// Last updated timestamp
    var lastUpdated: Date = Date()
    
    /// Optional notes for this exit
    var notes: String?
    
    init(
        id: UUID = UUID(),
        exitTxid: String,
        initiatedDate: Date = Date(),
        status: UnilateralExitStatus = .broadcasted,
        challengePeriodEndHeight: Int,
        vtxoOutpoints: [String],
        totalAmountSat: Int,
        errorMessage: String? = nil,
        lastUpdated: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.exitTxid = exitTxid
        self.initiatedDate = initiatedDate
        self.status = status
        self.challengePeriodEndHeight = challengePeriodEndHeight
        self.vtxoOutpoints = vtxoOutpoints
        self.totalAmountSat = totalAmountSat
        self.errorMessage = errorMessage
        self.lastUpdated = lastUpdated
        self.notes = notes
    }
    
    // MARK: - Computed Properties
    
    /// Formatted amount for display
    var formattedAmount: String {
        BitcoinFormatter.shared.formatAmount(totalAmountSat)
    }
    
    /// Short transaction ID for display
    var shortTxid: String {
        if exitTxid.count > 12 {
            return String(exitTxid.prefix(8)) + "..." + String(exitTxid.suffix(4))
        }
        return exitTxid
    }
    
    /// Check if this exit is still active (not completed or failed)
    var isActive: Bool {
        status.isActive
    }
    
    /// Check if user action is required
    var requiresUserAction: Bool {
        status.requiresUserAction
    }
    
    // MARK: - Block Height Calculations
    
    /// Calculate blocks remaining until maturity
    func blocksRemaining(currentHeight: Int) -> Int {
        let remaining = challengePeriodEndHeight - currentHeight
        return max(0, remaining)
    }
    
    /// Check if the exit has matured based on current block height
    func hasMatured(currentHeight: Int) -> Bool {
        return currentHeight >= challengePeriodEndHeight
    }
    
    /// Estimated time remaining (assumes ~10 min per block)
    func estimatedTimeRemaining(currentHeight: Int) -> TimeInterval {
        let blocks = blocksRemaining(currentHeight: currentHeight)
        return TimeInterval(blocks * 10 * 60) // blocks * 10 minutes * 60 seconds
    }
    
    /// Formatted time remaining string
    func formattedTimeRemaining(currentHeight: Int) -> String {
        let timeInterval = estimatedTimeRemaining(currentHeight: currentHeight)
        
        if timeInterval <= 0 {
            return "Matured"
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        
        if hours > 24 {
            let days = hours / 24
            return "~\(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "~\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "~\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
    
    // MARK: - Status Update Methods
    
    /// Update the status of this exit
    func updateStatus(_ newStatus: UnilateralExitStatus, errorMessage: String? = nil) {
        self.status = newStatus
        self.errorMessage = errorMessage
        self.lastUpdated = Date()
    }
    
    /// Mark as claimed
    func markClaimed() {
        updateStatus(.claimed)
    }
    
    /// Mark as failed with error message
    func markFailed(error: String) {
        updateStatus(.failed, errorMessage: error)
    }
    
    /// Check and update status based on current block height
    func updateStatusForBlockHeight(_ currentHeight: Int) {
        guard isActive else { return }
        
        switch status {
        case .broadcasted, .inChallengePeriod:
            if hasMatured(currentHeight: currentHeight) {
                updateStatus(.claimable)
            } else {
                updateStatus(.inChallengePeriod)
            }
        case .matured:
            // Transition from matured to claimable
            updateStatus(.claimable)
        case .claimable, .claimed, .failed:
            // No automatic status change needed
            break
        }
    }
}

// MARK: - Query Extensions

extension OngoingUnilateralExit {
    /// Predicate for active exits
    static var activeExitsPredicate: Predicate<OngoingUnilateralExit> {
        let activeStatuses = [
            UnilateralExitStatus.broadcasted.rawValue,
            UnilateralExitStatus.inChallengePeriod.rawValue,
            UnilateralExitStatus.matured.rawValue,
            UnilateralExitStatus.claimable.rawValue
        ]
        return #Predicate<OngoingUnilateralExit> { exit in
            activeStatuses.contains(exit.statusRawValue)
        }
    }
    
    /// Predicate for exits requiring user action
    static var requiresActionPredicate: Predicate<OngoingUnilateralExit> {
        let claimableStatus = UnilateralExitStatus.claimable.rawValue
        return #Predicate<OngoingUnilateralExit> { exit in
            exit.statusRawValue == claimableStatus
        }
    }
    
    /// Predicate for completed exits (claimed or failed)
    static var completedExitsPredicate: Predicate<OngoingUnilateralExit> {
        let completedStatuses = [
            UnilateralExitStatus.claimed.rawValue,
            UnilateralExitStatus.failed.rawValue
        ]
        return #Predicate<OngoingUnilateralExit> { exit in
            completedStatuses.contains(exit.statusRawValue)
        }
    }
}
// MARK: - Uniqueness Helper

extension OngoingUnilateralExit {
    /// Find an existing exit by ID
    /// - Parameters:
    ///   - id: The UUID to search for
    ///   - context: The ModelContext to use
    /// - Returns: The OngoingUnilateralExit if found, nil otherwise
    static func findByID(_ id: UUID, context: ModelContext) throws -> OngoingUnilateralExit? {
        let descriptor = FetchDescriptor<OngoingUnilateralExit>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    /// Find an existing exit by transaction ID
    /// - Parameters:
    ///   - txid: The transaction ID to search for
    ///   - context: The ModelContext to use
    /// - Returns: The OngoingUnilateralExit if found, nil otherwise
    static func findByTxid(_ txid: String, context: ModelContext) throws -> OngoingUnilateralExit? {
        let descriptor = FetchDescriptor<OngoingUnilateralExit>(
            predicate: #Predicate { $0.exitTxid == txid }
        )
        return try context.fetch(descriptor).first
    }
    
    /// Get or create an exit by ID
    /// - Parameters:
    ///   - id: The UUID to search for or use for creation
    ///   - context: The ModelContext to use
    ///   - createIfNeeded: Closure to create a new instance if not found
    /// - Returns: Existing or newly created OngoingUnilateralExit
    static func getOrCreate(
        id: UUID,
        context: ModelContext,
        createIfNeeded: () -> OngoingUnilateralExit
    ) throws -> OngoingUnilateralExit {
        if let existing = try findByID(id, context: context) {
            return existing
        } else {
            let newExit = createIfNeeded()
            context.insert(newExit)
            return newExit
        }
    }
    
    /// Check if an exit with this transaction ID already exists
    /// - Parameters:
    ///   - txid: The transaction ID to check
    ///   - context: The ModelContext to use
    /// - Returns: True if an exit with this txid exists
    static func exists(txid: String, context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<OngoingUnilateralExit>(
            predicate: #Predicate { $0.exitTxid == txid }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }
}

