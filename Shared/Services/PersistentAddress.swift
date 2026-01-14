//
//  PersistentAddress.swift
//  Ark wallet prototype
//
//  Created by Assistant on 1/12/26.
//

import Foundation
import SwiftData

/// SwiftData model for tracking wallet address history
/// This is primarily an internal system model for:
/// - Gap limit compliance (Bitcoin BIP44)
/// - Internal transfer detection
/// - Address-transaction linking
/// - Wallet recovery support
@Model
final class PersistentAddress {
    // MARK: - Identity
    
    /// Unique identifier
    var id: UUID = UUID()
    
    /// The actual address string (Ark or Bitcoin)
    var address: String = ""
    
    /// Type of address ("ark" or "onchain")
    var addressType: String = "ark"
    
    // MARK: - Generation Metadata
    
    /// When this address was generated
    var generatedAt: Date = Date()
    
    /// BIP44 derivation index for onchain addresses (critical for recovery)
    /// Nil for Ark addresses (not BIP44-based)
    var derivationIndex: Int?
    
    /// How this address was generated
    var generatedBy: String = "auto"
    
    // MARK: - Usage Tracking
    
    /// Whether this address has received any funds
    var isUsed: Bool = false
    
    /// When the first transaction was received to this address
    var firstUsedAt: Date?
    
    /// When the most recent transaction was received to this address
    var lastUsedAt: Date?
    
    /// Count of transactions received to this address
    var receivedTransactionCount: Int = 0
    
    /// Total satoshis received to this address (cumulative)
    var totalReceivedSats: Int = 0
    
    // MARK: - Status
    
    /// Whether this address is active (can be deactivated during wallet restore)
    var isActive: Bool = true
    
    // MARK: - Relationships
    
    /// Transactions that were received to this address
    @Relationship(deleteRule: .nullify, inverse: \PersistentTransaction.receivingAddress)
    var receivedTransactions: [PersistentTransaction]? = []
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        address: String,
        addressType: AddressType,
        generatedAt: Date = Date(),
        derivationIndex: Int? = nil,
        generatedBy: AddressGenerationStrategy = .auto
    ) {
        self.id = id
        self.address = address
        self.addressType = addressType.rawValue
        self.generatedAt = generatedAt
        self.derivationIndex = derivationIndex
        self.generatedBy = generatedBy.rawValue
    }
    
    // MARK: - Computed Properties
    
    /// Get the address type as enum
    var type: AddressType {
        return AddressType(rawValue: addressType) ?? .ark
    }
    
    /// Get the generation strategy as enum
    var strategy: AddressGenerationStrategy {
        return AddressGenerationStrategy(rawValue: generatedBy) ?? .auto
    }
    
    /// Whether this address has been used to receive funds
    var hasBeenUsed: Bool {
        return isUsed
    }
    
    /// Formatted total received amount
    var totalReceivedFormatted: String {
        return BitcoinFormatter.shared.formatAmount(totalReceivedSats)
    }
}
