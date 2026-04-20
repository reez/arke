//
//  TransactionService.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/23/25.
//

import Foundation
import SwiftData
import ArkeUI

// MARK: - JSON Parsing Models for Movements (Updated for New API)

/*
 MOVEMENT PARSING NOTES (Updated January 2026):
 - Movement schema with explicit subsystem_kind and subsystem_name
 - Transaction type determined from subsystem (not inferred from balance)
 - Timestamps are ISO 8601 with timezone
 - Status values: "pending", "successful", "failed", "canceled"
 - Tracks exited_vtxo_ids for VTXOs forced into unilateral exit
 
 ADDRESS OBJECT FORMAT:
 - sent_to_addresses and received_on_addresses contain JSON-encoded objects
 - Each address object has: {"type": "ark"|"bitcoin"|"lightning", "value": "address_string"}
 - The type field explicitly indicates the payment method (no heuristic detection needed!)
 - Still no per-destination amounts (must use effectiveBalanceSat for total)
 
 CRITICAL LIMITATION:
 - API returns addresses WITH TYPES but still WITHOUT AMOUNTS!
 - Cannot create per-recipient transaction breakdowns
 - Must use effectiveBalanceSat for total amount
 - Multi-recipient sends will show as single transaction with total amount
 
 OPEN QUESTIONS FOR FUTURE CONSIDERATION:
 1. When receiving from another Ark user peer-to-peer, will `receivedOnAddresses` contain their
    address, or will it be empty? This affects contact auto-assignment for receives.
 
 2. Are VTXO consolidation/split movements now hidden from the movements list, or do
    they appear with empty `sentToAddresses`/`receivedOnAddresses` arrays?
 
 3. Should we display `exitedVtxoIds` in the UI with warnings? These represent VTXOs that
    were forced into unilateral exit during this movement (e.g., expired HTLC).
 
 4. Should we parse and store the `metadata_json` field? It contains subsystem-specific info
    that might be useful for debugging or future features.
 
 5. Do we need to handle `input_vtxo_ids` and `output_vtxo_ids` for anything? They
    could be useful for VTXO-level transaction tracking in the future.
 
 6. Why doesn't the API provide per-destination amounts for multi-recipient sends?
    This makes it impossible to show detailed transaction breakdowns in the UI.
*/

/// Address object as returned by the API (JSON-encoded within the address arrays)
struct AddressObject: Codable {
    let type: String   // "ark", "bitcoin", "lightning", etc.
    let value: String  // The actual address/invoice/identifier
    
    /// Convert to PaymentMethod enum
    var paymentMethod: PaymentMethod {
        // Use the explicit type from the server instead of heuristic detection
        switch type.lowercased() {
        case "ark":
            return .ark(address: value)
        case "bitcoin":
            return .bitcoin(address: value)
        case "lightning":
            // Could be invoice, offer, or lightning address - use detection for subcategory
            if value.hasPrefix("lnbc") || value.hasPrefix("lntb") || value.hasPrefix("lnbcrt") {
                return .invoice(value: value)
            } else if value.hasPrefix("lno1") {
                return .offer(value: value)
            } else if value.contains("@") {
                return .lightningAddress(value: value)
            } else {
                return .unknown(value: value)
            }
        default:
            // Unknown type - fall back to heuristic detection
            return PaymentMethod.detect(from: value)
        }
    }
}

// MARK: - Transaction Service

@MainActor
@Observable
class TransactionService {
    var error: String?
    var isRefreshing: Bool = false
    var hasLoadedTransactions: Bool = false
    
    private let taskManager: TaskDeduplicationManager
    
    // Internal use by extensions only.
    var modelContext: ModelContext?
    var addressService: AddressService?
    let wallet: BarkWalletProtocol
    
    // MARK: - Computed Properties
    
    /// Get all transactions from SwiftData as UI models
    var transactions: [TransactionModel] {
        guard let modelContext = modelContext else {
            return []
        }
        
        do {
            let descriptor = FetchDescriptor<PersistentTransaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let persistentTransactions = try modelContext.fetch(descriptor)
            return persistentTransactions.map { TransactionModel(from: $0) }
        } catch {
            print("❌ Failed to fetch transactions: \(error)")
            return []
        }
    }
    
    init(wallet: BarkWalletProtocol, taskManager: TaskDeduplicationManager) {
        self.wallet = wallet
        self.taskManager = taskManager
    }
    
    /// Set the model context for SwiftData operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// Set the address service for address-transaction linking
    func setAddressService(_ service: AddressService?) {
        self.addressService = service
    }
    
    /// Refresh transactions with deduplication using upsert strategy
    func refreshTransactions() async {
        await taskManager.execute(key: "transactions") {
            await self.performRefreshTransactions()
        }
    }
    
    private func performRefreshTransactions() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            let output = try await wallet.getMovements()
            print("📋 Transactions output: \(output)")
            await upsertTransactionsFromServerData(output)
            hasLoadedTransactions = true
        } catch {
            print("❌ Failed to get transactions: \(error)")
            self.error = "Failed to get transactions: \(error)"
        }
    }
    
    /// Process a single movement from notification stream
    /// Converts single movement JSON to array format and processes through existing upsert pipeline
    func processSingleMovement(json: String) async {
        guard modelContext != nil else {
            print("🚨 [TransactionService] No model context available for processing movement")
            return
        }
        
        // Wrap single movement in array format expected by parser
        let wrappedJson = "[\(json)]"
        
        print("📩 [TransactionService] Processing single movement from notification")
        
        // Reuse existing upsert pipeline
        await upsertTransactionsFromServerData(wrappedJson)
        
        print("✅ [TransactionService] Processed single movement from notification")
    }
    
    // MARK: - Upsert Strategy (Insert or Update)
    
    /*
     Transaction ID Format:
     - All transactions: "movement_{id}"
     
     Note: Due to API limitation (addresses without amounts), we cannot create separate
     transactions for multi-destination sends. All movements map to a single transaction.
     
     Old format used "movement_{id}_recipient_{index}" for multi-recipient breakdowns,
     but this is no longer possible with the new API structure.
    */
    
    private func upsertTransactionsFromServerData(_ output: String) async {
        guard let modelContext = modelContext else {
            print("🚨 No model context available for upserting transactions")
            return
        }
        
        guard let jsonData = output.data(using: .utf8) else {
            print("❌ Failed to convert output to data")
            return
        }
        
        do {
            let movements = try JSONDecoder().decode([MovementData].self, from: jsonData)
            
            // Get existing transactions to check for updates/new ones
            let existingDescriptor = FetchDescriptor<PersistentTransaction>()
            let existingTransactions = try modelContext.fetch(existingDescriptor)
            
            // Build dictionary manually to handle duplicates (keep first occurrence)
            var existingTransactionDict: [String: PersistentTransaction] = [:]
            var duplicateCount = 0
            for transaction in existingTransactions {
                if existingTransactionDict[transaction.txid] != nil {
                    duplicateCount += 1
                    print("⚠️ Found duplicate txid in database: \(transaction.txid)")
                    // Delete the duplicate from the database
                    modelContext.delete(transaction)
                } else {
                    existingTransactionDict[transaction.txid] = transaction
                }
            }
            
            if duplicateCount > 0 {
                print("🗑️ Removed \(duplicateCount) duplicate transactions from database")
                try modelContext.save()
            }
            
            // Cache existing tag assignments for preservation during updates
            // let tagAssignmentCache = await cacheExistingTagAssignments(from: existingTransactions)
            
            var upsertedCount = 0
            var updatedCount = 0
            var preservedTagCount = 0
            var autoAssignedCount = 0
            
            for movement in movements {
                let movementTransactions = await parseMovementToTransactions(movement)
                
                // Debug: Check if movement produces multiple transactions
                if movementTransactions.count > 1 {
                    print("⚠️ Movement \(movement.id) produced \(movementTransactions.count) transactions")
                }
                
                for transactionData in movementTransactions {
                    // Check if this transaction already exists in the database OR was just inserted in this batch
                    if let existingTransaction = existingTransactionDict[transactionData.txid] {
                        // Update existing transaction if data has changed
                        var hasChanges = false
                        
                        if existingTransaction.amount != transactionData.amount {
                            existingTransaction.amount = transactionData.amount
                            hasChanges = true
                        }
                        
                        if existingTransaction.transactionStatus != transactionData.status {
                            existingTransaction.status = Self.stringValue(for: transactionData.status)
                            hasChanges = true
                        }
                        
                        if existingTransaction.transactionType != transactionData.type {
                            existingTransaction.type = Self.stringValue(for: transactionData.type)
                            hasChanges = true
                        }
                        
                        if existingTransaction.date != transactionData.date {
                            existingTransaction.date = transactionData.date
                            hasChanges = true
                        }
                        
                        if existingTransaction.address != transactionData.address {
                            existingTransaction.address = transactionData.address
                            hasChanges = true
                        }
                        
                        if existingTransaction.fees != transactionData.fees {
                            existingTransaction.fees = transactionData.fees
                            hasChanges = true
                        }
                        
                        // ✅ Update rich metadata fields
                        let newCategory = transactionData.category.rawValue
                        if existingTransaction.subsystemCategory != newCategory {
                            existingTransaction.subsystemCategory = newCategory
                            hasChanges = true
                        }
                        
                        if existingTransaction.subsystemName != transactionData.subsystemName {
                            existingTransaction.subsystemName = transactionData.subsystemName
                            hasChanges = true
                        }
                        
                        if existingTransaction.subsystemKind != transactionData.subsystemKind {
                            existingTransaction.subsystemKind = transactionData.subsystemKind
                            hasChanges = true
                        }
                        
                        let newPaymentMethodType = transactionData.paymentMethod?.displayType
                        if existingTransaction.paymentMethodType != newPaymentMethodType {
                            existingTransaction.paymentMethodType = newPaymentMethodType
                            hasChanges = true
                        }
                        
                        if existingTransaction.paymentHash != transactionData.paymentHash {
                            existingTransaction.paymentHash = transactionData.paymentHash
                            hasChanges = true
                        }
                        
                        if existingTransaction.onchainFeeSat != transactionData.onchainFeeSat {
                            existingTransaction.onchainFeeSat = transactionData.onchainFeeSat
                            hasChanges = true
                        }
                        
                        if existingTransaction.fundingTxid != transactionData.fundingTxid {
                            existingTransaction.fundingTxid = transactionData.fundingTxid
                            hasChanges = true
                        }
                        
                        // Update VTXO IDs
                        let newInputVtxoIdsJson = PersistentTransaction.encodeVtxoIds(transactionData.inputVtxoIds)
                        if existingTransaction.inputVtxoIdsJson != newInputVtxoIdsJson {
                            existingTransaction.inputVtxoIdsJson = newInputVtxoIdsJson
                            hasChanges = true
                        }
                        
                        let newOutputVtxoIdsJson = PersistentTransaction.encodeVtxoIds(transactionData.outputVtxoIds)
                        if existingTransaction.outputVtxoIdsJson != newOutputVtxoIdsJson {
                            existingTransaction.outputVtxoIdsJson = newOutputVtxoIdsJson
                            hasChanges = true
                        }
                        
                        let newExitedVtxoIdsJson = PersistentTransaction.encodeVtxoIds(transactionData.exitedVtxoIds)
                        if existingTransaction.exitedVtxoIdsJson != newExitedVtxoIdsJson {
                            existingTransaction.exitedVtxoIdsJson = newExitedVtxoIdsJson
                            hasChanges = true
                        }
                        
                        // Preserve existing tag assignments - they survive server updates
                        // No need to explicitly restore them as they're already attached to the existing transaction
                        // The SwiftData relationship will maintain the connections automatically
                        if !(existingTransaction.tagAssignments ?? []).isEmpty {
                            preservedTagCount += (existingTransaction.tagAssignments ?? []).count
                        }
                        
                        if hasChanges {
                            updatedCount += 1
                        }
                    } else {
                        // Insert new transaction
                        let newTransaction = PersistentTransaction(
                            txid: transactionData.txid,
                            movementId: transactionData.movementId,
                            recipientIndex: transactionData.recipientIndex,
                            type: transactionData.type,
                            amount: transactionData.amount,
                            date: transactionData.date,
                            status: transactionData.status,
                            address: transactionData.address,
                            fees: transactionData.fees,
                            // ✅ Rich metadata
                            subsystemCategory: transactionData.category.rawValue,
                            subsystemName: transactionData.subsystemName,
                            subsystemKind: transactionData.subsystemKind,
                            paymentMethodType: transactionData.paymentMethod?.displayType,
                            paymentHash: transactionData.paymentHash,
                            onchainFeeSat: transactionData.onchainFeeSat,
                            fundingTxid: transactionData.fundingTxid,
                            inputVtxoIds: transactionData.inputVtxoIds,
                            outputVtxoIds: transactionData.outputVtxoIds,
                            exitedVtxoIds: transactionData.exitedVtxoIds
                        )
                        modelContext.insert(newTransaction)
                        
                        // ✅ Phase 3: Link transaction to address
                        await linkTransactionToAddress(newTransaction)
                        
                        // Add to dictionary to prevent duplicates within this batch
                        existingTransactionDict[transactionData.txid] = newTransaction
                        
                        upsertedCount += 1
                        
                        // Auto-assign contact if transaction has an address
                        // Only for sent transactions - received_on_addresses are our own addresses, not the sender's
                        if let address = transactionData.address, transactionData.type == .sent {
                            let wasAutoAssigned = await autoAssignContactForAddress(address, transaction: newTransaction, modelContext: modelContext)
                            if wasAutoAssigned {
                                autoAssignedCount += 1
                            }
                        }
                    }
                }
            }
            
            // Handle orphaned transactions (exist locally but not in server data)
            let serverTxids = Set(await movements.asyncFlatMap { movement in
                await parseMovementToTransactions(movement).map { $0.txid }
            })
            
            let orphanedTransactions = existingTransactions.filter { !serverTxids.contains($0.txid) }
            var orphanedTagCount = 0
            
            for orphanedTransaction in orphanedTransactions {
                let tagAssignments = orphanedTransaction.tagAssignments ?? []
                if !tagAssignments.isEmpty {
                    orphanedTagCount += tagAssignments.count
                    print("⚠️ Transaction \(orphanedTransaction.txid) no longer exists on server but has \(tagAssignments.count) tag(s)")
                }
                // Note: We could choose to preserve orphaned tagged transactions or delete them
                // For now, we'll let them remain to preserve user tags until explicit cleanup
            }
            
            // Save changes
            try modelContext.save()
            
            print("💾 Successfully saved \(upsertedCount) new, \(updatedCount) updated transactions")
            if autoAssignedCount > 0 {
                print("🔗 Auto-assigned \(autoAssignedCount) transaction(s) to contacts based on address matching")
            }
            print("🏷️ Preserved \(preservedTagCount) tag assignments across updates")
            if orphanedTagCount > 0 {
                print("🏷️ Found \(orphanedTagCount) tag assignments on \(orphanedTransactions.count) orphaned transactions")
            }
            
        } catch {
            print("❌ Failed to upsert transactions: \(error)")
            self.error = "Failed to process transactions: \(error)"
        }
    }
    
    // MARK: - State Management
    
    /// Clear error state
    func clearError() {
        error = nil
    }
}

// MARK: - Transaction Service Errors

enum TransactionServiceError: LocalizedError {
    case noModelContext
    case transactionNotFound(txid: String)
    case notesTooLong(count: Int, limit: Int)
    
    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "No model context available for database operations"
        case .transactionNotFound(let txid):
            return "Transaction not found: \(txid)"
        case .notesTooLong(let count, let limit):
            return "Notes too long: \(count) characters (limit: \(limit))"
        }
    }
}

// MARK: - Collection Extension for Async Operations
extension Collection {
    /// Async version of flatMap for collections
    func asyncFlatMap<T>(_ transform: (Element) async throws -> [T]) async rethrows -> [T] {
        var result: [T] = []
        for element in self {
            let transformed = try await transform(element)
            result.append(contentsOf: transformed)
        }
        return result
    }
}

