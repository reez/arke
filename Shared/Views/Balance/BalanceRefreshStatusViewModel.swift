//
//  BalanceRefreshStatusViewModel.swift
//  Arke
//
//  Created by Assistant on 4/24/26.
//

import SwiftUI
import Observation

/// Shared view model for balance refresh status calculations
/// Used by both BalanceRefreshStatusContainer and BalanceRefreshStatusContainerCompact
@Observable
@MainActor
class BalanceRefreshStatusViewModel {
    
    // MARK: - Dependencies
    
    private let walletManager: WalletManager
    
    // MARK: - State
    
    var vtxos: [VTXOModel] = []
    var latestBlockHeight: Int?
    var nextRoundStartTime: UInt64?
    var hasCompletedInitialLoad = false
    
    // MARK: - Initialization
    
    init(walletManager: WalletManager) {
        self.walletManager = walletManager
    }
    
    // MARK: - Computed Properties
    
    var activeVTXOs: [VTXOModel] {
        vtxos.filter { $0.state != .spent }
    }
    
    /// Get the set of VTXO IDs that are currently being refreshed in pending transactions
    var vtxosBeingRefreshed: Set<String> {
        guard hasActiveRefresh else { return Set() }
        
        // Get all pending refresh transactions
        let pendingRefreshes = walletManager.transactions.filter {
            $0.category == .refresh && $0.status == .pending
        }
        
        // Collect all VTXO IDs that are inputs to these transactions
        return Set(pendingRefreshes.flatMap { $0.inputVtxoIds })
    }
    
    var urgencyLevel: RefreshUrgency {
        guard let blockHeight = latestBlockHeight,
              let vtxoLifespan = walletManager.arkInfo?.vtxoExpiryDelta else {
            return .none
        }
        
        // Filter out VTXOs that are already being refreshed
        let vtxosToEvaluate: [VTXOModel]
        if hasActiveRefresh {
            let beingRefreshed = vtxosBeingRefreshed
            vtxosToEvaluate = vtxos.filter { !beingRefreshed.contains($0.id) }
        } else {
            vtxosToEvaluate = vtxos
        }
        
        return RefreshUrgency.calculateOverallUrgency(
            for: vtxosToEvaluate,
            currentBlockHeight: blockHeight,
            vtxoLifespan: vtxoLifespan
        )
    }
    
    var secondsUntilNextExpiry: Int? {
        guard let blockHeight = latestBlockHeight else { return nil }
        let nextExpiry = activeVTXOs.min {
            ($0.expiryHeight - blockHeight) < ($1.expiryHeight - blockHeight)
        }
        guard let vtxo = nextExpiry else { return nil }
        let secondsPerBlock = 600 // 10 minutes per block
        return (vtxo.expiryHeight - blockHeight) * secondsPerBlock
    }
    
    var hasActiveRefresh: Bool {
        walletManager.transactions.contains {
            $0.category == .refresh && $0.status == .pending
        }
    }
    
    /// Returns the total amount (in satoshis) of VTXOs that should be refreshed
    /// based on the current urgency level
    var totalAmountToRefresh: Int {
        guard let blockHeight = latestBlockHeight,
              let vtxoLifespan = walletManager.arkInfo?.vtxoExpiryDelta else {
            return 0
        }
        
        // Filter out VTXOs that are already being refreshed
        let vtxosToEvaluate: [VTXOModel]
        if hasActiveRefresh {
            let beingRefreshed = vtxosBeingRefreshed
            vtxosToEvaluate = vtxos.filter { !beingRefreshed.contains($0.id) }
        } else {
            vtxosToEvaluate = vtxos
        }
        
        let vtxosToRefresh = RefreshUrgency.vtxosNeedingRefresh(
            from: vtxosToEvaluate,
            currentBlockHeight: blockHeight,
            vtxoLifespan: vtxoLifespan
        )
        
        return vtxosToRefresh.reduce(0) { $0 + $1.amountSat }
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        do {
            vtxos = try await walletManager.getVTXOs()
            latestBlockHeight = await walletManager.getEstimatedBlockHeight()
            nextRoundStartTime = try? await walletManager.nextRoundStartTime()
        } catch {
            print("BalanceRefreshStatusViewModel: \(error)")
        }
        hasCompletedInitialLoad = true
    }
    
    // MARK: - Utilities
    
    func formatTimeInterval(_ seconds: Int) -> String {
        if seconds < 60 { return "< 1m" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(seconds)) ?? "< 1m"
    }
}
