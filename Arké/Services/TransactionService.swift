//
//  TransactionService.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/23/25.
//

import Foundation
import SwiftData

// MARK: - JSON Parsing Models for Movements

struct MovementData: Codable {
    let id: Int
    let fees: Int
    let spends: [TransactionOutput]
    let receives: [TransactionOutput]
    let recipients: [RecipientData]
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, fees, spends, receives, recipients
        case createdAt = "created_at"
    }
}

struct RecipientData: Codable {
    let recipient: String
    let amountSat: Int
    
    enum CodingKeys: String, CodingKey {
        case recipient
        case amountSat = "amount_sat"
    }
}

struct TransactionOutput: Codable {
    let id: String
    let amountSat: Int
    let policyType: String?
    let userPubkey: String?
    let serverPubkey: String?
    let expiryHeight: Int?
    let exitDelta: Int?
    let chainAnchor: String?
    let exitDepth: Int?
    let arkoorDepth: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case amountSat = "amount_sat"
        case policyType = "policy_type"
        case userPubkey = "user_pubkey"
        case serverPubkey = "server_pubkey"
        case expiryHeight = "expiry_height"
        case exitDelta = "exit_delta"
        case chainAnchor = "chain_anchor"
        case exitDepth = "exit_depth"
        case arkoorDepth = "arkoor_depth"
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
            let existingTransactionDict = Dictionary(uniqueKeysWithValues: existingTransactions.map { ($0.txid, $0) })
            
            // Cache existing tag assignments for preservation during updates
            // let tagAssignmentCache = await cacheExistingTagAssignments(from: existingTransactions)
            
            var upsertedCount = 0
            var updatedCount = 0
            var preservedTagCount = 0
            var autoAssignedCount = 0
            
            for movement in movements {
                let movementTransactions = await parseMovementToTransactions(movement)
                
                for transactionData in movementTransactions {
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
                        
                        // Preserve existing tag assignments - they survive server updates
                        // No need to explicitly restore them as they're already attached to the existing transaction
                        // The SwiftData relationship will maintain the connections automatically
                        if !existingTransaction.tagAssignments.isEmpty {
                            preservedTagCount += existingTransaction.tagAssignments.count
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
                            fees: transactionData.fees
                        )
                        modelContext.insert(newTransaction)
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
                if !orphanedTransaction.tagAssignments.isEmpty {
                    orphanedTagCount += orphanedTransaction.tagAssignments.count
                    print("⚠️ Transaction \(orphanedTransaction.txid) no longer exists on server but has \(orphanedTransaction.tagAssignments.count) tag(s)")
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
            let alreadyAssigned = transaction.contactAssignments.contains { 
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
            if !transaction.tagAssignments.isEmpty {
                cache[transaction.txid] = transaction.tagAssignments
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
    }
    
    /// Calculate proportional fee allocation for multi-recipient transactions
    /// - Parameters:
    ///   - totalFees: Total fees for the movement
    ///   - recipientAmount: Amount for this specific recipient
    ///   - totalAmount: Total amount sent across all recipients
    ///   - recipientIndex: Index of this recipient (for rounding adjustments)
    ///   - totalRecipients: Total number of recipients
    /// - Returns: Proportionally allocated fee for this recipient
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
        var transactions: [TransactionData] = []
        let parsedDate = parseDate(movement.createdAt)
        
        // Analyze the movement to determine transaction types
        let totalSpent = movement.spends.reduce(0) { $0 + $1.amountSat }
        let totalReceived = movement.receives.reduce(0) { $0 + $1.amountSat }
        let totalSentToRecipients = movement.recipients.reduce(0) { $0 + $1.amountSat }
        
        if !movement.recipients.isEmpty {
            // This is a send transaction (user sent to others)
            // Create separate transactions for each recipient to preserve detail
            // Calculate fees proportionally based on amount sent
            var totalAllocatedFees = 0
            
            for (index, recipient) in movement.recipients.enumerated() {
                let proportionalFee = calculateProportionalFee(
                    totalFees: movement.fees,
                    recipientAmount: recipient.amountSat,
                    totalAmount: totalSentToRecipients,
                    recipientIndex: index,
                    totalRecipients: movement.recipients.count
                )
                
                totalAllocatedFees += proportionalFee
                
                let transaction = TransactionData(
                    txid: "movement_\(movement.id)_recipient_\(index)",
                    movementId: movement.id,
                    recipientIndex: index,
                    type: .sent,
                    amount: recipient.amountSat,
                    date: parsedDate,
                    status: .confirmed,
                    address: recipient.recipient,
                    fees: proportionalFee
                )
                transactions.append(transaction)
            }
            
            // Log fee allocation for verification (helpful during development)
            if movement.recipients.count > 1 {
                let feeDiscrepancy = abs(totalAllocatedFees - movement.fees)
                if feeDiscrepancy > 0 {
                    print("💰 Movement \(movement.id): Allocated \(totalAllocatedFees) sats fees across \(movement.recipients.count) recipients (total: \(movement.fees) sats, discrepancy: \(feeDiscrepancy) sats)")
                }
            }
        } else if totalReceived > 0 && totalSpent == 0 {
            // This is a receive transaction (user received from others)
            // Receiver doesn't pay fees
            let transaction = TransactionData(
                txid: "movement_\(movement.id)",
                movementId: movement.id,
                recipientIndex: nil,
                type: .received,
                amount: totalReceived,
                date: parsedDate,
                status: .confirmed,
                address: nil,
                fees: nil  // No fees for received transactions
            )
            transactions.append(transaction)
        } else if totalSpent > 0 && totalReceived > 0 && movement.recipients.isEmpty {
            // This is an internal transaction (VTXO consolidation/splitting)
            // Skip internal transactions as they don't represent economic transfers
            //print("🔄 Skipping internal transaction for movement \(movement.id)")
        } else {
            // Fallback for unexpected cases - log and skip
            print("⚠️ Unexpected movement pattern: spends=\(totalSpent), receives=\(totalReceived), recipients=\(totalSentToRecipients)")
        }
        
        return transactions
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Fallback to current date if parsing fails
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
            let taggedTransactionsCount = persistentTransactions.filter { !$0.tagAssignments.isEmpty }.count
            let totalTagAssignments = persistentTransactions.flatMap { $0.tagAssignments }.count
            
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
                    !transaction.tagAssignments.isEmpty
                }
            )
            let taggedTransactions = try modelContext.fetch(taggedDescriptor)
            
            if !taggedTransactions.isEmpty {
                print("🏷️ Found \(taggedTransactions.count) tagged transactions")
                
                // Refresh from server to identify which ones still exist
                let serverOutput = try await wallet.getMovements()
                let serverTxids = await getServerTransactionIds(from: serverOutput)
                
                let orphanedTaggedTransactions = taggedTransactions.filter { !serverTxids.contains($0.txid) }
                
                if !orphanedTaggedTransactions.isEmpty {
                    let totalOrphanedTags = orphanedTaggedTransactions.flatMap { $0.tagAssignments }.count
                    
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
