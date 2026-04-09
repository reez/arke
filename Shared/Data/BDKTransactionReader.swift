//
//  BDKTransactionReader.swift
//  Arké
//
//  Lightweight BDK wallet wrapper for reading onchain transaction history
//  Used alongside Bark's OnchainWallet.default() - does NOT replace it
//

import Foundation
import BitcoinDevKit
import Bark

/// Read-only BDK wallet service for listing onchain transactions
/// 
/// This service runs in parallel with Bark's built-in OnchainWallet to provide
/// transaction history functionality that is not exposed in the Bark FFI.
/// 
/// Architecture:
/// - OnchainWallet.default() → Main wallet (CPFP, boarding, exits)
/// - BDKTransactionReader → Transaction history only
///
/// Wallet Configuration (matches Bark's built-in wallet):
/// - Uses Wallet.createSingle() / loadSingle() - same as Bark's Wallet::create_single()
/// - BIP86 (Taproot) derivation: m/86'/coin_type'/0'/0/*
/// - Single-descriptor wallet (no separate change descriptor)
/// - Empty BIP39 passphrase (matches Bark's mnemonic.to_seed(""))
/// - Same network as Bark wallet
final class BDKTransactionReader {
    
    private let wallet: BitcoinDevKit.Wallet
    private let esploraClient: EsploraClient
    
    // MARK: - Initialization
    
    /// Initialize a read-only BDK wallet for transaction queries
    /// - Parameters:
    ///   - mnemonic: BIP39 mnemonic phrase
    ///   - network: Bark Network type
    ///   - esploraURL: Esplora server URL
    ///   - dataDir: Directory to store wallet database
    init(mnemonic: String, network: Bark.Network, esploraURL: String, dataDir: URL) throws {
        print("📜 Initializing BDKTransactionReader...")
        
        // Convert Bark Network to BDK Network
        let bdkNetwork = try Self.convertToBDKNetwork(network)
        
        // Create descriptor from mnemonic
        // IMPORTANT: Must match Bark's onchain wallet configuration:
        // - BIP86 (Taproot) 
        // - Empty BIP39 passphrase
        // - External path: m/86'/coin_type'/0'/0/*
        // - Single-descriptor wallet using Wallet.createSingle() (same as Bark's Wallet::create_single)
        let mnemonicObj = try Mnemonic.fromString(mnemonic: mnemonic)
        let secretKey = DescriptorSecretKey(
            network: bdkNetwork,
            mnemonic: mnemonicObj,
            password: nil  // Empty passphrase to match Bark's mnemonic.to_seed("")
        )
        
        let descriptor = Descriptor.newBip86(
            secretKey: secretKey,
            keychainKind: .external,
            network: bdkNetwork
        )
        
        // Diagnostic: log the descriptor string
        print("   📋 Descriptor: \(String(describing: descriptor))")
        
        // Create persister (separate database from main wallet)
        let dbPath = dataDir.appendingPathComponent("bdk_transactions.db")
        let persister = try Persister.newSqlite(path: dbPath.path)
        
        // Create or load single-descriptor wallet to match Bark's Wallet::create_single()
        if FileManager.default.fileExists(atPath: dbPath.path) {
            print("   Loading existing single-descriptor transaction database...")
            do {
                self.wallet = try BitcoinDevKit.Wallet.loadSingle(
                    descriptor: descriptor,
                    persister: persister
                )
            } catch {
                print("   ⚠️ Failed to load existing database, recreating: \(error)")
                // Delete old database and create new one
                try? FileManager.default.removeItem(at: dbPath)
                let newPersister = try Persister.newSqlite(path: dbPath.path)
                self.wallet = try BitcoinDevKit.Wallet.createSingle(
                    descriptor: descriptor,
                    network: bdkNetwork,
                    persister: newPersister
                )
            }
        } else {
            print("   Creating new single-descriptor transaction database...")
            self.wallet = try BitcoinDevKit.Wallet.createSingle(
                descriptor: descriptor,
                network: bdkNetwork,
                persister: persister
            )
        }
        
        self.esploraClient = EsploraClient(url: esploraURL)
        print("✅ BDKTransactionReader initialized")
    }
    
    // MARK: - Public Methods
    
    /// Sync the wallet to fetch latest transactions
    /// - Parameters:
    ///   - fullScan: If true, performs full scan. If false, incremental sync.
    ///   - stopGap: Number of consecutive unused addresses before stopping
    ///   - parallelRequests: Number of parallel requests to Esplora
    func sync(fullScan: Bool = false, stopGap: UInt64 = 10, parallelRequests: UInt64 = 3) async throws {
        try await Task {
            if fullScan {
                let fullScanRequest = try self.wallet.startFullScan().build()
                let update = try self.esploraClient.fullScan(
                    request: fullScanRequest,
                    stopGap: stopGap,
                    parallelRequests: parallelRequests
                )
                try self.wallet.applyUpdate(update: update)
            } else {
                let syncRequest = try self.wallet.startSyncWithRevealedSpks().build()
                let update = try self.esploraClient.sync(
                    request: syncRequest,
                    parallelRequests: parallelRequests
                )
                try self.wallet.applyUpdate(update: update)
            }
        }.value
    }
    
    /// Get the first receiving address (for diagnostic comparison)
    /// - Returns: First external address as string
    func getFirstAddress() -> String {
        let addressInfo = wallet.revealNextAddress(keychain: .external)
        return String(describing: addressInfo.address)
    }
    
    /// Get the first N receiving addresses (for diagnostic comparison)
    /// - Parameter count: Number of addresses to generate
    /// - Returns: Array of addresses as strings
    func getFirstNAddresses(count: Int) -> [String] {
        var addresses: [String] = []
        for _ in 0..<count {
            let addressInfo = wallet.revealNextAddress(keychain: .external)
            addresses.append(String(describing: addressInfo.address))
        }
        return addresses
    }
    
    /// List all transactions in the wallet
    /// - Returns: Array of transactions with confirmation status
    func listTransactions() -> [CanonicalTx] {
        return wallet.transactions()
    }
    
    /// Get detailed transaction information
    /// - Returns: Array of tuples with txid, sent, received, fee, and confirmation details
    func getTransactionDetails() -> [(txid: String, sent: UInt64, received: UInt64, fee: UInt64?, confirmationTime: ConfirmationTime?)] {
        let transactions = wallet.transactions()
        
        print("🔍 BDKTransactionReader analyzing \(transactions.count) transactions...")
        
        return transactions.map { canonicalTx in
            let tx = canonicalTx.transaction
            let txid = String(describing: tx.computeTxid())
            
            print("\n   📝 TX: \(txid.prefix(16))...")
            
            // Calculate sent and received amounts
            var sent: UInt64 = 0
            var received: UInt64 = 0
            var outputsOwnedByWallet = 0
            
            // Get our wallet's outputs that are spent by this transaction
            let utxos = wallet.listUnspent()
            for input in tx.input() {
                let prevOut = input.previousOutput
                for utxo in utxos {
                    if String(describing: utxo.outpoint.txid) == String(describing: prevOut.txid) 
                        && utxo.outpoint.vout == prevOut.vout {
                        sent += utxo.txout.value.toSat()
                    }
                }
            }
            
            // Get outputs received by our wallet
            for (vout, output) in tx.output().enumerated() {
                // Check if this output belongs to our wallet
                if wallet.isMine(script: output.scriptPubkey) {
                    received += output.value.toSat()
                    outputsOwnedByWallet += 1
                    print("      Output #\(vout): \(output.value.toSat()) sats → OURS ✓")
                } else {
                    print("      Output #\(vout): \(output.value.toSat()) sats → not ours")
                }
            }
            
            print("      Summary: sent=\(sent), received=\(received), ours=\(outputsOwnedByWallet)/\(tx.output().count)")
            
            // Get fee (only if we sent the transaction)
            let fee: UInt64? = sent > 0 ? (sent > received ? sent - received : nil) : nil
            
            // Get confirmation info
            let confirmationTime = getConfirmationTime(chainPosition: canonicalTx.chainPosition)
            
            return (txid, sent, received, fee, confirmationTime)
        }
    }
    
    // MARK: - Private Helpers
    
    private func getConfirmationTime(chainPosition: ChainPosition) -> ConfirmationTime? {
        switch chainPosition {
        case .confirmed(let confirmationBlockTime, _):
            // Get current height if possible (would need to query chain for accurate confirmations)
            // For now, we don't have current height, so ConfirmationTime will show 1 confirmation minimum
            return ConfirmationTime(
                height: confirmationBlockTime.blockId.height,
                timestamp: confirmationBlockTime.confirmationTime,
                blockHash: String(describing: confirmationBlockTime.blockId.hash),
                currentHeight: nil  // Could be enhanced by querying Esplora for current height
            )
        case .unconfirmed:
            return nil
        }
    }
    
    private static func convertToBDKNetwork(_ network: Bark.Network) throws -> BitcoinDevKit.Network {
        switch network {
        case .bitcoin:
            return .bitcoin
        case .testnet:
            return .testnet
        case .signet:
            return .signet
        case .regtest:
            return .regtest
        @unknown default:
            throw BDKTransactionReaderError.unsupportedNetwork
        }
    }
}

// MARK: - Errors

enum BDKTransactionReaderError: Error {
    case unsupportedNetwork
    case syncFailed(Error)
}
