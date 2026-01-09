//
//  BarkWalletProtocol.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import Foundation
import Bark

// Protocol so both real and mock wallets can be used interchangeably
protocol BarkWalletProtocol {
    var walletDir: URL { get }
    var networkConfig: NetworkConfig { get }
    var isMainnet: Bool { get }
    var currentNetworkName: String { get }
    
    // MARK: - Wallet Lifecycle
    
    func executeCommand(_ args: [String]) async throws -> String
    func createWallet(network: String?, asp: String?) async throws -> String
    func importWallet(network: String?, asp: String?, mnemonic: String) async throws -> String
    func deleteWallet() async throws -> String
    func getMnemonic() async throws -> String
    func openWalletIfNeeded() async -> Bool
    
    // MARK: - Balance & Address Operations
    
    func getArkBalance() async throws -> ArkBalanceResponse
    func getArkAddress() async throws -> String
    func getOnchainAddress() async throws -> String
    func getOnchainBalance() async throws -> OnchainBalanceResponse
    
    // MARK: - Configuration & Info
    
    func getArkInfo() async throws -> ArkInfoModel
    func getConfig() async throws -> ArkConfigModel
    func getLatestBlockHeight() async throws -> Int
    func getMovements() async throws -> String
    
    // MARK: - VTXO Operations (Basic)
    
    func getVTXOs() async throws -> [VTXOModel]
    func refreshVTXOs() async throws -> String
    func refreshVTXO(vtxo_id: String) async throws -> String
    func exitVTXO(vtxo_id: String) async throws -> String
    func exitVTXO(vtxo_id: String, to address: String) async throws -> String
    
    // MARK: - VTXO Operations (Advanced - New in FFI)
    
    func allVtxos() async throws -> [Vtxo]
    func spendableVtxos() async throws -> [Vtxo]
    func getExpiringVtxos(thresholdBlocks: UInt32) async throws -> [Vtxo]
    func getVtxosToRefresh() async throws -> [Vtxo]
    func getVtxoById(vtxoId: String) async throws -> Vtxo
    func getFirstExpiringVtxoBlockheight() async throws -> UInt32?
    func getNextRequiredRefreshBlockheight() async throws -> UInt32?
    
    // MARK: - UTXO Operations
    
    func getUTXOs() async throws -> [UTXOModel]
    
    // MARK: - Exit Operations (Basic)
    
    func startExit() async throws -> String
    func startExitForVTXOs(vtxo_ids: [String]) async throws -> String
    
    // MARK: - Exit Operations (Advanced - New in FFI)
    
    func progressExits(feeRateSatPerVb: UInt64?) async throws -> [ExitProgressStatus]
    func syncExits() async throws
    func drainExits(vtxoIds: [String], address: String, feeRateSatPerVb: UInt64?) async throws -> ExitClaimTransaction
    func listClaimableExits() async throws -> [ExitVtxo]
    func getExitVtxos() async throws -> [ExitVtxo]
    func hasPendingExits() async throws -> Bool
    func pendingExitsTotalSats() async throws -> UInt64
    func getExitStatus(vtxoId: String, includeHistory: Bool, includeTransactions: Bool) async throws -> ExitTransactionStatus?
    func allExitsClaimableAtHeight() async throws -> UInt32?
    
    // MARK: - Sync & Maintenance
    
    func sync() async throws
    func maintenanceRefresh() async throws -> String?
    func maybeScheduleMaintenanceRefresh() async throws -> UInt32?
    func maintenanceWithOnchain() async throws
    
    // MARK: - Server Connection
    
    func refreshServer() async throws
    
    // MARK: - Round Management
    
    func cancelAllPendingRounds() async throws
    func cancelPendingRound(roundId: UInt32) async throws
    func pendingRoundStates() async throws -> [RoundState]
    func progressPendingRounds() async throws
    func syncPendingBoards() async throws
    
    // MARK: - Send Operations
    
    func send(to address: String, amount: Int) async throws -> String
    func sendToOnchain(to address: String, amount: Int) async throws -> String
    func sendOnchain(to address: String, amount: Int, feeRateSatPerVb: UInt64?) async throws -> String
    
    // MARK: - Board Operations
    
    func board(amount: Int) async throws
    func boardAll() async throws -> String
    
    // MARK: - Lightning Operations (Basic)
    
    func payLightningInvoice(invoice: String, amount: Int) async throws -> String
    func payLightningInvoice(invoice: String, amount: Int?) async throws -> String
    func getLightningInvoice(amount: Int) async throws -> String
    func getLightningInvoiceStatus(invoice: String) async throws -> String
    func listLightningInvoices() async throws -> String
    func claimLightningInvoice(invoice: String) async throws -> String
    
    // MARK: - Lightning Operations (Enhanced - New in FFI)
    
    func payLightningOffer(offer: String, amountSats: UInt64?) async throws -> LightningSend
    func checkLightningPayment(paymentHash: String, wait: Bool) async throws -> String?
    func lightningReceiveStatus(paymentHash: String) async throws -> LightningReceive?
    func tryClaimLightningReceive(paymentHash: String, wait: Bool) async throws
    func claimableLightningReceiveBalanceSats() async throws -> UInt64
    
    // MARK: - Network Safety Methods
    
    func requiresMainnetWarning() -> Bool
    func validateMainnetOperation() throws
    func sendWithSafetyCheck(to address: String, amount: Int) async throws -> String
    func sendOnchainWithSafetyCheck(to address: String, amount: Int, feeRateSatPerVb: UInt64?) async throws -> String
    
    // MARK: - Development
    
    func executeCustomCommand(_ commandString: String) async throws -> String
}
