//
//  ConsoleViewModel.swift
//  Arké
//
//  Created by Christoph on 1/5/26.
//

import Foundation
import Observation

/// Shared view model for console functionality across platforms
@Observable
class ConsoleViewModel {
    var commandInput: String = ""
    var history: [ConsoleEntry] = []
    var isExecuting: Bool = false
    
    private var commandExecutor = CommandExecutor()
    private weak var walletManager: WalletManager?
    
    init(walletManager: WalletManager? = nil) {
        self.walletManager = walletManager
        registerWalletCommands(commandExecutor)
    }
    
    /// Execute the current command input
    @MainActor
    func executeCommand() async {
        let command = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !command.isEmpty else { return }
        guard !isExecuting else { return }
        guard let walletManager = walletManager else {
            appendError(for: command, message: "Wallet manager not available")
            return
        }
        
        isExecuting = true
        
        do {
            let context = CommandContext(walletManager: walletManager)
            let result = try await commandExecutor.execute(command, context: context)
            
            // Handle special commands
            if result == "__CLEAR__" {
                history.removeAll()
                commandInput = ""
                isExecuting = false
                return
            }
            
            history.append(ConsoleEntry(
                command: command,
                result: result.isEmpty ? "(empty response)" : result,
                isError: false,
                timestamp: Date()
            ))
            commandInput = ""
            isExecuting = false
        } catch {
            appendError(for: command, message: error.localizedDescription)
            commandInput = ""
            isExecuting = false
        }
    }
    
    /// Clear the console history
    func clearHistory() {
        history.removeAll()
    }
    
    /// Set the wallet manager reference
    func setWalletManager(_ manager: WalletManager) {
        self.walletManager = manager
    }
    
    // MARK: - Private Helpers
    
    private func appendError(for command: String, message: String) {
        history.append(ConsoleEntry(
            command: command,
            result: "Error: \(message)",
            isError: true,
            timestamp: Date()
        ))
    }
}
