//
//  TransactionService.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/23/25.
//

import Foundation
import SwiftData

// MARK: - JSON Parsing Models for Movements (Updated for New API)

/*
 MOVEMENT PARSING NOTES (Updated January 2026):
 - Movement schema with explicit subsystem_kind and subsystem_name
 - Transaction type determined from subsystem (not inferred from balance)
 - Timestamps are ISO 8601 with timezone
 - Status values: "pending", "successful", "failed", "canceled"
 - Tracks exited_vtxo_ids for VTXOs forced into unilateral exit
 
 CRITICAL LIMITATION:
 - API returns only ADDRESSES without AMOUNTS for sent_to_addresses!
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

struct MovementData: Codable {
    let id: Int
    let status: String                          // "Pending", "Finished", "Failed", "Cancelled"
    let subsystemKind: String                   // "send" | "receive" | other subsystem-specific
    let subsystemName: String                   // e.g., "bark.arkoor", "bark.lightning"
    let intendedBalanceSat: Int64
    let effectiveBalanceSat: Int64              // Negative for sends, positive for receives
    let offchainFeeSat: Int64                   // Renamed from "fees"
    let sentToAddresses: [String]               // Just addresses, no amounts (WARNING: amounts lost!)
    let receivedOnAddresses: [String]           // Just addresses, no amounts
    let inputVtxoIds: [String]                  // Replaces old "spends" (just IDs now)
    let outputVtxoIds: [String]                 // Replaces old "receives" (just IDs now)
    let exitedVtxoIds: [String]                 // VTXOs forced into unilateral exit (empty array if none)
    let metadataJson: String                    // JSON string, not parsed object
    let createdAt: String                       // ISO 8601 format
    let updatedAt: String
    let completedAt: String?                    // Nil if not yet completed
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case subsystemKind = "subsystem_kind"
        case subsystemName = "subsystem_name"
        case intendedBalanceSat = "intended_balance_sats"
        case effectiveBalanceSat = "effective_balance_sats"
        case offchainFeeSat = "offchain_fee_sats"
        case sentToAddresses = "sent_to_addresses"
        case receivedOnAddresses = "received_on_addresses"
        case inputVtxoIds = "input_vtxo_ids"
        case outputVtxoIds = "output_vtxo_ids"
        case exitedVtxoIds = "exited_vtxo_ids"
        case metadataJson = "metadata_json"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
    }
    
    // MARK: - Computed Properties
    
    /// Whether this movement has VTXOs that were forced into unilateral exit
    /// This typically happens with expired HTLC VTXOs during Lightning payments
    var hasExitedVtxos: Bool {
        !exitedVtxoIds.isEmpty
    }
    
    /// Movement category based on subsystem
    var category: MovementCategory {
        MovementCategory.from(subsystemName: subsystemName, subsystemKind: subsystemKind)
    }
    
    /// Parsed metadata (lazily computed)
    var metadata: MovementMetadata? {
        MovementMetadataParser.parse(json: metadataJson, subsystemName: subsystemName)
    }
    
    /// Destination objects from sent addresses with payment method detection
    var destinations: [MovementDestination] {
        sentToAddresses.map { MovementDestination.fromAddress($0) }
    }
    
    /// Source objects from received addresses with payment method detection
    var sources: [MovementDestination] {
        receivedOnAddresses.map { MovementDestination.fromAddress($0) }
    }
    
    /// Total onchain fees (if available in metadata)
    var onchainFeeSat: Int? {
        (metadata as? BoardMetadata)?.onchainFeeSat
    }
    
    /// Payment hash (if Lightning payment)
    var paymentHash: String? {
        (metadata as? LightningMetadata)?.paymentHash
    }
    
    /// HTLC VTXO IDs (if Lightning payment)
    var htlcVtxoIds: [String] {
        (metadata as? LightningMetadata)?.htlcVtxos ?? []
    }
    
    /// Number of HTLC VTXOs
    var htlcVtxoCount: Int {
        htlcVtxoIds.count
    }
    
    /// Round funding transaction ID (if round operation)
    var fundingTxid: String? {
        (metadata as? RoundMetadata)?.fundingTxid
    }
    
    /// Whether this movement should be shown in history by default
    var showInHistoryByDefault: Bool {
        category.showInHistoryByDefault
    }
}

// MARK: - Transaction Service

@MainActor
@Observable
class TransactionService {
    var error: String?
    var isRefreshing: Bool = false
    var hasLoadedTransactions: Bool = false
    
    private let wallet: BarkWalletProtocol
    private let taskManager: TaskDeduplicationManager
    private var modelContext: ModelContext?
    private var addressService: AddressService?
    
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
    
    /// Get raw transactions data from wallet
    func getTransactions() async throws -> String {
        return try await wallet.getMovements()
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
                        
                        if existingTransaction.hasExitedVtxos != transactionData.hasExitedVtxos {
                            existingTransaction.hasExitedVtxos = transactionData.hasExitedVtxos
                            hasChanges = true
                        }
                        
                        if existingTransaction.htlcVtxoCount != transactionData.htlcVtxoCount {
                            existingTransaction.htlcVtxoCount = transactionData.htlcVtxoCount
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
                            paymentMethodType: transactionData.paymentMethod?.displayType,
                            paymentHash: transactionData.paymentHash,
                            onchainFeeSat: transactionData.onchainFeeSat,
                            fundingTxid: transactionData.fundingTxid,
                            hasExitedVtxos: transactionData.hasExitedVtxos,
                            htlcVtxoCount: transactionData.htlcVtxoCount
                        )
                        modelContext.insert(newTransaction)
                        
                        // ✅ Phase 3: Link transaction to address
                        await linkTransactionToAddress(newTransaction)
                        
                        // Add to dictionary to prevent duplicates within this batch
                        existingTransactionDict[transactionData.txid] = newTransaction
                        
                        upsertedCount += 1
                        
                        // Auto-assign contact if transaction has an address
                        if let address = transactionData.address {
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
    
    // MARK: - Address Linking (Phase 3)
    
    /// Link a transaction to its address for internal transfer detection
    /// - Parameter transaction: The transaction to link
    private func linkTransactionToAddress(_ transaction: PersistentTransaction) async {
        guard let addressService = addressService else {
            // AddressService not available yet - this is OK during initialization
            return
        }
        
        guard let address = transaction.address else {
            // No address on transaction - this is normal for some transaction types
            return
        }
        
        // Handle received transactions: mark address as used
        if transaction.type == "received" {
            await addressService.markAddressAsUsed(
                address: address,
                transaction: transaction
            )
            
            // Link the address to transaction
            if let persistentAddr = await addressService.getAddressByString(address) {
                transaction.receivingAddress = persistentAddr
                print("✅ Linked received transaction \(transaction.txid) to address \(address)")
            }
        }
        
        // Handle sent transactions: check if internal transfer
        if transaction.type == "sent" {
            let isOwn = await addressService.isOwnAddress(address)
            if isOwn {
                // This is an internal transfer!
                transaction.subsystemCategory = "internal_transfer"
                
                // Link to receiving address
                if let persistentAddr = await addressService.getAddressByString(address) {
                    transaction.receivingAddress = persistentAddr
                    print("🔄 Detected internal transfer: \(transaction.txid) to \(address)")
                }
            }
        }
    }
    
    // MARK: - Auto-Assignment
    
    /// Automatically assign a contact to a transaction if the address matches any contact's addresses
    /// - Parameters:
    ///   - address: The transaction address to match against contact addresses
    ///   - transaction: The transaction to assign the contact to
    ///   - modelContext: The SwiftData model context for database operations
    /// - Returns: True if a contact was auto-assigned, false otherwise
    private func autoAssignContactForAddress(_ address: String, transaction: PersistentTransaction, modelContext: ModelContext) async -> Bool {
        // Normalize the address for case-insensitive comparison
        let normalizedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        do {
            // Query for any contact address that matches this normalized address
            let addressDescriptor = FetchDescriptor<PersistentContactAddress>(
                predicate: #Predicate<PersistentContactAddress> { 
                    $0.normalizedAddress == normalizedAddress 
                }
            )
            let matchingAddresses = try modelContext.fetch(addressDescriptor)
            
            guard let matchingAddress = matchingAddresses.first else {
                // No contact found with this address - this is normal, skip silently
                return false
            }
            
            // Check if multiple contacts have this address (unusual but possible)
            if matchingAddresses.count > 1 {
                let contactNames = matchingAddresses.compactMap { $0.contact?.cachedName }.joined(separator: ", ")
                print("⚠️ Multiple contacts found for address \(address): [\(contactNames)], using first match")
            }
            
            // Get the associated contact
            guard let contact = matchingAddress.contact else {
                print("⚠️ Contact address found but contact relationship is nil for address: \(address)")
                return false
            }
            
            // Check if this transaction already has this contact assigned (shouldn't happen for new transactions, but defensive)
            let contactAssignments = transaction.contactAssignments ?? []
            let alreadyAssigned = contactAssignments.contains { 
                $0.contact?.id == contact.id 
            }
            
            if alreadyAssigned {
                // Already assigned, skip
                return false
            }
            
            // Create the auto-assignment
            let assignment = TransactionContactAssignment(contact: contact, transaction: transaction)
            modelContext.insert(assignment)
            
            // Update contact's timestamp
            contact.touch()
            
            print("✅ Auto-assigned contact '\(contact.cachedName)' to transaction \(transaction.txid) based on address \(address)")
            
            return true
            
        } catch {
            // Log but don't fail the transaction insertion
            print("⚠️ Failed to check auto-assignment for address \(address): \(error)")
            return false
        }
    }
    
    // MARK: - Tag Assignment Preservation
    
    /// Cache existing tag assignments for preservation during updates
    /// This method is primarily for logging and verification - SwiftData relationships handle preservation automatically
    private func cacheExistingTagAssignments(from transactions: [PersistentTransaction]) async -> [String: [TransactionTagAssignment]] {
        var cache: [String: [TransactionTagAssignment]] = [:]
        
        for transaction in transactions {
            let tagAssignments = transaction.tagAssignments ?? []
            if !tagAssignments.isEmpty {
                cache[transaction.txid] = tagAssignments
            }
        }
        
        let totalTagAssignments = cache.values.flatMap { $0 }.count
        if totalTagAssignments > 0 {
            print("🏷️ Found \(totalTagAssignments) existing tag assignments across \(cache.count) transactions")
        }
        
        return cache
    }
    
    // MARK: - Transaction Parsing
    
    private struct TransactionData {
        let txid: String
        let movementId: Int
        let recipientIndex: Int?
        let type: TransactionTypeEnum
        let amount: Int
        let date: Date
        let status: TransactionStatusEnum
        let address: String?
        let fees: Int?  // Proportionally allocated fees for this transaction
        
        // ✅ Enhanced metadata
        let category: MovementCategory
        let paymentMethod: PaymentMethod?
        let paymentHash: String?
        let onchainFeeSat: Int?
        let fundingTxid: String?
        let hasExitedVtxos: Bool
        let htlcVtxoCount: Int
        
        /// Whether this transaction should be shown in history by default
        var shouldShowInHistory: Bool {
            category.showInHistoryByDefault
        }
    }
    
    /// Calculate proportional fee allocation for multi-destination transactions
    /// - Parameters:
    ///   - totalFees: Total fees for the movement
    ///   - recipientAmount: Amount for this specific destination
    ///   - totalAmount: Total amount sent across all destinations
    ///   - recipientIndex: Index of this destination (for rounding adjustments)
    ///   - totalRecipients: Total number of destinations
    /// - Returns: Proportionally allocated fee for this destination
    private func calculateProportionalFee(
        totalFees: Int,
        recipientAmount: Int,
        totalAmount: Int,
        recipientIndex: Int,
        totalRecipients: Int
    ) -> Int {
        guard totalAmount > 0, totalRecipients > 0 else {
            return 0
        }
        
        // Calculate proportion of total amount
        let proportion = Double(recipientAmount) / Double(totalAmount)
        let proportionalFee = Int(round(Double(totalFees) * proportion))
        
        return proportionalFee
    }
    
    private func parseMovementToTransactions(_ movement: MovementData) async -> [TransactionData] {
        let parsedDate = parseDate(movement.completedAt ?? movement.createdAt)
        let status = mapMovementStatus(movement.status)
        let category = movement.category
        
        // Use category-aware parsing
        return parseMovementWithCategory(
            movement,
            category: category,
            date: parsedDate,
            status: status
        )
    }
    
    /// Parse movement using category-aware logic
    private func parseMovementWithCategory(
        _ movement: MovementData,
        category: MovementCategory,
        date: Date,
        status: TransactionStatusEnum
    ) -> [TransactionData] {
        
        // Handle self-transfer operations (boarding, exit, offboarding)
        if category == .boarding || category == .exit || category == .offboarding {
            return parseTransferOperation(movement, category: category, date: date, status: status)
        }
        
        // Handle send operations
        if movement.subsystemKind == "send" || category == .lightningSend || category == .onchainSend {
            return parseSendOperation(movement, category: category, date: date, status: status)
        }
        
        // Handle receive operations
        if movement.subsystemKind == "receive" || category == .lightningReceive {
            return parseReceiveOperation(movement, category: category, date: date, status: status)
        }
        
        // Other operations (refresh, unknown)
        return parseOtherOperation(movement, category: category, date: date, status: status)
    }
    
    /// Parse send operations (send, lightning send, offboard, onchain send)
    private func parseSendOperation(
        _ movement: MovementData,
        category: MovementCategory,
        date: Date,
        status: TransactionStatusEnum
    ) -> [TransactionData] {
        
        let destinations = movement.destinations
        
        guard !destinations.isEmpty else {
            // No destinations - create single transaction with total amount
            return [createTransactionData(
                movement: movement,
                destination: nil,
                recipientIndex: nil,
                type: .sent,
                date: date,
                status: status,
                category: category
            )]
        }
        
        if destinations.count == 1 {
            // Single destination
            return [createTransactionData(
                movement: movement,
                destination: destinations[0],
                recipientIndex: nil,
                type: .sent,
                date: date,
                status: status,
                category: category
            )]
        } else {
            // Multiple destinations - we don't have per-destination amounts
            print("⚠️ Movement \(movement.id) has \(destinations.count) destinations but no per-destination amounts")
            print("   Destinations: \(destinations.map { $0.paymentMethod.displayType }.joined(separator: ", "))")
            
            // Create one transaction showing first destination
            return [createTransactionData(
                movement: movement,
                destination: destinations[0],
                recipientIndex: nil,
                type: .sent,
                date: date,
                status: status,
                category: category
            )]
        }
    }
    
    /// Parse receive operations (receive, lightning receive)
    private func parseReceiveOperation(
        _ movement: MovementData,
        category: MovementCategory,
        date: Date,
        status: TransactionStatusEnum
    ) -> [TransactionData] {
        
        let sources = movement.sources
        let source = sources.first  // May be nil
        
        return [createTransactionData(
            movement: movement,
            destination: source,
            recipientIndex: nil,
            type: .received,
            date: date,
            status: status,
            category: category
        )]
    }
    
    /// Parse transfer operations (boarding, exit, offboarding)
    /// These are self-transfers between the user's onchain and Ark accounts
    private func parseTransferOperation(
        _ movement: MovementData,
        category: MovementCategory,
        date: Date,
        status: TransactionStatusEnum
    ) -> [TransactionData] {
        
        let destinations = movement.destinations
        let destination = destinations.first  // May be nil for boarding (no destination address)
        
        return [createTransactionData(
            movement: movement,
            destination: destination,
            recipientIndex: nil,
            type: .transfer,
            date: date,
            status: status,
            category: category
        )]
    }
    
    /// Parse other operations (exit, refresh, etc.)
    private func parseOtherOperation(
        _ movement: MovementData,
        category: MovementCategory,
        date: Date,
        status: TransactionStatusEnum
    ) -> [TransactionData] {
        
        // Determine transaction type based on balance
        let type: TransactionTypeEnum
        if movement.effectiveBalanceSat < 0 {
            type = .sent
        } else if movement.effectiveBalanceSat > 0 {
            type = .received
        } else {
            // Zero balance (e.g., refresh) - treat as pending for now
            type = .pending
        }
        
        let destinations = movement.destinations
        let destination = destinations.first  // May be nil
        
        return [createTransactionData(
            movement: movement,
            destination: destination,
            recipientIndex: nil,
            type: type,
            date: date,
            status: status,
            category: category
        )]
    }
    
    /// Create a TransactionData object with all metadata
    private func createTransactionData(
        movement: MovementData,
        destination: MovementDestination?,
        recipientIndex: Int?,
        type: TransactionTypeEnum,
        date: Date,
        status: TransactionStatusEnum,
        category: MovementCategory
    ) -> TransactionData {
        
        let amount: Int
        let fees: Int?
        
        // Determine amount and fees based on type
        if type == .received {
            amount = Int(movement.effectiveBalanceSat)
            fees = nil  // Receiver doesn't pay offchain fees
        } else {
            amount = Int(abs(movement.effectiveBalanceSat))
            fees = Int(movement.offchainFeeSat)
        }
        
        return TransactionData(
            txid: "movement_\(movement.id)",
            movementId: movement.id,
            recipientIndex: recipientIndex,
            type: type,
            amount: amount,
            date: date,
            status: status,
            address: destination?.address,
            fees: fees,
            category: category,
            paymentMethod: destination?.paymentMethod,
            paymentHash: movement.paymentHash,
            onchainFeeSat: movement.onchainFeeSat,
            fundingTxid: movement.fundingTxid,
            hasExitedVtxos: movement.hasExitedVtxos,
            htlcVtxoCount: movement.htlcVtxoCount
        )
    }
    
    /// Map movement status string to TransactionStatusEnum
    private func mapMovementStatus(_ status: String) -> TransactionStatusEnum {
        switch status.lowercased() {
        case "successful":
            return .confirmed
        case "pending":
            return .pending
        case "failed", "cancelled":
            return .failed
        default:
            print("⚠️ Unknown movement status '\(status)', defaulting to pending")
            return .pending
        }
    }
    
    private func parseDate(_ dateString: String) -> Date {
        // Try ISO 8601 format first (new API format)
        // Example: "2025-12-05T11:17:01.044108+01:00"
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Fallback to old format for backward compatibility
        // Example: "2025-10-29 14:17:11.193"
        let legacyFormatter = DateFormatter()
        legacyFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        legacyFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = legacyFormatter.date(from: dateString) {
            return date
        }
        
        // If both fail, try without fractional seconds
        legacyFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = legacyFormatter.date(from: dateString) {
            return date
        }
        
        // Last resort fallback to current date
        print("⚠️ Failed to parse date: \(dateString)")
        return Date()
    }
    
    // MARK: - Helper Methods
    
    /// Convert TransactionStatusEnum to String representation
    private static func stringValue(for status: TransactionStatusEnum) -> String {
        switch status {
        case .confirmed: return "confirmed"
        case .pending: return "pending"
        case .failed: return "failed"
        }
    }
    
    /// Convert TransactionTypeEnum to String representation
    private static func stringValue(for type: TransactionTypeEnum) -> String {
        switch type {
        case .sent: return "sent"
        case .received: return "received"
        case .transfer: return "transfer"
        case .pending: return "pending"
        }
    }
    
    // MARK: - Utility Methods
    
    /// Clear all persisted transactions from SwiftData
    func clearTransactionModels() async {
        guard let modelContext = modelContext else {
            print("⚠️ No model context available for clearing transactions")
            return
        }
        
        do {
            // Fetch all persisted transactions
            let descriptor = FetchDescriptor<PersistentTransaction>()
            let persistentTransactions = try modelContext.fetch(descriptor)
            
            // Count tagged transactions before deletion
            let taggedTransactionsCount = persistentTransactions.filter { !(($0.tagAssignments ?? []).isEmpty) }.count
            let totalTagAssignments = persistentTransactions.flatMap { $0.tagAssignments ?? [] }.count
            
            // Delete all transactions (cascade will handle tag assignments)
            for transaction in persistentTransactions {
                modelContext.delete(transaction)
            }
            
            // Save changes
            try modelContext.save()
            
            // Reset loaded state
            hasLoadedTransactions = false
            
            print("🗑️ Cleared \(persistentTransactions.count) persisted transactions")
            if totalTagAssignments > 0 {
                print("🏷️ Also cleared \(totalTagAssignments) tag assignments from \(taggedTransactionsCount) tagged transactions")
            }
            
        } catch {
            print("❌ Failed to clear persisted transactions: \(error)")
        }
    }
    
    /// Clean up orphaned transactions that no longer exist on the server but have been locally tagged
    /// This is a manual cleanup method that can be called when needed
    func cleanupOrphanedTaggedTransactions() async {
        guard let modelContext = modelContext else {
            print("⚠️ No model context available for cleaning orphaned transactions")
            return
        }
        
        do {
            // Get all transactions with tags
            let taggedDescriptor = FetchDescriptor<PersistentTransaction>(
                predicate: #Predicate { transaction in
                    transaction.tagAssignments != nil
                }
            )
            let taggedTransactions = try modelContext.fetch(taggedDescriptor)
            
            // Filter for those that actually have tags (since relationship is optional)
            let actuallyTaggedTransactions = taggedTransactions.filter { !(($0.tagAssignments ?? []).isEmpty) }
            
            if !actuallyTaggedTransactions.isEmpty {
                print("🏷️ Found \(actuallyTaggedTransactions.count) tagged transactions")
                
                // Refresh from server to identify which ones still exist
                let serverOutput = try await wallet.getMovements()
                let serverTxids = await getServerTransactionIds(from: serverOutput)
                
                let orphanedTaggedTransactions = actuallyTaggedTransactions.filter { !serverTxids.contains($0.txid) }
                
                if !orphanedTaggedTransactions.isEmpty {
                    let totalOrphanedTags = orphanedTaggedTransactions.flatMap { $0.tagAssignments ?? [] }.count
                    
                    print("🚨 Found \(orphanedTaggedTransactions.count) orphaned tagged transactions with \(totalOrphanedTags) total tag assignments")
                    print("🚨 These transactions no longer exist on the server but have local tags")
                    
                    // Log details for manual review
                    for transaction in orphanedTaggedTransactions {
                        let tagNames = transaction.associatedTags.map { $0.displayName }.joined(separator: ", ")
                        let transactionModel = TransactionModel(from: transaction)
                        print("   • \(transaction.txid): \(transactionModel.formattedAmount) [\(tagNames)]")
                    }
                    
                    // Note: We don't automatically delete these - that's a policy decision for the app
                    // The user might want to keep them for historical tracking
                }
            }
            
        } catch {
            print("❌ Failed to cleanup orphaned tagged transactions: \(error)")
        }
    }
    
    /// Extract transaction IDs from server data for comparison
    private func getServerTransactionIds(from output: String) async -> Set<String> {
        guard let jsonData = output.data(using: .utf8) else {
            return Set()
        }
        
        do {
            let movements = try JSONDecoder().decode([MovementData].self, from: jsonData)
            let transactionDataList = await movements.asyncFlatMap { movement in
                await parseMovementToTransactions(movement)
            }
            return Set(transactionDataList.map { $0.txid })
        } catch {
            print("❌ Failed to parse server transaction IDs: \(error)")
            return Set()
        }
    }
    
    // MARK: - State Management
    
    /// Clear error state
    func clearError() {
        error = nil
    }
    
    // MARK: - Notes Management
    
    /// Update notes for a transaction
    /// - Parameters:
    ///   - txid: The transaction ID to update
    ///   - notes: The notes text to set (nil to clear notes, empty strings are converted to nil)
    /// - Throws: TransactionServiceError if validation fails or transaction not found
    func updateNotes(for txid: String, notes: String?) async throws {
        guard let modelContext = modelContext else {
            throw TransactionServiceError.noModelContext
        }
        
        // Validate and sanitize notes
        let sanitizedNotes = try Self.validateAndSanitizeNotes(notes)
        
        // Find the transaction
        let descriptor = FetchDescriptor<PersistentTransaction>(
            predicate: #Predicate<PersistentTransaction> { transaction in
                transaction.txid == txid
            }
        )
        
        let transactions = try modelContext.fetch(descriptor)
        
        guard let transaction = transactions.first else {
            throw TransactionServiceError.transactionNotFound(txid: txid)
        }
        
        // Update the notes
        transaction.notes = sanitizedNotes
        
        // Save changes
        try modelContext.save()
        
        if let sanitizedNotes = sanitizedNotes {
            print("📝 Updated notes for transaction \(txid): \"\(sanitizedNotes.prefix(50))...\"")
        } else {
            print("📝 Cleared notes for transaction \(txid)")
        }
    }
    
    /// Search transactions by notes content
    /// - Parameter query: The search query string
    /// - Returns: Array of transactions whose notes contain the query string (case-insensitive)
    func searchTransactionsByNotes(query: String) async throws -> [TransactionModel] {
        guard let modelContext = modelContext else {
            throw TransactionServiceError.noModelContext
        }
        
        // Normalize query for case-insensitive search
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !normalizedQuery.isEmpty else {
            return []
        }
        
        // Fetch all transactions with notes
        let descriptor = FetchDescriptor<PersistentTransaction>(
            predicate: #Predicate<PersistentTransaction> { transaction in
                transaction.notes != nil
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let transactions = try modelContext.fetch(descriptor)
        
        // Filter by query (case-insensitive)
        let matchingTransactions = transactions.filter { transaction in
            guard let notes = transaction.notes else { return false }
            return notes.lowercased().contains(normalizedQuery)
        }
        
        print("🔍 Found \(matchingTransactions.count) transactions matching notes query: \"\(query)\"")
        
        return matchingTransactions.map { TransactionModel(from: $0) }
    }
    
    /// Validate and sanitize notes text
    /// - Parameter notes: The raw notes text
    /// - Returns: Sanitized notes (nil if empty after trimming)
    /// - Throws: TransactionServiceError.notesTooLong if exceeds character limit
    private static func validateAndSanitizeNotes(_ notes: String?) throws -> String? {
        guard let notes = notes else {
            return nil
        }
        
        // Trim whitespace
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty after trimming? Return nil
        if trimmed.isEmpty {
            return nil
        }
        
        // Check character limit
        if trimmed.count > 1000 {
            throw TransactionServiceError.notesTooLong(count: trimmed.count, limit: 1000)
        }
        
        return trimmed
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
