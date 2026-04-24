//
//  BalanceRefreshStatusContainerCompact.swift
//  Arke
//
//  Created by Christoph on 4/16/26.
//

import SwiftUI
import ArkeUI
import Combine

struct BalanceRefreshStatusContainerCompact: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel: BalanceRefreshStatusViewModel?
    @State private var updateTimer: Timer?
    @State private var currentTime = Date()
    
    var onRefresh: (() async -> Void)?
    var reloadTrigger: Int = 0
    
    var body: some View {
        BalanceRefreshStatusCompact(data: makeData(), currentTime: currentTime)
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
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                currentTime = Date()
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
        case .expired: return "Refresh critical now"
        case .critical: return "Refresh urgent now"
        case .warning: return "Refresh recommended now"
        case .normal: return "Refresh optional now"
        default: return "Refresh in"
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

// MARK: - Previews

#Preview("Loading") {
    BalanceRefreshStatusCompact(
        data: BalanceRefreshData(isLoading: true),
        currentTime: Date()
    )
    .padding()
}

#Preview("Empty balance") {
    BalanceRefreshStatusCompact(
        data: BalanceRefreshData(
            urgencyBackgroundColor: .gray,
            statusMessage: ""
        ),
        currentTime: Date()
    )
    .padding()
}

#Preview("Warning") {
    BalanceRefreshStatusCompact(
        data: BalanceRefreshData(
            urgencyBackgroundColor: .Arke.yellow,
            statusMessage: "Recommended",
            timeUntilExpiry: "2d 3h",
            showActionButton: true,
            nextRoundStartTime: UInt64(Date().timeIntervalSince1970) + 1800
        ),
        currentTime: Date()
    )
    .padding()
}

#Preview("Critical") {
    BalanceRefreshStatusCompact(
        data: BalanceRefreshData(
            urgencyBackgroundColor: .Arke.red,
            statusMessage: "Urgent",
            timeUntilExpiry: "12h 4m",
            showActionButton: true,
            nextRoundStartTime: UInt64(Date().timeIntervalSince1970) + 300
        ),
        currentTime: Date()
    )
    .padding()
}

#Preview("Expired") {
    BalanceRefreshStatusCompact(
        data: BalanceRefreshData(
            urgencyBackgroundColor: .Arke.red,
            statusMessage: "Critical",
            isExpired: true,
            expiredAgoString: "2h 15m",
            showActionButton: true,
            nextRoundStartTime: UInt64(Date().timeIntervalSince1970) + 300
        ),
        currentTime: Date()
    )
    .padding()
}

#Preview("Refreshing") {
    BalanceRefreshStatusCompact(
        data: BalanceRefreshData(
            hasActiveRefresh: true,
            urgencyBackgroundColor: .Arke.blue,
            nextRoundStartTime: UInt64(Date().timeIntervalSince1970) + 300
        ),
        currentTime: Date()
    )
    .padding()
}
