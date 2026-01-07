//
//  BackupStatus.swift
//  Ark wallet prototype
//
//  Created by Christoph on 1/6/26.
//

import Foundation
import SwiftData

/// Persistent model for tracking wallet backup status
@Model
final class BackupStatus {
    /// Unique identifier (singleton pattern - only one instance should exist)
    /// Note: Removed @Attribute(.unique) for CloudKit compatibility
    var id: UUID = UUID()
    
    /// Whether the user has confirmed backing up their seed phrase
    var hasConfirmedBackup: Bool = false
    
    /// Date when the backup was last confirmed
    var lastBackupConfirmationDate: Date?
    
    /// Number of transactions since last backup reminder was shown
    var transactionsSinceLastReminder: Int = 0
    
    /// Date when backup reminder was last shown
    var lastReminderShownDate: Date?
    
    /// Number of times the reminder has been dismissed/snoozed
    var reminderDismissCount: Int = 0
    
    /// Date until which the reminder is snoozed (nil if not snoozed)
    var snoozedUntilDate: Date?
    
    /// Last updated timestamp
    var lastUpdated: Date = Date()
    
    init(
        id: UUID = UUID(),
        hasConfirmedBackup: Bool = false,
        lastBackupConfirmationDate: Date? = nil,
        transactionsSinceLastReminder: Int = 0,
        lastReminderShownDate: Date? = nil,
        reminderDismissCount: Int = 0,
        snoozedUntilDate: Date? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.hasConfirmedBackup = hasConfirmedBackup
        self.lastBackupConfirmationDate = lastBackupConfirmationDate
        self.transactionsSinceLastReminder = transactionsSinceLastReminder
        self.lastReminderShownDate = lastReminderShownDate
        self.reminderDismissCount = reminderDismissCount
        self.snoozedUntilDate = snoozedUntilDate
        self.lastUpdated = lastUpdated
    }
    
    // MARK: - Configuration Constants
    
    /// Number of transactions before showing reminder again
    static let transactionThreshold = 5
    
    /// Days between reminders (if dismissed)
    static let reminderIntervalDays = 7
    
    /// Hours to snooze when user dismisses
    static let snoozeHours = 24
    
    // MARK: - Backup Confirmation
    
    /// Mark backup as confirmed
    func confirmBackup() {
        self.hasConfirmedBackup = true
        self.lastBackupConfirmationDate = Date()
        self.transactionsSinceLastReminder = 0
        self.reminderDismissCount = 0
        self.snoozedUntilDate = nil
        self.lastUpdated = Date()
    }
    
    /// Increment transaction counter
    func incrementTransactionCount() {
        self.transactionsSinceLastReminder += 1
        self.lastUpdated = Date()
    }
    
    // MARK: - Reminder Management
    
    /// Check if reminder should be shown
    func shouldShowReminder() -> Bool {
        // Already backed up, no need to remind
        if hasConfirmedBackup {
            return false
        }
        
        // Currently snoozed
        if let snoozedUntil = snoozedUntilDate, Date() < snoozedUntil {
            return false
        }
        
        // Check transaction threshold
        if transactionsSinceLastReminder >= Self.transactionThreshold {
            return true
        }
        
        // Check time-based reminder (if previously shown and dismissed)
        if let lastShown = lastReminderShownDate {
            let daysSinceLastReminder = Calendar.current.dateComponents([.day], from: lastShown, to: Date()).day ?? 0
            if daysSinceLastReminder >= Self.reminderIntervalDays {
                return true
            }
        }
        
        // First time user - show after some transactions
        if lastReminderShownDate == nil && transactionsSinceLastReminder >= 3 {
            return true
        }
        
        return false
    }
    
    /// Mark reminder as shown
    func markReminderShown() {
        self.lastReminderShownDate = Date()
        self.lastUpdated = Date()
    }
    
    /// Dismiss/snooze reminder
    func snoozeReminder() {
        self.reminderDismissCount += 1
        self.snoozedUntilDate = Calendar.current.date(byAdding: .hour, value: Self.snoozeHours, to: Date())
        self.transactionsSinceLastReminder = 0
        self.lastUpdated = Date()
    }
    
    /// Dismiss reminder permanently (until more transactions)
    func dismissReminder() {
        self.reminderDismissCount += 1
        self.transactionsSinceLastReminder = 0
        self.lastReminderShownDate = Date()
        self.snoozedUntilDate = nil
        self.lastUpdated = Date()
    }
    
    // MARK: - Display Properties
    
    /// Get reminder message based on context
    var reminderMessage: String {
        if transactionsSinceLastReminder >= Self.transactionThreshold {
            return "You've made \(transactionsSinceLastReminder) transactions. Back up your wallet to protect your funds."
        } else if reminderDismissCount > 0 {
            return "Back up your wallet to ensure you can recover your funds if you lose access."
        } else {
            return "Back up your wallet to protect your funds. Write down your seed phrase and store it safely."
        }
    }
    
    /// Priority level for the reminder
    var reminderPriority: ReminderPriority {
        if transactionsSinceLastReminder >= 10 {
            return .high
        } else if transactionsSinceLastReminder >= Self.transactionThreshold {
            return .medium
        } else {
            return .low
        }
    }
}

/// Priority levels for backup reminders
enum ReminderPriority: Comparable, Sendable {
    case low
    case medium
    case high
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}
// MARK: - Singleton Pattern Helper

extension BackupStatus {
    /// Get the singleton BackupStatus instance, creating one if it doesn't exist
    /// - Parameter context: The ModelContext to use
    /// - Returns: The singleton BackupStatus instance
    static func getSingleton(context: ModelContext) throws -> BackupStatus {
        let descriptor = FetchDescriptor<BackupStatus>()
        let existing = try context.fetch(descriptor)
        
        if let first = existing.first {
            // Delete any duplicate instances (cleanup)
            for duplicate in existing.dropFirst() {
                context.delete(duplicate)
                print("⚠️ Deleted duplicate BackupStatus instance")
            }
            return first
        } else {
            // Create new singleton instance
            let newStatus = BackupStatus()
            context.insert(newStatus)
            print("✅ Created new BackupStatus singleton")
            return newStatus
        }
    }
    
    /// Check if a BackupStatus instance exists
    /// - Parameter context: The ModelContext to use
    /// - Returns: True if at least one instance exists
    static func exists(context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<BackupStatus>()
        descriptor.fetchLimit = 1
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }
}

