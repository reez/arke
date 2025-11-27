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
/// Key features:
/// - SwiftData @Model for direct UI observation and persistence
/// - Singleton pattern with id = "onchain_balance"
/// - Built-in cache validity and update methods
/// - All existing computed properties preserved
@Model
class OnchainBalanceModel {
    var id: String = "onchain_balance"  // Default value for CloudKit compatibility
    var totalSat: Int = 0
    var trustedSpendableSat: Int = 0
    var immatureSat: Int = 0
    var trustedPendingSat: Int = 0
    var untrustedPendingSat: Int = 0
    var confirmedSat: Int = 0
    var lastUpdated: Date = Date()  // Default value for CloudKit compatibility
    
    // MARK: - Initialization
    
    init(
        totalSat: Int,
        trustedSpendableSat: Int,
        immatureSat: Int,
        trustedPendingSat: Int,
        untrustedPendingSat: Int,
        confirmedSat: Int,
        lastUpdated: Date = Date()
    ) {
        self.id = "onchain_balance" // Singleton approach
        self.totalSat = totalSat
        self.trustedSpendableSat = trustedSpendableSat
        self.immatureSat = immatureSat
        self.trustedPendingSat = trustedPendingSat
        self.untrustedPendingSat = untrustedPendingSat
        self.confirmedSat = confirmedSat
        self.lastUpdated = lastUpdated
    }
    
    // MARK: - Convenience Methods
    
    /// Create from API response
    convenience init(from response: OnchainBalanceResponse) {
        self.init(
            totalSat: response.totalSat,
            trustedSpendableSat: response.trustedSpendableSat,
            immatureSat: response.immatureSat,
            trustedPendingSat: response.trustedPendingSat,
            untrustedPendingSat: response.untrustedPendingSat,
            confirmedSat: response.confirmedSat,
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
        self.trustedSpendableSat = response.trustedSpendableSat
        self.immatureSat = response.immatureSat
        self.trustedPendingSat = response.trustedPendingSat
        self.untrustedPendingSat = response.untrustedPendingSat
        self.confirmedSat = response.confirmedSat
        self.lastUpdated = Date()
    }
    
    // MARK: - Computed Properties (mirrored in OnchainBalanceResponse)
    
    /// Total balance in BTC
    var totalBTC: Double {
        Double(totalSat) / 100_000_000
    }
    
    /// Trusted spendable balance in BTC
    var trustedSpendableBTC: Double {
        Double(trustedSpendableSat) / 100_000_000
    }
    
    /// Confirmed balance in BTC
    var confirmedBTC: Double {
        Double(confirmedSat) / 100_000_000
    }
}
