//
//  FeePriority.swift
//  Arké
//
//  Created by Assistant on 3/25/26.
//

import Foundation
import SwiftUI

/// Priority level for on-chain Bitcoin transaction fees
enum FeePriority: String, CaseIterable, Identifiable {
    case fast = "fast"
    case medium = "medium"
    case slow = "slow"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .fast:
            return String(localized: "fee_priority_fast")
        case .medium:
            return String(localized: "fee_priority_medium")
        case .slow:
            return String(localized: "fee_priority_slow")
        }
    }
    
    var description: String {
        switch self {
        case .fast:
            return String(localized: "fee_priority_fast_description")
        case .medium:
            return String(localized: "fee_priority_medium_description")
        case .slow:
            return String(localized: "fee_priority_slow_description")
        }
    }
    
    var estimatedConfirmationTime: String {
        switch self {
        case .fast:
            return String(localized: "fee_priority_fast_time")
        case .medium:
            return String(localized: "fee_priority_medium_time")
        case .slow:
            return String(localized: "fee_priority_slow_time")
        }
    }
    
    /// Default fee rate in sat/vB for this priority
    /// These are fallback values when real-time fee estimation is unavailable
    var defaultSatPerVb: UInt64 {
        switch self {
        case .fast:
            return 10 // ~10-20 minutes
        case .medium:
            return 5  // ~30-60 minutes
        case .slow:
            return 2  // ~1-2 hours
        }
    }
}

/// On-chain fee rates for different priority levels
struct OnchainFeeRates {
    let fast: UInt64    // sat/vB
    let medium: UInt64  // sat/vB
    let slow: UInt64    // sat/vB
    
    /// Default fallback rates when real-time estimation is unavailable
    static let `default` = OnchainFeeRates(
        fast: FeePriority.fast.defaultSatPerVb,
        medium: FeePriority.medium.defaultSatPerVb,
        slow: FeePriority.slow.defaultSatPerVb
    )
    
    /// Get the fee rate for a specific priority
    func rate(for priority: FeePriority) -> UInt64 {
        switch priority {
        case .fast:
            return fast
        case .medium:
            return medium
        case .slow:
            return slow
        }
    }
}
