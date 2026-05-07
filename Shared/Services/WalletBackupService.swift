//
//  WalletBackupService.swift
//  Arké
//
//  Manages backup and restoration of the Bark wallet database to iCloud Drive
//
//  Created by Claude on 5/7/26.
//

import Foundation
import OSLog

/// Service for backing up and restoring wallet database to/from iCloud
class WalletBackupService {
    
    // MARK: - Properties
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.arke", category: "WalletBackup")
    
    private let walletDirectory: URL
    private let databaseFileName = "bark.sqlite"
    private let backupSubdirectory = "Backups"
    
    /// iCloud ubiquity container URL (nil if iCloud unavailable)
    private var ubiquityContainer: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)
    }
    
    // MARK: - Initialization
    
    init(walletDirectory: URL) {
        self.walletDirectory = walletDirectory
        
        if ubiquityContainer != nil {
            Self.logger.info("✅ iCloud available for wallet backup")
        } else {
            Self.logger.warning("⚠️ iCloud not available - backups disabled")
        }
    }
    
    // MARK: - Backup Operations
    
    /// Performs a backup of the wallet database to iCloud
    /// - Returns: Success status
    func performBackup() async -> Bool {
        guard let container = ubiquityContainer else {
            Self.logger.debug("Backup skipped - iCloud unavailable")
            return false
        }
        
        let sourceFile = walletDirectory.appendingPathComponent(databaseFileName)
        
        // Check if source exists
        guard FileManager.default.fileExists(atPath: sourceFile.path) else {
            Self.logger.debug("Backup skipped - database file not found at: \(sourceFile.path)")
            
            // Log all files in wallet directory for debugging
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: walletDirectory,
                    includingPropertiesForKeys: [.fileSizeKey],
                    options: []
                )
                Self.logger.debug("Wallet directory contains \(contents.count) items:")
                for item in contents {
                    let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let size = (try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    Self.logger.debug("  - \(item.lastPathComponent) (\(isDirectory ? "directory" : "file"), \(size) bytes)")
                }
            } catch {
                Self.logger.debug("Failed to list wallet directory contents: \(error.localizedDescription)")
            }
            
            return false
        }
        
        // Create backup directory if needed
        let backupDir = container.appendingPathComponent(backupSubdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        
        // Create current backup file
        let currentBackup = backupDir.appendingPathComponent(databaseFileName)
        
        // Check if backup already exists and is identical
        if FileManager.default.fileExists(atPath: currentBackup.path) {
            if await filesAreIdentical(sourceFile, currentBackup) {
                Self.logger.debug("Backup skipped - no changes detected")
                return false
            }
        }
        
        do {
            // Remove old current backup
            if FileManager.default.fileExists(atPath: currentBackup.path) {
                try FileManager.default.removeItem(at: currentBackup)
            }
            
            // Copy database to iCloud
            try FileManager.default.copyItem(at: sourceFile, to: currentBackup)
            
            Self.logger.info("✅ Wallet backup completed")
            
            // Create timestamped backup for versioning
            await createTimestampedBackup(from: sourceFile, in: backupDir)
            
            return true
            
        } catch {
            Self.logger.error("❌ Backup failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Creates a timestamped backup and cleans up old ones
    private func createTimestampedBackup(from sourceFile: URL, in backupDir: URL) async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let timestampedBackup = backupDir.appendingPathComponent("db.sqlite.\(timestamp)")
        
        do {
            try FileManager.default.copyItem(at: sourceFile, to: timestampedBackup)
            Self.logger.debug("Created timestamped backup: \(timestamp)")
            
            // Clean up old backups (keep 5 most recent)
            await cleanupOldBackups(in: backupDir, keepCount: 5)
            
        } catch {
            Self.logger.warning("Failed to create timestamped backup: \(error.localizedDescription)")
        }
    }
    
    /// Removes old timestamped backups
    private func cleanupOldBackups(in directory: URL, keepCount: Int) async {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            // Filter timestamped backups only
            let timestampedBackups = files.filter { $0.lastPathComponent.hasPrefix("db.sqlite.") }
            
            // Sort by creation date (newest first)
            let sortedBackups = try timestampedBackups.sorted { file1, file2 in
                let date1 = try file1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
                let date2 = try file2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
                return date1 > date2
            }
            
            // Remove old backups
            for backup in sortedBackups.dropFirst(keepCount) {
                try FileManager.default.removeItem(at: backup)
                Self.logger.debug("Removed old backup: \(backup.lastPathComponent)")
            }
            
        } catch {
            Self.logger.warning("Failed to cleanup old backups: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Restore Operations
    
    /// Restores the wallet database from iCloud backup
    /// - Parameter overwriteExisting: If true, will overwrite existing database
    /// - Returns: Success status
    func restoreFromBackup(overwriteExisting: Bool = false) async -> Bool {
        guard let container = ubiquityContainer else {
            Self.logger.warning("Restore failed - iCloud unavailable")
            return false
        }
        
        let backupDir = container.appendingPathComponent(backupSubdirectory, isDirectory: true)
        let sourceBackup = backupDir.appendingPathComponent(databaseFileName)
        let destinationFile = walletDirectory.appendingPathComponent(databaseFileName)
        
        // Check if backup exists
        guard FileManager.default.fileExists(atPath: sourceBackup.path) else {
            Self.logger.warning("Restore failed - no backup found")
            return false
        }
        
        // Check if destination exists
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            guard overwriteExisting else {
                Self.logger.debug("Restore skipped - database exists and overwrite=false")
                return false
            }
            
            // Remove existing file
            do {
                try FileManager.default.removeItem(at: destinationFile)
            } catch {
                Self.logger.error("Failed to remove existing database: \(error.localizedDescription)")
                return false
            }
        }
        
        // Create wallet directory if needed
        try? FileManager.default.createDirectory(
            at: walletDirectory,
            withIntermediateDirectories: true
        )
        
        // Copy backup to wallet directory
        do {
            try FileManager.default.copyItem(at: sourceBackup, to: destinationFile)
            Self.logger.info("✅ Wallet database restored from backup")
            return true
        } catch {
            Self.logger.error("❌ Restore failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Status Checks
    
    /// Checks if a backup exists in iCloud
    func hasBackupAvailable() -> Bool {
        guard let container = ubiquityContainer else { return false }
        
        let backupDir = container.appendingPathComponent(backupSubdirectory, isDirectory: true)
        let backupFile = backupDir.appendingPathComponent(databaseFileName)
        
        return FileManager.default.fileExists(atPath: backupFile.path)
    }
    
    /// Gets information about the backup
    func getBackupInfo() async -> BackupInfo? {
        guard let container = ubiquityContainer else { return nil }
        
        let backupDir = container.appendingPathComponent(backupSubdirectory, isDirectory: true)
        let backupFile = backupDir.appendingPathComponent(databaseFileName)
        
        guard FileManager.default.fileExists(atPath: backupFile.path) else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: backupFile.path)
            let modificationDate = attributes[.modificationDate] as? Date
            let fileSize = attributes[.size] as? Int64
            
            return BackupInfo(
                lastBackupDate: modificationDate,
                fileSize: fileSize,
                isAvailable: true
            )
        } catch {
            Self.logger.warning("Failed to get backup info: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Private Helpers
    
    /// Compares two files to see if they are identical
    private func filesAreIdentical(_ file1: URL, _ file2: URL) async -> Bool {
        do {
            let data1 = try Data(contentsOf: file1)
            let data2 = try Data(contentsOf: file2)
            return data1 == data2
        } catch {
            return false
        }
    }
}

// MARK: - Supporting Types

struct BackupInfo {
    let lastBackupDate: Date?
    let fileSize: Int64?
    let isAvailable: Bool
    
    var formattedDate: String {
        guard let date = lastBackupDate else { return "Never" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedSize: String {
        guard let size = fileSize else { return "Unknown" }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
