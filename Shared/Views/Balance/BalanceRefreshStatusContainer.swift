//
//  BalanceRefreshStatusContainer.swift
//  Arke
//
//  Created by Christoph on 2/23/26.
//

import SwiftUI
import ArkeUI

struct BalanceRefreshStatusContainer: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var vtxos: [VTXOModel] = []
    @State private var latestBlockHeight: Int?
    @State private var updateTimer: Timer?
    @State private var hasCompletedInitialLoad = false
    
    var onRefresh: (() async -> Void)?
    
    var body: some View {
        BalanceRefreshStatus(data: makeData())
            .task { await loadData() }
            .onAppear { startBlockHeightUpdater() }
            .onDisappear { stopBlockHeightUpdater() }
    }
    
    private func makeData() -> BalanceRefreshData {
        guard hasCompletedInitialLoad else {
            return BalanceRefreshData(isLoading: true)
        }
        
        let urgency = urgencyLevel
        
        return BalanceRefreshData(
            isLoading: false,
            hasActiveRefresh: hasActiveRefresh,
            urgencyColor: urgency.color,
            statusMessage: urgency == .none ? "" : statusMessage,
            timeUntilExpiry: secondsUntilNextExpiry.map { formatTimeInterval(abs($0)) },
            isExpired: urgency == .expired,
            expiredAgoString: urgency == .expired
                ? secondsUntilNextExpiry.map { formatTimeInterval(abs($0)) }
                : nil,
            showActionButton: urgency != .none,
            nextRoundStartTime: try? walletManager.nextRoundStartTime(),
            onRefresh: onRefresh
        )
    }
    
    // MARK: - Computed properties (same logic as before)
    
    private var activeVTXOs: [VTXOModel] {
        vtxos.filter { $0.state != .spent }
    }
    
    private var urgencyLevel: RefreshUrgency {
        guard let blockHeight = latestBlockHeight,
              let vtxoLifespan = walletManager.arkInfo?.vtxoExpiryDelta else {
            return .none
        }
        return RefreshUrgency.calculateOverallUrgency(
            for: vtxos,
            currentBlockHeight: blockHeight,
            vtxoLifespan: vtxoLifespan
        )
    }
    
    private var secondsUntilNextExpiry: Int? {
        guard let blockHeight = latestBlockHeight else { return nil }
        let nextExpiry = activeVTXOs.min {
            ($0.expiryHeight - blockHeight) < ($1.expiryHeight - blockHeight)
        }
        guard let vtxo = nextExpiry else { return nil }
        let secondsPerRound = walletManager.arkInfo?.roundIntervalSeconds ?? 30
        return (vtxo.expiryHeight - blockHeight) * secondsPerRound
    }
    
    private var statusMessage: String {
        switch urgencyLevel {
        case .expired: return "Critical"
        case .critical: return "Urgent"
        case .warning: return "Recommended"
        case .normal: return "Optional"
        default: return "Not needed"
        }
    }
    
    private var hasActiveRefresh: Bool {
        walletManager.transactions.contains {
            $0.category == .refresh && $0.status == .pending
        }
    }
    
    // MARK: - Data loading (same as before)
    
    private func loadData() async {
        do {
            vtxos = try await walletManager.getVTXOs()
            latestBlockHeight = await walletManager.getEstimatedBlockHeight()
        } catch {
            print("BalanceRefreshStatusContainer: \(error)")
        }
        hasCompletedInitialLoad = true
    }
    
    private func startBlockHeightUpdater() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                latestBlockHeight = await walletManager.getEstimatedBlockHeight()
            }
        }
    }
    
    private func stopBlockHeightUpdater() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func formatTimeInterval(_ seconds: Int) -> String {
        if seconds < 60 { return "< 1m" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(seconds)) ?? "< 1m"
    }
}
