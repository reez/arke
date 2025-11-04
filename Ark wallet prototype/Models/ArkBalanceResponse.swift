//
//  ArkBalanceResponse.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import Foundation
import SwiftData

/// Pure API response struct for Ark balance data
///
/// This struct is used for decoding API responses and passing data between actors.
/// It's naturally Sendable and contains all the computed properties for convenience.
struct ArkBalanceResponse: Codable, Sendable {
    let spendableSat: Int
    let pendingLightningSendSat: Int
    let pendingInRoundSat: Int
    let pendingExitSat: Int
    let pendingBoardSat: Int
    
    enum CodingKeys: String, CodingKey {
        case spendableSat = "spendable_sat"
        case pendingLightningSendSat = "pending_lightning_send_sat"
        case pendingInRoundSat = "pending_in_round_sat"
        case pendingExitSat = "pending_exit_sat"
        case pendingBoardSat = "pending_board_sat"
    }
    
    // MARK: - Computed Properties (mirrored from ArkBalanceModel)
    
    /// Spendable balance in BTC
    var spendableBTC: Double {
        Double(spendableSat) / 100_000_000
    }
    
    var pendingLightningSendBTC: Double {
        Double(pendingLightningSendSat) / 100_000_000
    }
    
    var pendingInRoundBTC: Double {
        Double(pendingInRoundSat) / 100_000_000
    }
    
    var pendingExitBTC: Double {
        Double(pendingExitSat) / 100_000_000
    }
    
    var pendingBoardBTC: Double {
        Double(pendingBoardSat) / 100_000_000
    }
    
    // Total of all pending amounts
    var totalPendingSat: Int {
        pendingLightningSendSat + pendingInRoundSat + pendingExitSat + pendingBoardSat
    }
    
    var totalPendingBTC: Double {
        Double(totalPendingSat) / 100_000_000
    }
    
    // Total balance including spendable and all pending
    var totalSat: Int {
        spendableSat + totalPendingSat
    }
    
    var totalBTC: Double {
        Double(totalSat) / 100_000_000
    }
}
