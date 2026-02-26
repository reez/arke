//
//  RefreshUrgency.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/24/25.
//

import SwiftUI
import ArkeUI

enum RefreshUrgency {
    case expired   // Already expired (0 or negative blocks remaining)
    case critical  // < 15% of lifespan remaining - gives more buffer before expiry
    case warning   // 15-30% of lifespan remaining - earlier warning to prompt action
    case normal    // 30-50% of lifespan remaining
    case safe      // > 50% of lifespan remaining
    case none      // No VTXOs or all spent
    
    var color: Color {
        switch self {
        case .expired: return .Arke.red
        case .critical: return .Arke.orange
        case .warning: return .Arke.gold
        case .normal: return .Arke.green
        case .safe: return .Arke.green
        case .none: return Color.arkeSecondary
        }
    }
    
    var iconName: String {
        switch self {
        case .expired: return "xmark.octagon.fill"
        case .critical: return "exclamationmark.triangle.fill"
        case .warning: return "clock.fill"
        case .normal: return "arrow.clockwise.circle.fill"
        case .safe: return "checkmark.circle.fill"
        case .none: return "circle.fill"
        }
    }
    
    /// Calculate urgency level for a VTXO based on its expiry
    /// - Parameters:
    ///   - vtxo: The VTXO to evaluate
    ///   - currentBlockHeight: The current blockchain height
    ///   - vtxoLifespan: The total lifespan of VTXOs (from arkInfo.vtxoExpiryDelta)
    /// - Returns: The urgency level for this VTXO
    static func calculateUrgency(
        for vtxo: VTXOModel,
        currentBlockHeight: Int,
        vtxoLifespan: Int
    ) -> RefreshUrgency {
        let blocksUntilExpiry = vtxo.expiryHeight - currentBlockHeight
        let percentageRemaining = Double(blocksUntilExpiry) / Double(vtxoLifespan)
        
        if blocksUntilExpiry <= 0 {
            return .expired // Already expired
        } else if percentageRemaining < 0.15 {
            return .critical // Less than 15% of lifespan left - urgent action needed
        } else if percentageRemaining < 0.30 {
            return .warning // Less than 30% of lifespan left - should refresh soon
        } else if percentageRemaining < 0.50 {
            return .normal // Less than 50% of lifespan left - refresh available
        } else {
            return .safe // 50%+ of lifespan remaining
        }
    }
    
    /// Calculate the overall urgency level for a collection of VTXOs
    /// Returns the most urgent level among all active VTXOs
    /// - Parameters:
    ///   - vtxos: Array of VTXOs to evaluate
    ///   - currentBlockHeight: The current blockchain height
    ///   - vtxoLifespan: The total lifespan of VTXOs (from arkInfo.vtxoExpiryDelta)
    /// - Returns: The highest urgency level found, or .none if no active VTXOs
    static func calculateOverallUrgency(
        for vtxos: [VTXOModel],
        currentBlockHeight: Int,
        vtxoLifespan: Int
    ) -> RefreshUrgency {
        let activeVTXOs = vtxos.filter { $0.state != .spent }
        guard !activeVTXOs.isEmpty else { return .none }
        
        // Find the VTXO that expires soonest
        guard let nextExpiryVTXO = activeVTXOs.min(by: { vtxo1, vtxo2 in
            let rounds1 = vtxo1.expiryHeight - currentBlockHeight
            let rounds2 = vtxo2.expiryHeight - currentBlockHeight
            return rounds1 < rounds2
        }) else {
            return .none
        }
        
        return calculateUrgency(
            for: nextExpiryVTXO,
            currentBlockHeight: currentBlockHeight,
            vtxoLifespan: vtxoLifespan
        )
    }
    
    /// Returns VTXOs that should be refreshed based on urgency level
    /// Includes VTXOs that are at warning level or higher (.warning, .critical, .expired)
    /// - Parameters:
    ///   - vtxos: Array of all VTXOs to filter
    ///   - currentBlockHeight: The current blockchain height
    ///   - vtxoLifespan: The total lifespan of VTXOs (from arkInfo.vtxoExpiryDelta)
    /// - Returns: Array of VTXOs that need refreshing
    static func vtxosNeedingRefresh(
        from vtxos: [VTXOModel],
        currentBlockHeight: Int,
        vtxoLifespan: Int
    ) -> [VTXOModel] {
        let activeVTXOs = vtxos.filter { $0.state != .spent }
        
        return activeVTXOs.filter { vtxo in
            let urgency = calculateUrgency(
                for: vtxo,
                currentBlockHeight: currentBlockHeight,
                vtxoLifespan: vtxoLifespan
            )
            // Include VTXOs that are warning level or higher
            return urgency == .warning || urgency == .critical || urgency == .expired
        }
    }
}
