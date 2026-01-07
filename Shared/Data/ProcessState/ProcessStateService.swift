//
//  ProcessStateService.swift
//  Ark wallet prototype
//
//  Created by Christoph on 1/6/26.
//

import Foundation
import SwiftData

/// Service for tracking ongoing processes and wallet health states
@MainActor
@Observable
final class ProcessStateService {
    
    // MARK: - Dependencies
    private var modelContext: ModelContext?
    
    // MARK: - State Properties
    
    /// Active unilateral exits
    private(set) var activeUnilateralExits: [OngoingUnilateralExit] = []
    
    /// VTXO health status
    private(set) var vtxoHealth: VTXOHealth = VTXOHealth()
    
    /// Connection status
    private(set) var connectionStatus: ConnectionStatus = ConnectionStatus()
    
    /// Backup status (loaded from persistence)
    private(set) var backupStatus: BackupStatus?
    
    /// Current block height (cached from last update)
    private(set) var currentBlockHeight: Int = 0
    
    /// Error state
    private(set) var error: String?
    
    // MARK: - Initialization
    
    init() {
        // Service initializes empty, will be populated via setModelContext and refresh calls
    }
    
    // MARK: - ModelContext Management
    
    /// Set the ModelContext for SwiftData operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadPersistedData()
    }
    
    /// Load persisted data from SwiftData
    private func loadPersistedData() {
        guard let context = modelContext else { return }
        
        // Load active unilateral exits
        do {
            let exitDescriptor = FetchDescriptor<OngoingUnilateralExit>(
                predicate: OngoingUnilateralExit.activeExitsPredicate,
                sortBy: [SortDescriptor(\OngoingUnilateralExit.initiatedDate, order: .reverse)]
            )
            activeUnilateralExits = try context.fetch(exitDescriptor)
        } catch {
            self.error = "Failed to load unilateral exits: \(error.localizedDescription)"
            print("❌ ProcessStateService: Failed to load unilateral exits: \(error)")
        }
        
        // Load or create backup status (singleton)
        do {
            let backupDescriptor = FetchDescriptor<BackupStatus>()
            let backupStatuses = try context.fetch(backupDescriptor)
            
            if let existing = backupStatuses.first {
                self.backupStatus = existing
            } else {
                // Create initial backup status
                let newBackupStatus = BackupStatus()
                context.insert(newBackupStatus)
                self.backupStatus = newBackupStatus
                try context.save()
            }
        } catch {
            self.error = "Failed to load backup status: \(error.localizedDescription)"
            print("❌ ProcessStateService: Failed to load backup status: \(error)")
        }
    }
    
    // MARK: - Refresh Methods
    
    /// Refresh all state (called after wallet refresh)
    func refreshAll(
        vtxos: [VTXOModel],
        blockHeight: Int,
        isConnected: Bool,
        connectionError: String? = nil
    ) {
        self.currentBlockHeight = blockHeight
        
        refreshVTXOHealth(vtxos: vtxos, blockHeight: blockHeight)
        updateConnectionStatus(connected: isConnected, error: connectionError)
        checkUnilateralExitProgress(blockHeight: blockHeight)
    }
    
    /// Refresh VTXO health status
    func refreshVTXOHealth(vtxos: [VTXOModel], blockHeight: Int, thresholdBlocks: Int = 144) {
        self.currentBlockHeight = blockHeight
        self.vtxoHealth = VTXOHealth.calculate(
            from: vtxos,
            currentBlockHeight: blockHeight,
            expiryThresholdBlocks: thresholdBlocks
        )
    }
    
    /// Update connection status
    func updateConnectionStatus(connected: Bool, quality: ConnectionQuality? = nil, error: String? = nil) {
        if connected {
            if let quality = quality {
                connectionStatus.markConnected(quality: quality)
            } else {
                // Determine quality from last sync
                connectionStatus.markConnected(quality: .excellent)
            }
        } else {
            connectionStatus.markDisconnected(error: error)
        }
    }
    
    /// Check progress of all unilateral exits based on current block height
    func checkUnilateralExitProgress(blockHeight: Int) {
        guard let context = modelContext else { return }
        
        self.currentBlockHeight = blockHeight
        
        for exit in activeUnilateralExits {
            exit.updateStatusForBlockHeight(blockHeight)
        }
        
        // Save any status updates
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            self.error = "Failed to update exit progress: \(error.localizedDescription)"
            print("❌ ProcessStateService: Failed to save exit updates: \(error)")
        }
        
        // Reload to ensure we have latest state
        loadPersistedData()
    }
    
    // MARK: - Unilateral Exit Management
    
    /// Start a new unilateral exit process
    func startUnilateralExit(
        exitTxid: String,
        challengePeriodEndHeight: Int,
        vtxoOutpoints: [String],
        totalAmountSat: Int,
        notes: String? = nil
    ) throws {
        guard let context = modelContext else {
            throw ProcessStateError.noModelContext
        }
        
        // Check if exit already exists for this txid
        let existingDescriptor = FetchDescriptor<OngoingUnilateralExit>(
            predicate: #Predicate { $0.exitTxid == exitTxid }
        )
        
        if let existing = try? context.fetch(existingDescriptor).first {
            // Update existing exit instead of creating duplicate
            existing.updateStatus(.broadcasted)
            print("⚠️ ProcessStateService: Updated existing exit for txid: \(exitTxid)")
        } else {
            // Create new exit
            let newExit = OngoingUnilateralExit(
                exitTxid: exitTxid,
                challengePeriodEndHeight: challengePeriodEndHeight,
                vtxoOutpoints: vtxoOutpoints,
                totalAmountSat: totalAmountSat,
                notes: notes
            )
            context.insert(newExit)
        }
        
        try context.save()
        loadPersistedData()
        
        print("✅ ProcessStateService: Started unilateral exit: \(exitTxid)")
    }
    
    /// Mark an exit as claimed
    func markExitClaimed(exitTxid: String) throws {
        guard let context = modelContext else {
            throw ProcessStateError.noModelContext
        }
        
        guard let exit = activeUnilateralExits.first(where: { $0.exitTxid == exitTxid }) else {
            throw ProcessStateError.exitNotFound(txid: exitTxid)
        }
        
        exit.markClaimed()
        try context.save()
        loadPersistedData()
        
        print("✅ ProcessStateService: Marked exit as claimed: \(exitTxid)")
    }
    
    /// Mark an exit as failed
    func markExitFailed(exitTxid: String, error: String) throws {
        guard let context = modelContext else {
            throw ProcessStateError.noModelContext
        }
        
        guard let exit = activeUnilateralExits.first(where: { $0.exitTxid == exitTxid }) else {
            throw ProcessStateError.exitNotFound(txid: exitTxid)
        }
        
        exit.markFailed(error: error)
        try context.save()
        loadPersistedData()
        
        print("⚠️ ProcessStateService: Marked exit as failed: \(exitTxid) - \(error)")
    }
    
    /// Cancel an exit (mark as failed with cancellation message)
    func cancelExit(exitTxid: String) throws {
        try markExitFailed(exitTxid: exitTxid, error: "Cancelled by user")
    }
    
    /// Get specific exit by txid
    func getExit(txid: String) -> OngoingUnilateralExit? {
        return activeUnilateralExits.first { $0.exitTxid == txid }
    }
    
    /// Clean up old completed exits (older than 30 days)
    func cleanupOldExits() throws {
        guard let context = modelContext else {
            throw ProcessStateError.noModelContext
        }
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        // Fetch all completed exits using the predefined predicate
        let completedDescriptor = FetchDescriptor<OngoingUnilateralExit>(
            predicate: OngoingUnilateralExit.completedExitsPredicate
        )
        
        let completedExits = try context.fetch(completedDescriptor)
        let oldExits = completedExits.filter { $0.lastUpdated < thirtyDaysAgo }
        
        for exit in oldExits {
            context.delete(exit)
        }
        
        if !oldExits.isEmpty {
            try context.save()
            print("🗑️ ProcessStateService: Cleaned up \(oldExits.count) old exits")
        }
    }
    
    // MARK: - Backup Status Management
    
    /// Check if backup reminder should be shown
    var shouldShowBackupReminder: Bool {
        backupStatus?.shouldShowReminder() ?? false
    }
    
    /// Confirm that wallet has been backed up
    func confirmBackup() throws {
        guard let context = modelContext else {
            throw ProcessStateError.noModelContext
        }
        
        guard let status = backupStatus else {
            throw ProcessStateError.backupStatusNotFound
        }
        
        status.confirmBackup()
        try context.save()
        
        print("✅ ProcessStateService: Backup confirmed")
    }
    
    /// Increment transaction count (call after each transaction)
    func incrementBackupTransactionCount() {
        guard let context = modelContext else { return }
        
        backupStatus?.incrementTransactionCount()
        
        do {
            try context.save()
        } catch {
            print("⚠️ ProcessStateService: Failed to update transaction count: \(error)")
        }
    }
    
    /// Snooze backup reminder
    func snoozeBackupReminder() throws {
        guard let context = modelContext else {
            throw ProcessStateError.noModelContext
        }
        
        guard let status = backupStatus else {
            throw ProcessStateError.backupStatusNotFound
        }
        
        status.snoozeReminder()
        try context.save()
        
        print("💤 ProcessStateService: Backup reminder snoozed")
    }
    
    /// Dismiss backup reminder
    func dismissBackupReminder() throws {
        guard let context = modelContext else {
            throw ProcessStateError.noModelContext
        }
        
        guard let status = backupStatus else {
            throw ProcessStateError.backupStatusNotFound
        }
        
        status.dismissReminder()
        status.markReminderShown()
        try context.save()
        
        print("✋ ProcessStateService: Backup reminder dismissed")
    }
    
    // MARK: - Computed Properties
    
    /// Check if there are any active unilateral exits
    var hasActiveUnilateralExits: Bool {
        !activeUnilateralExits.isEmpty
    }
    
    /// Count of active exits
    var activeExitCount: Int {
        activeUnilateralExits.count
    }
    
    /// Exits requiring user action (claimable)
    var exitsRequiringAction: [OngoingUnilateralExit] {
        activeUnilateralExits.filter { $0.requiresUserAction }
    }
    
    /// Check if any exits require user action
    var hasExitsRequiringAction: Bool {
        !exitsRequiringAction.isEmpty
    }
    
    /// Total number of items requiring user attention
    var attentionItemCount: Int {
        var count = 0
        
        if vtxoHealth.hasExpiredVTXOs {
            count += vtxoHealth.expiredCount
        }
        
        if hasExitsRequiringAction {
            count += exitsRequiringAction.count
        }
        
        if shouldShowBackupReminder {
            count += 1
        }
        
        return count
    }
    
    /// Check if any state needs user attention
    var needsAttention: Bool {
        return vtxoHealth.needsAttention || 
               hasExitsRequiringAction || 
               shouldShowBackupReminder ||
               connectionStatus.showWarning
    }
    
    /// Summary message of all attention items
    var attentionSummary: String? {
        var messages: [String] = []
        
        if let vtxoMessage = vtxoHealth.statusMessage {
            messages.append(vtxoMessage)
        }
        
        if hasExitsRequiringAction {
            messages.append("\(exitsRequiringAction.count) exit\(exitsRequiringAction.count == 1 ? "" : "s") ready to claim")
        }
        
        if hasActiveUnilateralExits && !hasExitsRequiringAction {
            messages.append("\(activeExitCount) active exit\(activeExitCount == 1 ? "" : "s") in progress")
        }
        
        if shouldShowBackupReminder {
            messages.append("Backup your wallet")
        }
        
        if connectionStatus.showWarning {
            messages.append(connectionStatus.statusMessage)
        }
        
        return messages.isEmpty ? nil : messages.joined(separator: " • ")
    }
}

// MARK: - Errors

enum ProcessStateError: LocalizedError {
    case noModelContext
    case exitNotFound(txid: String)
    case backupStatusNotFound
    
    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "Database context not available"
        case .exitNotFound(let txid):
            return "Exit not found: \(txid)"
        case .backupStatusNotFound:
            return "Backup status not found"
        }
    }
}
