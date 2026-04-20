//
//  WalletManager+Operations.swift
//  Arké
//
//  Wallet operations - send, receive, board, exit, VTXO, rounds
//  Delegates to WalletOperationsService
//

import Foundation
import Bark

extension WalletManager {
    
    // MARK: - Send/Receive/Board Operations
    
    func send(to address: String, amount: Int) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.send(to: address, amount: amount)
    }
    
    func sendOnchain(to address: String, amount: Int) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.sendOnchain(to: address, amount: amount)
    }
    
    func sendToOnchain(to address: String, amount: Int) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.sendToOnchain(to: address, amount: amount)
    }
    
    func board(amount: Int) async throws {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        try await walletOperationsService.board(amount: amount)
    }
    
    func boardAll() async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.boardAll()
    }
    
    /// Synchronize wallet state with the ASP server
    func sync() async throws {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        try await wallet.sync()
    }
    
    // MARK: - Exit Operations
    
    /// Start the exit process for pending VTXOs - checks exit progress and waits
    func startExit() async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.startExit()
    }
    
    /// Exit a specific VTXO by its ID
    func exitVTXO(vtxoId: String, to address: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.exitVTXO(vtxoId: vtxoId, to: address)
    }
    
    /// Progress unilateral exits (broadcast, fee bump, advance state machine)
    func progressExits(feeRateSatPerVb: UInt64?) async throws -> [ExitProgressStatus] {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.progressExits(feeRateSatPerVb: feeRateSatPerVb)
    }
    
    /// Sync exit state (checks status but doesn't progress)
    func syncExits() async throws {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        try await wallet.syncExits()
    }
    
    /// Get all VTXOs currently in exit process
    func getExitVtxos() async throws -> [ExitVtxo] {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.getExitVtxos()
    }
    
    /// Start exit process for specific VTXOs
    func startExitForVTXOs(vtxo_ids: [String]) async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.startExitForVTXOs(vtxo_ids: vtxo_ids)
    }
    
    /// List all exits that are currently claimable
    func listClaimableExits() async throws -> [ExitVtxo] {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.listClaimableExits()
    }
    
    /// Check if there are any pending exits
    func hasPendingExits() async throws -> Bool {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.hasPendingExits()
    }
    
    /// Get total amount in satoshis of all pending exits
    func pendingExitsTotalSats() async throws -> UInt64 {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.pendingExitsTotalSats()
    }
    
    /// Get detailed status for a specific exit
    func getExitStatus(vtxoId: String, includeHistory: Bool, includeTransactions: Bool) async throws -> ExitTransactionStatus? {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.getExitStatus(vtxoId: vtxoId, includeHistory: includeHistory, includeTransactions: includeTransactions)
    }
    
    /// Get the block height at which all exits will be claimable
    func allExitsClaimableAtHeight() async throws -> UInt32? {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.allExitsClaimableAtHeight()
    }
    
    /// Drain claimable exits to an onchain address
    func drainExits(vtxoIds: [String], address: String, feeRateSatPerVb: UInt64?) async throws -> ExitClaimTransaction {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.drainExits(vtxoIds: vtxoIds, address: address, feeRateSatPerVb: feeRateSatPerVb)
    }
    
    // MARK: - Round Operations
    
    /// Get pending round states
    func pendingRoundStates() async throws -> [RoundState] {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.pendingRoundStates()
    }
    
    /// Progress pending rounds (delegates to RoundProgressionService)
    func progressPendingRounds() async throws {
        guard let service = roundProgressionService else {
            throw BarkErrorArke.commandFailed("Round progression service not initialized")
        }
        try await service.progressRoundsManually()
    }
    
    /// Cancel a specific pending round
    /// - Parameter roundId: The ID of the round to cancel
    func cancelPendingRound(roundId: UInt32) async throws {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        try await wallet.cancelPendingRound(roundId: roundId)
    }
    
    /// Get the next round start time
    /// - Returns: Unix timestamp (seconds since epoch) of when the next round is scheduled to start
    func nextRoundStartTime() async throws -> UInt64 {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.nextRoundStartTime()
    }
    
    // MARK: - VTXO Operations
    
    func getVTXOs() async throws -> [VTXOModel] {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getVTXOs()
    }
    
    func allVtxos() async throws -> [Vtxo] {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.allVtxos()
    }
    
    // MARK: - UTXO & Config
    
    func getUTXOs() async throws -> [UTXOModel] {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getUTXOs()
    }
    
    func getConfig() async throws -> ArkConfigModel {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getConfig()
    }
    
    func getArkInfo() async throws -> ArkInfoModel {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getArkInfo()
    }
    
    // MARK: - Transaction Utilities
    
    /// Extract a raw transaction from a PSBT (Partially Signed Bitcoin Transaction)
    /// - Parameter psbtBase64: The PSBT encoded as base64
    /// - Returns: The extracted transaction as hex string
    func extractTxFromPsbt(psbtBase64: String) async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.extractTxFromPsbt(psbtBase64: psbtBase64)
    }
    
    /// Broadcast a raw transaction to the Bitcoin network
    /// - Parameter txHex: The raw transaction encoded as hex string
    /// - Returns: The transaction ID (txid) of the broadcast transaction
    func broadcastTx(txHex: String) async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.broadcastTx(txHex: txHex)
    }
    
    /**
     * Get a pull-based notification holder for this wallet.
     *
     * Call `next_notification()` in a loop to receive events.
     * Call `cancel_next_notification_wait()` to unblock a pending wait without
     * destroying the stream.
     */
    func notifications() -> NotificationHolder {
        guard let wallet = wallet else {
            fatalError("Wallet not initialized")
        }
        return wallet.notifications()
    }
}
