//
//  BarkWallet+Transactions.swift
//  Arke
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension BarkWalletFFI {
    
    func getOnchainTransactions() async throws -> [OnchainTransactionModel] {
        // Get onchain transaction history from transaction service
        
        if isPreview {
            return OnchainTransactionModel.mockTransactions()
        }
        
        // Ensure transaction reader is initialized
        guard let txReader = transactionReader else {
            print("⚠️ Transaction reader not initialized - cannot fetch transaction history")
            throw BarkWalletFFIError.configurationError("Transaction reader not initialized")
        }
        
        print("🔧 Fetching onchain transaction history...")
        
        do {
            // Sync transaction reader first to get latest transactions
            try await txReader.sync()
            
            // Get transaction details from reader
            let txDetails = txReader.getTransactionDetails()
            
            // Convert to OnchainTransactionModel
            let transactions = txDetails.map { detail in
                OnchainTransactionModel(
                    txid: detail.txid,
                    received: detail.received,
                    sent: detail.sent,
                    fee: detail.fee,
                    confirmationTime: detail.confirmationTime,
                    isSelfTransfer: detail.isSelfTransfer
                )
            }
            
            print("✅ Retrieved \(transactions.count) onchain transactions")
            
            // Print detailed information for each transaction
            print("📋 ONCHAIN TRANSACTION DETAILS:")
            print("================================")
            for (index, tx) in transactions.enumerated() {
                print("\n🔹 Transaction #\(index + 1):")
                print("   TXID: \(tx.txid)")
                
                // Calculate net amount safely (avoiding unsigned integer overflow)
                let netAmount: Int64
                if tx.sent >= tx.received {
                    netAmount = -Int64(tx.sent - tx.received)  // Negative for outgoing
                } else {
                    netAmount = Int64(tx.received - tx.sent)   // Positive for incoming
                }
                print("   Net Amount: \(netAmount) sats")
                print("   Sent: \(tx.sent) sats")
                print("   Received: \(tx.received) sats")
                print("   Fee: \(tx.fee?.description ?? "unknown") sats")
                
                if let confirmationTime = tx.confirmationTime {
                    print("   Status: ✅ Confirmed")
                    print("   Block Height: \(confirmationTime.height)")
                    print("   Timestamp: \(confirmationTime.timestamp)")
                    let date = Date(timeIntervalSince1970: TimeInterval(confirmationTime.timestamp))
                    print("   Date: \(date)")
                } else {
                    print("   Status: ⏳ Pending (unconfirmed)")
                }
                
                print("   Is Confirmed: \(tx.isConfirmed)")
                print("   Confirmations: \(tx.confirmations)")
                
                // Print type
                if tx.isSelfTransfer {
                    print("   Type: 🔄 SELF-TRANSFER")
                } else if tx.sent > tx.received {
                    print("   Type: 📤 SEND")
                } else if tx.received > tx.sent {
                    print("   Type: 📥 RECEIVE")
                } else {
                    print("   Type: ⚖️ NEUTRAL")
                }
            }
            print("\n================================")
            print("📊 Total transactions retrieved: \(transactions.count)")
            
            
            // Sort by confirmation time (most recent first), unconfirmed at top
            let sortedTransactions = transactions.sorted { tx1, tx2 in
                // Unconfirmed transactions first
                if tx1.confirmationTime == nil && tx2.confirmationTime != nil {
                    return true
                }
                if tx1.confirmationTime != nil && tx2.confirmationTime == nil {
                    return false
                }
                
                // Both confirmed or both unconfirmed - sort by timestamp/height
                if let time1 = tx1.confirmationTime?.timestamp,
                   let time2 = tx2.confirmationTime?.timestamp {
                    return time1 > time2
                }
                
                return false
            }
            
            // Log summary
            let confirmed = sortedTransactions.filter { $0.isConfirmed }.count
            let pending = sortedTransactions.count - confirmed
            print("   Confirmed: \(confirmed), Pending: \(pending)")
            
            return sortedTransactions
            
        } catch {
            print("❌ Error fetching onchain transactions: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get onchain transactions: \(error.localizedDescription)")
        }
    }
    
    func getMovements() async throws -> String {
        // Get transaction history/movements
        
        if isPreview {
            return "[]"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Fetching wallet movements via FFI...")
        
        do {
            // Call FFI movements method
            let movements = try await wallet.history()
            
            print("✅ Retrieved \(movements.count) movements")
            print("📋 Movements: \(movements)")
            
            // Log movements with exited VTXOs for debugging
            let movementsWithExits = movements.filter { !$0.exitedVtxoIds.isEmpty }
            if !movementsWithExits.isEmpty {
                print("⚠️ Found \(movementsWithExits.count) movement(s) with exited VTXOs:")
                for movement in movementsWithExits {
                    print("   • Movement \(movement.id) (\(movement.subsystemName)): \(movement.exitedVtxoIds.count) exited VTXO(s)")
                }
            }
            
            // Convert Movement array to JSON string
            let jsonEncoder = JSONEncoder()
            jsonEncoder.dateEncodingStrategy = .iso8601
            jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            // Convert FFI Movement to a JSON-serializable structure
            let movementDicts: [[String: Any]] = movements.map { movement in
                var dict: [String: Any] = [
                    "id": movement.id,
                    "status": movement.status,
                    "subsystem_name": movement.subsystemName,
                    "subsystem_kind": movement.subsystemKind,
                    "metadata_json": movement.metadataJson,
                    "intended_balance_sats": movement.intendedBalanceSats,
                    "effective_balance_sats": movement.effectiveBalanceSats,
                    "offchain_fee_sats": movement.offchainFeeSats,
                    "sent_to_addresses": movement.sentToAddresses,
                    "received_on_addresses": movement.receivedOnAddresses,
                    "input_vtxo_ids": movement.inputVtxoIds,
                    "output_vtxo_ids": movement.outputVtxoIds,
                    "exited_vtxo_ids": movement.exitedVtxoIds,
                    "created_at": movement.createdAt,
                    "updated_at": movement.updatedAt
                ]
                
                // Only include completed_at if it's not nil
                if let completedAt = movement.completedAt {
                    dict["completed_at"] = completedAt
                }
                
                return dict
            }
            
            // Convert to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: movementDicts, options: [.prettyPrinted, .sortedKeys])
            
            // Convert to string
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw BarkWalletFFIError.configurationError("Failed to encode movements as JSON string")
            }
            
            print("✅ Movements converted to JSON")
            
            return jsonString
            
        } catch let error as BarkError {
            print("❌ FFI Error fetching movements: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get movements: \(error.localizedDescription)")
        } catch {
            print("❌ Error fetching movements: \(error)")
            throw error
        }
    }
    
    // MARK: - Send Operations
    
    // Three types of send operations:
    // 1. send() - Ark-to-Ark payment (off-chain, uses VTXOs)
    // 2. sendToOnchain() - Offboard Ark funds to Bitcoin address (via round)
    // 3. sendOnchain() - Direct Bitcoin transaction (uses onchain balance)
    
    func send(to address: String, amount: Int) async throws -> String {
        // Preview mode handling
        if isPreview {
            return "Mock: Sent \(amount) sats to \(address) (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        // Validate amount
        guard amount > 0 else {
            throw BarkWalletFFIError.configurationError("Amount must be greater than 0")
        }
        
        // Convert Int to UInt64 for FFI
        let amountSats = UInt64(amount)
        
        print("🔧 Sending \(amount) sats to \(address) via FFI...")
        print("   Network: \(networkConfig.name)")
        
        do {
            // Call FFI sendArkoorPayment method
            let roundId = try await wallet.sendArkoorPayment(arkAddress: address, amountSats: amountSats)
            
            print("✅ Payment sent successfully")
            print("   Round ID: \(roundId)")
            print("   Amount: \(amount) sats")
            print("   To: \(address)")
            
            // Return success message with round ID
            return "Successfully sent \(amount) sats to \(address). Round ID: \(roundId)"
            
        } catch let error as BarkError {
            print("❌ FFI Error sending payment: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to send payment: \(error.localizedDescription)")
        } catch {
            print("❌ Error sending payment: \(error)")
            throw error
        }
    }
    
    func sendToOnchain(to address: String, amount: Int) async throws -> String {
        // This is an "offboard" operation in Ark terminology
        // It sends Ark funds to a Bitcoin onchain address
        
        if isPreview {
            return "Mock: Sent \(amount) sats to onchain address \(address) (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        // Validate amount
        guard amount > 0 else {
            throw BarkWalletFFIError.configurationError("Amount must be greater than 0")
        }
        
        print("🔧 Offboarding \(amount) sats to onchain address via FFI...")
        print("   Network: \(networkConfig.name)")
        print("   Destination: \(address)")
        print("   Amount: \(amount) sats")
        
        // Convert Int to UInt64 for FFI
        let amountSats = UInt64(amount)
        
        do {
            // Call FFI sendRoundOnchainPayment method
            // This sends a specific amount during a round (better than offboarding all)
            //let roundId = try wallet.sendRoundOnchainPayment(address: address, amountSats: amountSats)
            let roundState = try await wallet.sendOnchain(address: address, amountSats: amountSats)
            
            // TODO: See if sendRoundOnchainPayment still exists under a different name in the new bindings repo
            //let result = try await sendOnchain(to: address, amount: Int(amountSats), feeRateSatPerVb: nil)
            
            print("✅ Onchain payment initiated")
            print("   Round state: \(roundState)")
            print("   Destination: \(address)")
            print("   Amount: \(amount) sats")
            //print("   Result: \(result)")
            
            // Return result with round ID
            //return "Onchain payment initiated. Round ID: \(roundId)"
            return roundState
        } catch let error as BarkError {
            print("❌ FFI Error sending onchain payment: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to send onchain payment: \(error.localizedDescription)")
        } catch {
            print("❌ Error sending onchain payment: \(error)")
            throw error
        }
    }
    
    func sendOnchain(to address: String, amount: Int, feeRateSatPerVb: UInt64? = nil) async throws -> String {
        // This is a direct onchain transaction (not offboarding Ark funds)
        // Sends Bitcoin from the wallet's onchain balance to a Bitcoin address
        
        if isPreview {
            return "Mock: Sent \(amount) sats onchain to \(address). Txid: abc123..."
        }
        
        // Ensure onchain wallet is initialized
        guard let onchainWallet = onchainWallet else {
            throw BarkWalletFFIError.configurationError("Onchain wallet not initialized")
        }
        
        // Validate amount
        guard amount > 0 else {
            throw BarkWalletFFIError.configurationError("Amount must be greater than 0")
        }
        
        // Convert Int to UInt64
        let amountSats = UInt64(amount)
        
        // Use provided fee rate or default to 10 sat/vB
        let feeRate = feeRateSatPerVb ?? 10
        
        print("🔧 Sending onchain Bitcoin transaction via built-in wallet...")
        print("   Network: \(networkConfig.name)")
        print("   Destination: \(address)")
        print("   Amount: \(amount) sats")
        print("   Fee rate: \(feeRate) sat/vB \(feeRateSatPerVb == nil ? "(default)" : "(custom)")")
        
        do {
            // Use built-in OnchainWallet to send transaction
            let txid = try await onchainWallet.send(
                address: address,
                amountSats: amountSats,
                feeRateSatPerVb: feeRate
            )
            
            print("✅ Onchain transaction sent successfully")
            print("   Txid: \(txid)")
            print("   Amount: \(amount) sats")
            print("   Fee rate: \(feeRate) sat/vB")
            print("   Destination: \(address)")
            
            return "Successfully sent \(amount) sats onchain. Txid: \(txid)"
            
        } catch {
            print("❌ Error sending onchain transaction: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to send onchain transaction: \(error.localizedDescription)")
        }
    }
    
    func sendWithSafetyCheck(to address: String, amount: Int) async throws -> String {
        try validateMainnetOperation()
        
        if networkConfig.isMainnet {
            print("🔴 MAINNET SEND: Sending \(amount) sats to \(address)")
        } else {
            print("🔵 \(networkConfig.networkType.uppercased()) SEND: Sending \(amount) sats to \(address)")
        }
        
        return try await send(to: address, amount: amount)
    }
    
    func sendOnchainWithSafetyCheck(to address: String, amount: Int, feeRateSatPerVb: UInt64? = nil) async throws -> String {
        try validateMainnetOperation()
        
        if networkConfig.isMainnet {
            print("🔴 MAINNET ONCHAIN SEND: Sending \(amount) sats to \(address)")
        } else {
            print("🔵 \(networkConfig.networkType.uppercased()) ONCHAIN SEND: Sending \(amount) sats to \(address)")
        }
        
        return try await sendOnchain(to: address, amount: amount, feeRateSatPerVb: feeRateSatPerVb)
    }
}
