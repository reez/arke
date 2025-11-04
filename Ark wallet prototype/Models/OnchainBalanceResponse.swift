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
/// This struct is used for decoding API responses and passing data between actors.
/// It's naturally Sendable and contains all the computed properties for convenience.
struct OnchainBalanceResponse: Codable, Sendable {
    let totalSat: Int
    let trustedSpendableSat: Int
    let immatureSat: Int
    let trustedPendingSat: Int
    let untrustedPendingSat: Int
    let confirmedSat: Int
    
    enum CodingKeys: String, CodingKey {
        case totalSat = "total_sat"
        case trustedSpendableSat = "trusted_spendable_sat"
        case immatureSat = "immature_sat"
        case trustedPendingSat = "trusted_pending_sat"
        case untrustedPendingSat = "untrusted_pending_sat"
        case confirmedSat = "confirmed_sat"
    }
    
    // MARK: - Computed Properties (mirrored from OnchainBalanceModel)
    
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
