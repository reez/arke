//
//  OnchainBalanceResponse.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import Foundation
import SwiftData

/// Pure API response struct for Onchain balance data
///
/// This struct matches the FFI's OnchainBalance structure (totalSats, confirmedSats, pendingSats).
/// It's naturally Sendable and contains computed properties for convenience.
struct OnchainBalanceResponse: Codable, Sendable {
    let totalSat: Int
    let confirmedSat: Int
    let pendingSat: Int
    
    enum CodingKeys: String, CodingKey {
        case totalSat = "total_sat"
        case confirmedSat = "confirmed_sat"
        case pendingSat = "pending_sat"
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
