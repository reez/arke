//
//  WalletManager+CustomCommands.swift
//  Arké
//
//  Custom command execution for development/debugging
//

import Foundation

extension WalletManager {
    
    /// Execute a custom bark CLI command
    /// - Parameter commandString: The command to execute (e.g., "balance", "vtxos --limit 5")
    /// - Returns: Raw command output
    /// - Note: For development and debugging purposes
    func executeCustomCommand(_ commandString: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.executeCustomCommand(commandString)
    }
}
