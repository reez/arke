//
//  TransactionModel.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/23/25.
//

import Foundation
import SwiftData
import Bark
import ArkeUI

struct TransactionModel: Identifiable, Hashable, Codable {
    let txid: String  // Primary stable identifier
    let movementId: Int?  // Server movement ID for grouping
    let recipientIndex: Int?  // For tracking multiple recipients in same movement
    let type: TransactionTypeEnum
    let amount: Int  // Amount in satoshis
    let date: Date
    let status: TransactionStatusEnum
    let address: String?  // Recipient address for sends, nil for receives
    let notes: String?  // User-added notes for this transaction (max 1000 characters)
    let fees: Int?  // Offchain transaction fees in satoshis (proportionally allocated for multi-recipient sends)
    let onchainFeeSat: Int?  // Bitcoin network fees (for onchain operations like boarding)
    
    // Enhanced metadata fields (Phase 4)
    let subsystemCategory: String?  // Movement category (e.g., "lightning_send", "offchain_transfer")
    let subsystemName: String?  // Subsystem name from server (e.g., "bark.arkoor", "bark.offboard")
    let subsystemKind: String?  // Subsystem kind from server (e.g., "send", "receive", "send_onchain")
    let paymentMethodType: String?  // Payment method type (e.g., "invoice", "bitcoin", "ark")
    let paymentHash: String?  // Lightning payment hash identifier
    let fundingTxid: String?  // Round funding transaction ID
    
    // VTXO ID tracking
    let inputVtxoIds: [String]  // VTXOs consumed in this transaction
    let outputVtxoIds: [String]  // VTXOs created by this transaction
    let exitedVtxoIds: [String]  // VTXOs forced into unilateral exit
    
    // Onchain transaction fields
    let confirmationHeight: UInt32?  // Block height where tx was confirmed (onchain only)
    let confirmationCount: UInt32?  // Number of confirmations (onchain only) - deprecated, use liveConfirmations
    
    // Transaction linking fields (movement-onchain linking)
    let parentTxid: String?  // Parent movement txid for linked onchain transactions
    let childTxids: [String]?  // Linked onchain txids for movement transactions
    
    // Associated tags and contacts (full objects for UI convenience)
    let associatedTags: [TagModel]
    let associatedContacts: [ContactModel]
    
    // Movement category for enhanced display
    let category: MovementCategory?
    
    init(txid: String, movementId: Int?, recipientIndex: Int? = nil, type: TransactionTypeEnum,
         amount: Int, date: Date, status: TransactionStatusEnum, address: String?, notes: String? = nil,
         associatedTags: [TagModel] = [], associatedContacts: [ContactModel] = [], fees: Int? = nil,
         onchainFeeSat: Int? = nil, subsystemCategory: String? = nil, subsystemName: String? = nil,
         subsystemKind: String? = nil, paymentMethodType: String? = nil,
         paymentHash: String? = nil, fundingTxid: String? = nil,
         inputVtxoIds: [String] = [], outputVtxoIds: [String] = [], 
         exitedVtxoIds: [String] = [], confirmationHeight: UInt32? = nil, confirmationCount: UInt32? = nil, 
         category: MovementCategory? = nil, parentTxid: String? = nil, childTxids: [String]? = nil) {
        self.txid = txid
        self.movementId = movementId
        self.recipientIndex = recipientIndex
        self.type = type
        self.amount = amount
        self.date = date
        self.status = status
        self.address = address
        self.notes = notes
        self.associatedTags = associatedTags
        self.associatedContacts = associatedContacts
        self.fees = fees
        self.onchainFeeSat = onchainFeeSat
        self.subsystemCategory = subsystemCategory
        self.subsystemName = subsystemName
        self.subsystemKind = subsystemKind
        self.paymentMethodType = paymentMethodType
        self.paymentHash = paymentHash
        self.fundingTxid = fundingTxid
        self.inputVtxoIds = inputVtxoIds
        self.outputVtxoIds = outputVtxoIds
        self.exitedVtxoIds = exitedVtxoIds
        self.confirmationHeight = confirmationHeight
        self.confirmationCount = confirmationCount
        self.category = category
        self.parentTxid = parentTxid
        self.childTxids = childTxids
    }
    
    // MARK: - Initialize from PersistentTransaction
    
    init(from persistentTransaction: PersistentTransaction) {
        self.txid = persistentTransaction.txid
        self.movementId = persistentTransaction.movementId
        self.recipientIndex = persistentTransaction.recipientIndex
        self.type = persistentTransaction.transactionType
        self.amount = persistentTransaction.amount
        self.date = persistentTransaction.date
        self.status = persistentTransaction.transactionStatus
        self.address = persistentTransaction.address
        self.notes = persistentTransaction.notes
        self.fees = persistentTransaction.fees
        self.onchainFeeSat = persistentTransaction.onchainFeeSat
        self.subsystemCategory = persistentTransaction.subsystemCategory
        self.subsystemName = persistentTransaction.subsystemName
        self.subsystemKind = persistentTransaction.subsystemKind
        self.paymentMethodType = persistentTransaction.paymentMethodType
        self.paymentHash = persistentTransaction.paymentHash
        self.fundingTxid = persistentTransaction.fundingTxid
        self.inputVtxoIds = persistentTransaction.inputVtxoIds
        self.outputVtxoIds = persistentTransaction.outputVtxoIds
        self.exitedVtxoIds = persistentTransaction.exitedVtxoIds
        self.confirmationHeight = persistentTransaction.confirmationHeight
        self.confirmationCount = persistentTransaction.confirmationCount
        self.associatedTags = persistentTransaction.associatedTags.map { TagModel(from: $0) }
        self.associatedContacts = persistentTransaction.associatedContacts.map { ContactModel(from: $0) }
        self.category = persistentTransaction.category
        self.parentTxid = persistentTransaction.parentTxid
        self.childTxids = persistentTransaction.childTxids
    }
    
    // MARK: - Identifiable
    
    var id: String { txid }
    
    // MARK: - UI Formatting Properties
    
    /// Formatted amount for display (e.g., "+0.00123456 BTC" or "-0.00050000 BTC")
    var formattedAmount: String {
        return BitcoinFormatter.shared.formatTransactionAmount(amount, transactionType: type, isInternalTransfer: isInternalTransfer)
    }
    
    /// Net amount including fees (what actually left/arrived in the wallet)
    var netAmount: Int {
        // For sent and transfer transactions, add fees to get total amount that left the wallet
        if type == .sent || type == .transfer {
            return amount + totalFees  // amount is stored as positive, so we add fees to show total that left
        }
        // For received transactions, amount is what arrived (fees not relevant to user)
        return amount
    }
    
    /// Net amount including fees from linked child transactions (for exits)
    /// - Parameter modelContext: SwiftData context to fetch linked transactions
    /// - Returns: Net amount including all fees
    func netAmountIncludingLinked(modelContext: ModelContext?) -> Int {
        // For sent and transfer transactions, add fees to get total amount that left the wallet
        if type == .sent || type == .transfer {
            return amount + totalFeesIncludingLinked(modelContext: modelContext)
        }
        // For received transactions, amount is what arrived (fees not relevant to user)
        return amount
    }
    
    /// Formatted net amount for display (includes fees in the calculation)
    /// For internal transfers, shows only the fees paid (as negative amount)
    var formattedNetAmount: String {
        // For internal transfers, only show the fees (as negative)
        if isInternalTransfer {
            let feesToShow = totalFees
            guard feesToShow > 0 else {
                return BitcoinFormatter.shared.formatAmount(0)
            }
            return BitcoinFormatter.shared.formatTransactionAmount(feesToShow, transactionType: .sent, isInternalTransfer: false)
        }
        
        return BitcoinFormatter.shared.formatTransactionAmount(netAmount, transactionType: type, isInternalTransfer: isInternalTransfer)
    }
    
    /// Formatted net amount including linked transaction fees (for exits)
    /// - Parameter modelContext: SwiftData context to fetch linked transactions
    /// - Returns: Formatted net amount string
    func formattedNetAmountIncludingLinked(modelContext: ModelContext?) -> String {
        // For internal transfers, only show the fees (as negative)
        if isInternalTransfer {
            let feesToShow = totalFeesIncludingLinked(modelContext: modelContext)
            guard feesToShow > 0 else {
                return BitcoinFormatter.shared.formatAmount(0)
            }
            return BitcoinFormatter.shared.formatTransactionAmount(feesToShow, transactionType: .sent, isInternalTransfer: false)
        }
        
        return BitcoinFormatter.shared.formatTransactionAmount(netAmountIncludingLinked(modelContext: modelContext), transactionType: type, isInternalTransfer: isInternalTransfer)
    }
    
    /// Formatted amount for display in transaction detail views
    /// For internal transfers (onboard, offboard, unilateral exit, send_onchain to own address),
    /// shows the amount that was transferred without the +/- sign
    /// For other transactions, shows the net amount with +/- sign
    var formattedDisplayAmount: String {
        // For internal transfers, show the transferred amount without sign
        if isInternalTransfer {
            return BitcoinFormatter.shared.formatAmount(abs(amount))
        }
        
        // For other transactions, show net amount with sign
        return BitcoinFormatter.shared.formatTransactionAmount(amount, transactionType: type, isInternalTransfer: isInternalTransfer)
    }
    
    /// Formatted amount for accounting display
    var formattedAmountAccounting: String {
        return BitcoinFormatter.shared.formatAccountingAmount(amount, transactionType: type, isInternalTransfer: isInternalTransfer)
    }
    
    /// Formatted date for display (relative time)
    var formattedDate: String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        // Show "just now" for timestamps within ±5 seconds
        if abs(interval) <= 5 {
            return "just now"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }
    
    /// Absolute formatted date
    var formattedDateAbsolute: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Formatted fee for display (e.g., "250 sats" or "0.00000250 BTC")
    /// Shows offchain fees only (for backwards compatibility)
    var formattedFee: String? {
        guard let fees = fees, fees > 0 else {
            return nil
        }
        return BitcoinFormatter.shared.formatAmount(fees)
    }
    
    /// Formatted onchain fee for display
    var formattedOnchainFee: String? {
        guard let onchainFee = onchainFeeSat, onchainFee > 0 else {
            return nil
        }
        return BitcoinFormatter.shared.formatAmount(onchainFee)
    }
    
    /// Total fees (offchain + onchain)
    /// For exit transactions, this only returns fees stored directly on the transaction.
    /// Use totalFeesIncludingLinked(modelContext:) to include fees from linked onchain transactions.
    var totalFees: Int {
        let offchain = fees ?? 0
        let onchain = onchainFeeSat ?? 0
        return offchain + onchain
    }
    
    /// Calculate total fees including fees from linked child transactions (for exits)
    /// - Parameter modelContext: SwiftData context to fetch linked transactions
    /// - Returns: Total fees including linked transaction fees
    func totalFeesIncludingLinked(modelContext: ModelContext?) -> Int {
        // Start with direct fees
        var total = totalFees
        
        // For exit transactions, add fees from linked onchain transactions
        if subsystemName == "bark.exit", let childTxids = childTxids, !childTxids.isEmpty, let modelContext = modelContext {
            // Fetch and sum fees from all linked onchain transactions
            for childTxid in childTxids {
                let descriptor = FetchDescriptor<PersistentTransaction>(
                    predicate: #Predicate { $0.txid == childTxid }
                )
                
                if let childTx = try? modelContext.fetch(descriptor).first,
                   let childFee = childTx.onchainFeeSat {
                    total += childFee
                }
            }
        }
        
        return total
    }
    
    /// Formatted total fees including linked transactions (for exits)
    /// - Parameter modelContext: SwiftData context to fetch linked transactions
    /// - Returns: Formatted fee string or nil if no fees
    func formattedTotalFeesIncludingLinked(modelContext: ModelContext?) -> String? {
        let total = totalFeesIncludingLinked(modelContext: modelContext)
        guard total > 0 else {
            return nil
        }
        return BitcoinFormatter.shared.formatAmount(total)
    }
    
    /// Formatted total fees for display
    var formattedTotalFees: String? {
        let total = totalFees
        guard total > 0 else {
            return nil
        }
        return BitcoinFormatter.shared.formatAmount(total)
    }
    
    /// Formatted total fees as negative amount (like a send transaction)
    var formattedTotalFeesNegative: String? {
        let total = totalFees
        guard total > 0 else {
            return nil
        }
        return BitcoinFormatter.shared.formatTransactionAmount(total, transactionType: .sent, isInternalTransfer: false)
    }
    
    /// Check if transaction has fees
    var hasFees: Bool {
        totalFees > 0
    }
    
    /// Check if transaction has both onchain and offchain fees
    var hasBothFeeTypes: Bool {
        let hasOffchain = (fees ?? 0) > 0
        let hasOnchain = (onchainFeeSat ?? 0) > 0
        return hasOffchain && hasOnchain
    }
    
    /// Convenience accessor for transaction type (already a typed property)
    var transactionType: TransactionTypeEnum {
        return type
    }
    
    /// Convenience accessor for transaction status (already a typed property)
    var transactionStatus: TransactionStatusEnum {
        return status
    }
    
    /// Check if this transaction is an internal transfer (between user's own balances)
    /// Internal transfers include:
    /// - Boarding, offboarding, refresh, exit operations (internal by nature)
    /// - Onchain sends to own addresses (requires client-side detection)
    /// - Onchain self-transfers detected by BDK (both sent and received non-zero)
    var isInternalTransfer: Bool {
        guard let category = category else { return false }
        
        switch category {
        case .boarding, .offboarding, .refresh, .exit:
            return true
        case .onchainTransaction:
            // For pure onchain transactions from BDK, check if it's a self-transfer
            // This is indicated by subsystemKind being "self_transfer"
            return subsystemKind == "self_transfer"
        case .onchainSend:
            return subsystemName == "bark.offboard"
            // For onchain sends, this will be determined by whether a receivingAddress
            // is linked in PersistentTransaction. This property will be true when
            // the TransactionService detects the destination is owned by the user.
            // Note: This check is placeholder - actual detection happens in PersistentTransaction
            //return false
        default:
            return false
        }
    }
    
    // MARK: - Tag and Contact Helpers
    
    /// Check if transaction has any tags
    var hasTags: Bool {
        !associatedTags.isEmpty
    }
    
    /// Count of tags
    var tagCount: Int {
        associatedTags.count
    }
    
    /// Check if transaction has a specific tag
    func hasTag(_ tag: TagModel) -> Bool {
        associatedTags.contains { $0.id == tag.id }
    }
    
    /// Check if transaction has a specific tag ID
    func hasTag(id: UUID) -> Bool {
        associatedTags.contains { $0.id == id }
    }
    
    /// Check if transaction has any contacts
    var hasContacts: Bool {
        !associatedContacts.isEmpty
    }
    
    /// Count of contacts
    var contactCount: Int {
        associatedContacts.count
    }
    
    /// Check if transaction has a specific contact
    func hasContact(_ contact: ContactModel) -> Bool {
        associatedContacts.contains { $0.id == contact.id }
    }
    
    /// Check if transaction has a specific contact ID
    func hasContact(id: UUID) -> Bool {
        associatedContacts.contains { $0.id == id }
    }
    
    // MARK: - Notes Helpers
    
    /// Check if transaction has notes
    var hasNotes: Bool {
        guard let notes = notes else { return false }
        return !notes.isEmpty
    }
    
    /// Get a preview of the notes (first 100 characters)
    var notesPreview: String? {
        guard let notes = notes, !notes.isEmpty else { return nil }
        if notes.count <= 100 {
            return notes
        }
        let endIndex = notes.index(notes.startIndex, offsetBy: 100)
        return String(notes[..<endIndex]) + String(localized: "symbol_ellipsis")
    }
    
    // MARK: - Linking Helpers
    
    /// Check if this transaction has linked onchain transactions
    var hasLinkedOnchainTransactions: Bool {
        guard let childTxids = childTxids else { return false }
        return !childTxids.isEmpty
    }
    
    /// Check if this transaction is linked to a parent movement
    var hasParentMovement: Bool {
        parentTxid != nil
    }
    
    // MARK: - Confirmation Helpers
    
    /// Get live confirmation count based on current block height
    /// This is calculated dynamically from confirmationHeight and current chain tip
    /// Returns nil if this is not an onchain transaction or if confirmation height is unknown
    var liveConfirmations: UInt32? {
        guard let confirmationHeight = confirmationHeight else {
            // Not an onchain transaction or unconfirmed
            return confirmationCount
        }
        
        // Access wallet manager through the static weak reference
        guard let walletManager = Self.walletManager as? WalletManager else {
            // Fallback to stored confirmationCount if wallet manager unavailable
            return confirmationCount
        }
        
        // Get current block height
        guard let currentHeight = walletManager.estimatedBlockHeight else {
            // Fallback to stored confirmationCount if current height unavailable
            return confirmationCount
        }
        
        // Calculate confirmations: currentHeight - confirmationHeight + 1
        // +1 because a transaction in block 100 has 1 confirmation at height 100
        let calculatedConfirmations = UInt32(currentHeight) - confirmationHeight + 1
        return max(calculatedConfirmations, 1)  // Ensure at least 1 confirmation if confirmed
    }
    
    // MARK: - Exit Status Helpers
    
    /// Weak reference to wallet manager for looking up current exit status
    /// This is set by views when displaying transactions
    static weak var walletManager: AnyObject?
    
    /// Check if this transaction has an associated unilateral exit
    var hasUnilateralExit: Bool {
        subsystemName == "bark.exit" && !exitedVtxoIds.isEmpty
    }
    
    /// Get the current exit status for this transaction
    /// Returns nil if this is not an exit transaction or if wallet manager is not available
    var currentExitStatus: ExitStatus? {
        guard hasUnilateralExit else { return nil }
        
        // Access wallet manager through the static weak reference
        guard let walletManager = Self.walletManager as? WalletManager else {
            return nil
        }
        
        // Get all exits (including claimed ones)
        let allExits = walletManager.allUnilateralExits
        
        // Find the exit that matches any of this transaction's exited VTXOs
        for vtxoId in exitedVtxoIds {
            if let exit = allExits.first(where: { $0.vtxoId == vtxoId }) {
                return ExitStatus(from: exit)
            }
        }
        
        return nil
    }
    
    /// Check if the exit associated with this transaction is claimed
    var isExitClaimed: Bool {
        currentExitStatus?.isClaimed ?? false
    }
    
    // MARK: - Convert to PersistentTransaction
    
    func toPersistentTransaction() -> PersistentTransaction {
        return PersistentTransaction(
            txid: self.txid,
            movementId: self.movementId,
            recipientIndex: self.recipientIndex,
            type: self.type,
            amount: self.amount,
            date: self.date,
            status: self.status,
            address: self.address,
            notes: self.notes,
            fees: self.fees,
            subsystemCategory: self.subsystemCategory,
            subsystemName: self.subsystemName,
            subsystemKind: self.subsystemKind,
            paymentMethodType: self.paymentMethodType,
            paymentHash: self.paymentHash,
            onchainFeeSat: self.onchainFeeSat,
            fundingTxid: self.fundingTxid,
            inputVtxoIds: self.inputVtxoIds,
            outputVtxoIds: self.outputVtxoIds,
            exitedVtxoIds: self.exitedVtxoIds
        )
        // Note: Tag and contact assignments should be managed separately through services
        // to avoid complex relationship management during transaction creation
    }
}

// MARK: - Exit Status Model

/// Represents the current status of a unilateral exit
struct ExitStatus {
    let isClaimed: Bool
    let isClaimable: Bool
    let stateDisplayName: String
    
    init(from exitVtxo: ExitVtxo) {
        self.isClaimed = exitVtxo.isClaimed
        self.isClaimable = exitVtxo.isClaimable
        self.stateDisplayName = exitVtxo.stateDisplayName
    }
}
