//
//  OnchainBalanceModel.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//  Migrated by Assistant on 10/29/25 - Unified with PersistedOnchainBalance
//

import Foundation
import SwiftData

/// SwiftData persistence model for Onchain balance
/// 
/// This model is now focused purely on persistence and UI observation.
/// API decoding is handled by OnchainBalanceResponse struct.
///
/// Simplified to match FFI's OnchainBalance structure (total, confirmed, pending).
///
/// Key features:
/// - SwiftData @Model for direct UI observation and persistence
/// - Singleton pattern with id = "onchain_balance"
/// - Built-in cache validity and update methods
@Model
class OnchainBalanceModel {
    var id: String = "onchain_balance"  // Default value for CloudKit compatibility
    var totalSat: Int = 0
    var confirmedSat: Int = 0
    var pendingSat: Int = 0
    var lastUpdated: Date = Date()  // Default value for CloudKit compatibility
    
    // MARK: - Initialization
    
    init(
        totalSat: Int,
        confirmedSat: Int,
        pendingSat: Int,
        lastUpdated: Date = Date()
    ) {
        self.id = "onchain_balance" // Singleton approach
        self.totalSat = totalSat
        self.confirmedSat = confirmedSat
        self.pendingSat = pendingSat
        self.lastUpdated = lastUpdated
    }
    
    // MARK: - Convenience Methods
    
    /// Create from API response
    convenience init(from response: OnchainBalanceResponse) {
        self.init(
            totalSat: response.totalSat,
            confirmedSat: response.confirmedSat,
            pendingSat: response.pendingSat,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Persistence Methods
    
    /// Check if the cached balance is still valid (within 5 minutes)
    var isValid: Bool {
        let cacheValidityDuration: TimeInterval = 5 * 60 // 5 minutes
        return Date().timeIntervalSince(lastUpdated) < cacheValidityDuration
    }
    
    /// Update with new balance data from API response
    func update(from response: OnchainBalanceResponse) {
        self.totalSat = response.totalSat
        self.confirmedSat = response.confirmedSat
        self.pendingSat = response.pendingSat
        self.lastUpdated = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Total balance in BTC
    var totalBTC: Double {
        Double(totalSat) / 100_000_000
    }
    
    /// Confirmed balance in BTC (spendable)
    var confirmedBTC: Double {
        Double(confirmedSat) / 100_000_000
    }
    
    /// Pending balance in BTC
    var pendingBTC: Double {
        Double(pendingSat) / 100_000_000
    }
    
    /// Confirmed balance is the spendable amount
    var spendableSat: Int {
        confirmedSat
    }
    
    /// Confirmed balance in BTC is the spendable amount
    var spendableBTC: Double {
        confirmedBTC
    }
}
