//
//  WalletManager+ProcessState.swift
//  Arké
//
//  Process state management - backup reminders, VTXO health, connection status
//

import Foundation

extension WalletManager {
    
    /// Access to ProcessStateService for direct service access if needed
    var processStateServiceInstance: ProcessStateService? {
        processStateService
    }
    
    /// Confirm that wallet has been backed up
    func confirmBackup() throws {
        guard let processStateService = processStateService else {
            throw BarkErrorArke.commandFailed("Process state service not initialized")
        }
        try processStateService.confirmBackup()
    }
    
    /// Snooze the backup reminder
    func snoozeBackupReminder() throws {
        guard let processStateService = processStateService else {
            throw BarkErrorArke.commandFailed("Process state service not initialized")
        }
        try processStateService.snoozeBackupReminder()
    }
    
    /// Dismiss the backup reminder
    func dismissBackupReminder() throws {
        guard let processStateService = processStateService else {
            throw BarkErrorArke.commandFailed("Process state service not initialized")
        }
        try processStateService.dismissBackupReminder()
    }
    
    // MARK: - Other Process State
    
    /// VTXO health status
    var vtxoHealth: VTXOHealth {
        processStateService?.vtxoHealth ?? VTXOHealth()
    }
    
    /// Connection status
    var connectionStatus: ConnectionStatus {
        processStateService?.connectionStatus ?? ConnectionStatus()
    }
    
    /// Backup status
    var backupStatus: BackupStatus? {
        processStateService?.backupStatus
    }
    
    /// Whether backup reminder should be shown
    var shouldShowBackupReminder: Bool {
        processStateService?.shouldShowBackupReminder ?? false
    }
    
    /// Total count of items requiring user attention
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
    
    /// Whether any state needs user attention
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
            let count = exitsRequiringAction.count
            messages.append("\(count) exit\(count == 1 ? "" : "s") ready to claim")
        }
        
        if hasActiveUnilateralExits && !hasExitsRequiringAction {
            let count = activeUnilateralExits.count
            messages.append("\(count) active exit\(count == 1 ? "" : "s") in progress")
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
