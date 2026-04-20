//
//  BarkWalletFFI.swift
//  Ark wallet prototype
//
//  FFI-based implementation of BarkWalletProtocol using Rust library
//
//  IMPLEMENTATION STATUS:
//  ✅ Implemented: Most core wallet operations are fully functional
//  ✅ NEW: Unilateral exit system fully implemented (10+ methods)
//  ✅ NEW: Advanced VTXO operations (allVtxos, spendableVtxos, getExpiringVtxos, etc.)
//  ✅ NEW: Maintenance operations (maintenanceRefresh, maybeScheduleMaintenanceRefresh)
//  ✅ NEW: Server connection refresh (refreshServer)
//  ✅ NEW: Round management (cancel, progress, pending states)
//  ✅ NEW: Enhanced Lightning operations (BOLT12 offers, payment status checks)
//  ✅ NEW: Board syncing (syncPendingBoards)
//  ✅ NEW: Boarding operations (board, boardAll) - Fully implemented with OnchainWallet
//  ✅ NEW: Direct onchain transactions (sendOnchain) - Send Bitcoin from onchain balance
//
//  ⚠️ Cannot implement (not in FFI):
//     - getUTXOs() - UTXOs managed internally by wallet
//
//  🆕 Methods now available in FFI and fully implemented:
//     Exit System:
//     - startExit() / startExitForVTXOs() - Start unilateral exits
//     - progressExits() - Advance exit state machine
//     - syncExits() - Sync exit state
//     - drainExits() - Claim exited funds
//     - listClaimableExits() - Get claimable exits
//     - getExitVtxos() - Get VTXOs in exit process
//     - hasPendingExits() - Check for pending exits
//     - pendingExitsTotalSats() - Get pending exit amounts
//     - getExitStatus() - Detailed exit status
//     - allExitsClaimableAtHeight() - Get claimable height
//
//     VTXO Operations:
//     - allVtxos() - Get all VTXOs including spent
//     - spendableVtxos() - Get only spendable VTXOs
//     - getExpiringVtxos(thresholdBlocks:) - Get VTXOs expiring soon
//     - getVtxosToRefresh() - Get VTXOs needing refresh
//     - getVtxoById(vtxoId:) - Get specific VTXO by ID
//     - getFirstExpiringVtxoBlockheight() - Get first expiry height
//     - getNextRequiredRefreshBlockheight() - Get next refresh height
//
//     Boarding:
//     - board(amount:) - Board specific amount of onchain BTC into Ark
//     - boardAll() - Board all available onchain BTC into Ark
//
//     Maintenance:
//     - maintenanceRefresh() - Perform maintenance refresh (returns round ID)
//     - maybeScheduleMaintenanceRefresh() - Schedule if needed
//     - maintenanceWithOnchain() - Full maintenance with onchain sync
//
//     Server & Rounds:
//     - refreshServer() - Refresh server connection
//     - cancelAllPendingRounds() - Cancel all pending rounds
//     - cancelPendingRound(roundId:) - Cancel specific round
//     - pendingRoundStates() - Get pending round states
//     - progressPendingRounds() - Progress pending rounds
//     - syncPendingBoards() - Sync pending board transactions
//
//     Lightning:
//     - payLightningOffer(offer:amountSats:) - Pay BOLT12 offer
//     - checkLightningPayment(paymentHash:wait:) - Check payment status
//     - lightningReceiveStatus(paymentHash:) - Get receive status
//     - tryClaimLightningReceive(paymentHash:wait:) - Claim specific receive
//     - claimableLightningReceiveBalanceSats() - Get claimable balance
//
//     Other:
//     - exitVTXO(vtxo_id:to:) - Exit specific VTXO to address
//     - newAddressWithIndex() - Generate address with derivation index
//     - peakAddress(index:) - Peek at address at specific index
//     - payLightningAddress(lightningAddress:amountSats:comment:) - Pay to Lightning address
//

import Foundation
import Bark

/// FFI-based implementation of BarkWalletProtocol using the Rust bark library
/// This provides better performance and type safety compared to the CLI-based approach
class BarkWalletFFI: BarkWalletProtocol {
    
    // MARK: - Properties
    
    /// The underlying FFI wallet object (nil until wallet is created/opened)
    var wallet: Wallet?
    
    /// The onchain wallet (managed internally, created alongside main wallet)
    var onchainWallet: OnchainWallet?
    
    /// Read-only transaction history reader (runs alongside OnchainWallet.default())
    var transactionReader: BDKTransactionReader?
    
    /// FFI configuration object
    let config: Config
    
    /// Network configuration (our app's model)
    let networkConfig: NetworkConfig
    
    /// Wallet directory URL
    let walletDir: URL
    
    /// Data directory path string (for FFI calls)
    let datadir: String
    
    /// Cached mnemonic (stored securely in production)
    var cachedMnemonic: String?
    
    /// Whether this is a preview/mock instance
    let isPreview: Bool
    
    /// Security service for secure mnemonic storage and biometric authentication
    let securityService: SecurityService?
    
    // MARK: - Initialization
    
    init?(networkConfig: NetworkConfig = .signet, securityService: SecurityService? = nil) {
        self.networkConfig = networkConfig
        self.isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        self.securityService = securityService
        
        // Set up wallet directory
        self.walletDir = Self.getWalletDirectory()
        self.datadir = walletDir.path
        
        // Convert NetworkConfig to FFI Config
        guard let ffiNetwork = Self.convertToFFINetwork(networkConfig.networkType) else {
            print("❌ Invalid network type: \(networkConfig.networkType)")
            return nil
        }
        
        self.config = Config(
            serverAddress: networkConfig.aspBaseURL,
            esploraAddress: networkConfig.esploraBaseURL,
            bitcoindAddress: nil,  // Optional - not needed for basic wallet operations
            bitcoindCookiefile: nil,
            bitcoindUser: nil,
            bitcoindPass: nil,
            network: ffiNetwork,
            vtxoRefreshExpiryThreshold: nil,  // Use defaults
            vtxoExitMargin: nil,
            htlcRecvClaimDelta: nil,
            fallbackFeeRate: nil,  // Use default fee rate
            roundTxRequiredConfirmations: nil,  // Use default confirmations
            daemonFastSyncIntervalSecs: nil,  // Use default fast sync interval
            daemonSlowSyncIntervalSecs: nil   // Use default slow sync interval
        )
        
        print("✅ BarkWalletFFI initialized")
        print("   Network: \(networkConfig.name)")
        print("   Wallet dir: \(walletDir.path)")
        
        // Note: Wallet opening is now explicit via openWalletIfNeeded()
        // This prevents uncoordinated background opening during init
    }
    
    // MARK: - Utilities
    
    func extractTxFromPsbt(psbtBase64: String) async throws -> String {
        print("🔧 Extracting transaction from PSBT...")
        
        do {
            // Call FFI method on onchain wallet to extract transaction hex from PSBT
            let txHex = try Bark.extractTxFromPsbt(psbtBase64: psbtBase64)
            
            print("✅ Transaction extracted from PSBT")
            print("   Tx hex length: \(txHex.count) characters")
            
            return txHex
            
        } catch let error as BarkError {
            print("❌ FFI Error extracting transaction from PSBT: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to extract transaction: \(error.localizedDescription)")
        } catch {
            print("❌ Unexpected error extracting transaction from PSBT: \(error)")
            throw error
        }
    }
    
    func broadcastTx(txHex: String) async throws -> String {
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Broadcasting transaction...")
        print("   Network: \(networkConfig.name)")
        
        do {
            // Call FFI method to broadcast transaction
            let txid = try await wallet.broadcastTx(txHex: txHex)
            
            print("✅ Transaction broadcast successfully")
            print("   Txid: \(txid)")
            
            return txid
            
        } catch let error as BarkError {
            print("❌ FFI Error broadcasting transaction: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to broadcast transaction: \(error.localizedDescription)")
        } catch {
            print("❌ Unexpected error broadcasting transaction: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private static func getWalletDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        let walletDir = appSupport
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.yourapp.arkwallet")
            .appendingPathComponent("bark-data-ffi")
        
        // Create directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: walletDir.path) {
            do {
                // Create directory with explicit permissions that allow file creation
                #if os(macOS)
                let attributes: [FileAttributeKey: Any] = [
                    .posixPermissions: NSNumber(value: 0o755)
                ]
                try fileManager.createDirectory(
                    at: walletDir,
                    withIntermediateDirectories: true,
                    attributes: attributes
                )
                #else
                try fileManager.createDirectory(
                    at: walletDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                #endif
                
                print("📁 Created wallet directory: \(walletDir.path)")
                
                // Verify directory is writable by attempting to create a test file
                let testFile = walletDir.appendingPathComponent(".test")
                do {
                    try "test".write(to: testFile, atomically: true, encoding: .utf8)
                    try fileManager.removeItem(at: testFile)
                    print("✅ Wallet directory is writable")
                } catch {
                    print("⚠️ Warning: Wallet directory may not be writable: \(error)")
                }
                
            } catch {
                print("❌ Failed to create wallet directory: \(error)")
            }
        } else {
            print("📁 FFI Wallet directory exists: \(walletDir.path)")
            
            // Verify existing directory is writable
            let testFile = walletDir.appendingPathComponent(".test")
            do {
                try "test".write(to: testFile, atomically: true, encoding: .utf8)
                try fileManager.removeItem(at: testFile)
                print("✅ Wallet directory is writable")
            } catch {
                print("⚠️ Warning: Existing wallet directory may not be writable: \(error)")
            }
        }
        
        return walletDir
    }
}

// MARK: - Error Types

enum BarkWalletFFIError: Error, LocalizedError {
    case notImplemented(String)
    case notSupported(String)
    case walletNotInitialized
    case invalidMnemonic
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .notImplemented(let method):
            return "Method not yet implemented: \(method)"
        case .notSupported(let method):
            return "Method not supported in FFI implementation: \(method)"
        case .walletNotInitialized:
            return "Wallet has not been created or opened"
        case .invalidMnemonic:
            return "Invalid mnemonic phrase"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}
