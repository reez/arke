//
//  WalletManager+CustomCommands.swift
//  Arké
//
//  Custom command execution
//  For development and debugging purposes only - allows executing arbitrary wallet commands
//

import Foundation

extension WalletManager {
    
    // MARK: - Custom Command Execution
    
    /// Execute a custom bark wallet command
    /// - Parameter commandString: The command to execute (e.g., "balance", "vtxos --limit 5")
    /// - Returns: Raw command output as string
    /// - Warning: For development and debugging purposes only
    func executeCustomCommand(_ commandString: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.executeCustomCommand(commandString)
    }
}
