//
//  BarkWalletFFI+Backup.swift
//  Arké
//
//  Wallet backup and restoration operations
//  Provides integration between BarkWalletFFI and WalletBackupService
//
//  Created by Claude on 5/7/26.
//

import Foundation
import OSLog

extension BarkWalletFFI {
    
    // MARK: - Backup Operations
    
    /// Performs an immediate backup of the wallet database to iCloud
    /// - Returns: Success status
    @discardableResult
    func backupWallet() async -> Bool {
        guard !isPreview else {
            return false
        }
        
        guard wallet != nil else {
            Self.logger.debug("Backup skipped - wallet not initialized")
            return false
        }
        
        let backupService = WalletBackupService(walletDirectory: walletDir)
        return await backupService.performBackup()
    }
    
    // MARK: - Restore Operations
    
    /// Checks if an iCloud backup is available for restoration
    /// - Returns: True if backup exists in iCloud
    func hasBackupAvailable() -> Bool {
        guard !isPreview else {
            return false
        }
        
        let backupService = WalletBackupService(walletDirectory: walletDir)
        return backupService.hasBackupAvailable()
    }
    
    /// Gets information about the available backup
    /// - Returns: Backup metadata if available
    func getBackupInfo() async -> BackupInfo? {
        guard !isPreview else {
            return nil
        }
        
        let backupService = WalletBackupService(walletDirectory: walletDir)
        return await backupService.getBackupInfo()
    }
    
    /// Restores wallet database from iCloud backup
    /// WARNING: This will shutdown the current wallet and replace the database
    /// - Returns: Success status
    @discardableResult
    func restoreWalletFromBackup() async throws -> Bool {
        guard !isPreview else {
            return false
        }
        
        Self.logger.info("Starting wallet restoration from iCloud backup")
        
        // Shutdown current wallet if running
        if wallet != nil {
            Self.logger.debug("Shutting down wallet before restore")
            await shutdownWallet()
        }
        
        // Restore database
        let backupService = WalletBackupService(walletDirectory: walletDir)
        let restored = await backupService.restoreFromBackup(overwriteExisting: true)
        
        guard restored else {
            throw BarkWalletFFIError.configurationError("Failed to restore database from backup")
        }
        
        Self.logger.info("✅ Wallet database restored from backup")
        return true
    }
}
