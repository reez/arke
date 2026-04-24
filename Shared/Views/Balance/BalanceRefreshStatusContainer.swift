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
    @State private var viewModel: BalanceRefreshStatusViewModel?
    @State private var updateTimer: Timer?
    
    var onRefresh: (() async -> Void)?
    var reloadTrigger: Int = 0
    
    var body: some View {
        BalanceRefreshStatus(data: makeData())
            .task { 
                if viewModel == nil {
                    viewModel = BalanceRefreshStatusViewModel(walletManager: walletManager)
                }
                await viewModel?.loadData()
            }
            .onAppear { startBlockHeightUpdater() }
            .onDisappear { stopBlockHeightUpdater() }
            .onChange(of: reloadTrigger) { _, _ in
                Task {
                    await viewModel?.loadData()
                }
            }
            .onChange(of: walletManager.transactionVersion) { _, _ in
                Task {
                    await viewModel?.loadData()
                }
            }
    }
    
    private func makeData() -> BalanceRefreshData {
        guard let viewModel = viewModel, viewModel.hasCompletedInitialLoad else {
            return BalanceRefreshData(isLoading: true)
        }
        
        let urgency = viewModel.urgencyLevel
        
        return BalanceRefreshData(
            isLoading: false,
            hasActiveRefresh: viewModel.hasActiveRefresh,
            urgencyForegroundColor: urgency.foregroundColor,
            urgencyBackgroundColor: urgency.backgroundColor,
            urgencyIconColor: urgency.iconColor,
            statusMessage: urgency == .none ? "" : statusMessage(for: urgency),
            timeUntilExpiry: viewModel.secondsUntilNextExpiry.map { viewModel.formatTimeInterval(abs($0)) },
            isExpired: urgency == .expired,
            expiredAgoString: urgency == .expired
                ? viewModel.secondsUntilNextExpiry.map { viewModel.formatTimeInterval(abs($0)) }
                : nil,
            showActionButton: urgency != .none,
            nextRoundStartTime: viewModel.nextRoundStartTime,
            totalAmountToRefresh: viewModel.totalAmountToRefresh > 0 ? viewModel.totalAmountToRefresh : nil,
            onRefresh: onRefresh
        )
    }
    
    private func statusMessage(for urgency: RefreshUrgency) -> String {
        switch urgency {
        case .expired: return "Critical"
        case .critical: return "Urgent"
        case .warning: return "Recommended"
        case .normal: return "Optional"
        default: return "Not needed"
        }
    }
    
    private func startBlockHeightUpdater() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                viewModel?.latestBlockHeight = await walletManager.getEstimatedBlockHeight()
            }
        }
    }
    
    private func stopBlockHeightUpdater() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}
