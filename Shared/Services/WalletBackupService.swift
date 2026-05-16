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
    
    // MARK: - Static Helpers for Device Migration
    
    /// Check if wallet database file exists locally
    /// Used to determine if restore from backup is needed during device migration
    /// - Returns: True if bark.sqlite exists in the wallet directory
    static func hasLocalWalletFile() -> Bool {
        let walletDirectory = getWalletDirectory()
        let walletFilePath = walletDirectory.appendingPathComponent("bark.sqlite")
        let exists = FileManager.default.fileExists(atPath: walletFilePath.path)
        
        logger.debug("Wallet file exists check: \(exists) at \(walletFilePath.path)")
        return exists
    }
    
    /// Get the modification date of the local wallet database file
    /// Used to compare with backup timestamps to determine which is newer
    /// - Returns: Modification date of bark.sqlite, or nil if file doesn't exist or error occurs
    static func getLocalWalletFileModificationDate() -> Date? {
        let walletDirectory = getWalletDirectory()
        let walletFilePath = walletDirectory.appendingPathComponent("bark.sqlite")
        
        guard FileManager.default.fileExists(atPath: walletFilePath.path) else {
            logger.debug("Local wallet file does not exist")
            return nil
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: walletFilePath.path)
            let modificationDate = attributes[.modificationDate] as? Date
            
            logger.debug("Local wallet file modification date: \(modificationDate?.description ?? "unknown")")
            return modificationDate
        } catch {
            logger.warning("⚠️ Error getting local wallet file date: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Gets the wallet directory path (duplicated from BarkWalletFFI for static access)
    private static func getWalletDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        return appSupport
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "GBKS.Arke")
            .appendingPathComponent("bark-data-ffi")
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
    
    /// Restores wallet database from a user-selected backup file
    /// - Parameter sourceFileURL: URL of the backup file selected by user
    /// - Returns: Success status
    /// - Throws: Error if restoration fails
    func restoreFromUserBackup(sourceFileURL: URL) async throws -> Bool {
        let destinationFile = walletDirectory.appendingPathComponent(databaseFileName)
        
        // Start accessing security-scoped resource (required for file picker selections)
        let accessGranted = sourceFileURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                sourceFileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Check if source file exists
        guard FileManager.default.fileExists(atPath: sourceFileURL.path) else {
            Self.logger.error("Backup file not found at: \(sourceFileURL.path)")
            throw BackupError.fileNotFound
        }
        
        // Basic validation: Check if it's a SQLite file by reading the header
        do {
            let fileHandle = try FileHandle(forReadingFrom: sourceFileURL)
            defer { try? fileHandle.close() }
            
            let headerData = fileHandle.readData(ofLength: 16)
            let sqliteHeader = "SQLite format 3\0".data(using: .utf8)
            
            guard headerData.prefix(16) == sqliteHeader else {
                Self.logger.error("Invalid backup file - not a SQLite database")
                throw BackupError.invalidFormat
            }
        } catch let error as BackupError {
            throw error
        } catch {
            Self.logger.error("Failed to validate backup file: \(error.localizedDescription)")
            throw BackupError.validationFailed(error.localizedDescription)
        }
        
        // Remove existing database if present
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            do {
                try FileManager.default.removeItem(at: destinationFile)
                Self.logger.debug("Removed existing database file")
            } catch {
                Self.logger.error("Failed to remove existing database: \(error.localizedDescription)")
                throw BackupError.removalFailed(error.localizedDescription)
            }
        }
        
        // Create wallet directory if needed
        try? FileManager.default.createDirectory(
            at: walletDirectory,
            withIntermediateDirectories: true
        )
        
        // Copy backup to wallet directory
        do {
            try FileManager.default.copyItem(at: sourceFileURL, to: destinationFile)
            Self.logger.info("✅ Wallet database restored from user backup: \(sourceFileURL.lastPathComponent)")
            return true
        } catch {
            Self.logger.error("❌ Failed to copy backup file: \(error.localizedDescription)")
            throw BackupError.copyFailed(error.localizedDescription)
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
    
    /// Gets the URL of the backup file for sharing/exporting
    func getBackupFileURL() -> URL? {
        guard let container = ubiquityContainer else { return nil }
        
        let backupDir = container.appendingPathComponent(backupSubdirectory, isDirectory: true)
        let backupFile = backupDir.appendingPathComponent(databaseFileName)
        
        guard FileManager.default.fileExists(atPath: backupFile.path) else { return nil }
        
        return backupFile
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

enum BackupError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case validationFailed(String)
    case removalFailed(String)
    case copyFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Backup file not found"
        case .invalidFormat:
            return "Invalid backup file - not a SQLite database"
        case .validationFailed(let message):
            return "Failed to validate backup file: \(message)"
        case .removalFailed(let message):
            return "Failed to remove existing database: \(message)"
        case .copyFailed(let message):
            return "Failed to copy backup file: \(message)"
        }
    }
}

struct BackupInfo {
    let lastBackupDate: Date?
    let fileSize: Int64?
    let isAvailable: Bool
    
    var formattedDate: String {
        guard let date = lastBackupDate else { return "Never" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var formattedSize: String {
        guard let size = fileSize else { return "Unknown" }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
