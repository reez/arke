//
//  OnchainTransactionEntity.swift
//  Arké
//
//  SwiftData persistence model for onchain Bitcoin transactions
//

import Foundation
import SwiftData

/// SwiftData model for persisting onchain Bitcoin transactions
@Model
class OnchainTransactionEntity {
    
    // MARK: - Properties
    
    /// Transaction ID (unique identifier)
    @Attribute(.unique) var txid: String
    
    /// Amount received in satoshis
    var received: UInt64
    
    /// Amount sent in satoshis
    var sent: UInt64
    
    /// Transaction fee in satoshis (optional)
    var fee: UInt64?
    
    // MARK: - Confirmation Details
    
    /// Block height where transaction was confirmed
    var confirmationHeight: UInt32?
    
    /// Unix timestamp when transaction was confirmed
    var confirmationTimestamp: UInt64?
    
    /// Block hash where transaction was confirmed
    var confirmationBlockHash: String?
    
    /// Current blockchain height at time of last update
    var currentHeight: UInt32?
    
    // MARK: - Metadata
    
    /// Last time this transaction was updated
    var lastUpdated: Date
    
    // MARK: - Initialization
    
    init(
        txid: String,
        received: UInt64,
        sent: UInt64,
        fee: UInt64?,
        confirmationHeight: UInt32?,
        confirmationTimestamp: UInt64?,
        confirmationBlockHash: String?,
        currentHeight: UInt32?,
        lastUpdated: Date
    ) {
        self.txid = txid
        self.received = received
        self.sent = sent
        self.fee = fee
        self.confirmationHeight = confirmationHeight
        self.confirmationTimestamp = confirmationTimestamp
        self.confirmationBlockHash = confirmationBlockHash
        self.currentHeight = currentHeight
        self.lastUpdated = lastUpdated
    }
    
    /// Initialize from OnchainTransactionModel
    convenience init(from model: OnchainTransactionModel) {
        self.init(
            txid: model.txid,
            received: model.received,
            sent: model.sent,
            fee: model.fee,
            confirmationHeight: model.confirmationTime?.height,
            confirmationTimestamp: model.confirmationTime?.timestamp,
            confirmationBlockHash: model.confirmationTime?.blockHash,
            currentHeight: model.confirmationTime?.currentHeight,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Update Methods
    
    /// Update this entity from a new model (for upsert logic)
    func update(from model: OnchainTransactionModel) {
        self.received = model.received
        self.sent = model.sent
        self.fee = model.fee
        self.confirmationHeight = model.confirmationTime?.height
        self.confirmationTimestamp = model.confirmationTime?.timestamp
        self.confirmationBlockHash = model.confirmationTime?.blockHash
        self.currentHeight = model.confirmationTime?.currentHeight
        self.lastUpdated = Date()
    }
    
    // MARK: - Conversion to Model
    
    /// Convert this entity back to OnchainTransactionModel
    var asModel: OnchainTransactionModel {
        let confirmationTime: ConfirmationTime?
        
        if let height = confirmationHeight, let timestamp = confirmationTimestamp {
            confirmationTime = ConfirmationTime(
                height: height,
                timestamp: timestamp,
                blockHash: confirmationBlockHash,
                currentHeight: currentHeight
            )
        } else {
            confirmationTime = nil
        }
        
        return OnchainTransactionModel(
            txid: txid,
            received: received,
            sent: sent,
            fee: fee,
            confirmationTime: confirmationTime
        )
    }
}

// MARK: - Computed Properties (Mirror OnchainTransactionModel)

extension OnchainTransactionEntity {
    
    /// Net amount change (positive = received, negative = sent)
    var netAmount: Int64 {
        Int64(received) - Int64(sent)
    }
    
    /// Whether this is an incoming transaction
    var isIncoming: Bool {
        netAmount > 0
    }
    
    /// Whether this is a self-transfer (funds moved between own addresses)
    /// Detected when both sent and received amounts are non-zero
    var isSelfTransfer: Bool {
        sent > 0 && received > 0
    }
    
    /// Whether transaction is confirmed
    var isConfirmed: Bool {
        confirmationHeight != nil && confirmationTimestamp != nil
    }
    
    /// Number of confirmations (0 if unconfirmed)
    var confirmations: UInt32 {
        guard let height = confirmationHeight,
              let current = currentHeight else {
            return 0
        }
        
        if current >= height {
            return current - height + 1
        } else {
            return 1
        }
    }
    
    /// Display amount (absolute value of net amount)
    var displayAmount: UInt64 {
        UInt64(abs(netAmount))
    }
    
    /// Short transaction ID for display (first 8 chars)
    var shortTxid: String {
        String(txid.prefix(8))
    }
    
    /// Transaction timestamp (nil if unconfirmed)
    var timestamp: Date? {
        guard let confirmationTimestamp = confirmationTimestamp else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(confirmationTimestamp))
    }
}
