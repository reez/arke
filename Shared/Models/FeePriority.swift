//
//  FeePriority.swift
//  Arké
//
//  Created by Assistant on 3/25/26.
//

import Foundation

/// Priority level for on-chain Bitcoin transaction fees
enum FeePriority: String, CaseIterable, Identifiable {
    case slow = "slow"
    case medium = "medium"
    case fast = "fast"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .slow:
            return String(localized: "fee_priority_slow")
        case .medium:
            return String(localized: "fee_priority_medium")
        case .fast:
            return String(localized: "fee_priority_fast")
        }
    }
    
    var description: String {
        switch self {
        case .slow:
            return String(localized: "fee_priority_slow_description")
        case .medium:
            return String(localized: "fee_priority_medium_description")
        case .fast:
            return String(localized: "fee_priority_fast_description")
        }
    }
    
    var estimatedConfirmationTime: String {
        switch self {
        case .slow:
            return String(localized: "fee_priority_slow_time")
        case .medium:
            return String(localized: "fee_priority_medium_time")
        case .fast:
            return String(localized: "fee_priority_fast_time")
        }
    }
    
    /// Default fee rate in sat/vB for this priority
    /// These are fallback values when real-time fee estimation is unavailable
    var defaultSatPerVb: UInt64 {
        switch self {
        case .slow:
            return 2  // ~1-2 hours
        case .medium:
            return 5  // ~30-60 minutes
        case .fast:
            return 10 // ~10-20 minutes
        }
    }
}

/// On-chain fee rates for different priority levels
struct OnchainFeeRates {
    let slow: UInt64    // sat/vB
    let medium: UInt64  // sat/vB
    let fast: UInt64    // sat/vB
    
    /// Default fallback rates when real-time estimation is unavailable
    static let `default` = OnchainFeeRates(
        slow: FeePriority.slow.defaultSatPerVb,
        medium: FeePriority.medium.defaultSatPerVb,
        fast: FeePriority.fast.defaultSatPerVb
    )
    
    /// Get the fee rate for a specific priority
    func rate(for priority: FeePriority) -> UInt64 {
        switch priority {
        case .slow:
            return slow
        case .medium:
            return medium
        case .fast:
            return fast
        }
    }
}
