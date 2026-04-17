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
    @State private var vtxos: [VTXOModel] = []
    @State private var latestBlockHeight: Int?
    @State private var nextRoundStartTime: UInt64?
    @State private var updateTimer: Timer?
    @State private var hasCompletedInitialLoad = false
    @State private var currentTime = Date()
    
    var onRefresh: (() async -> Void)?
    var reloadTrigger: Int = 0
    
    var body: some View {
        BalanceRefreshStatusCompact(data: makeData(), currentTime: currentTime)
            .task { await loadData() }
            .onAppear { startBlockHeightUpdater() }
            .onDisappear { stopBlockHeightUpdater() }
            .onChange(of: reloadTrigger) { _, _ in
                Task {
                    await loadData()
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                currentTime = Date()
            }
    }
    
    private func makeData() -> BalanceRefreshData {
        guard hasCompletedInitialLoad else {
            return BalanceRefreshData(isLoading: true)
        }
        
        let urgency = urgencyLevel
        
        return BalanceRefreshData(
            isLoading: false,
            hasActiveRefresh: hasActiveRefresh,
            urgencyForegroundColor: urgency.foregroundColor,
            urgencyBackgroundColor: urgency.backgroundColor,
            urgencyIconColor: urgency.iconColor,
            statusMessage: urgency == .none ? "" : statusMessage,
            timeUntilExpiry: secondsUntilNextExpiry.map { formatTimeInterval(abs($0)) },
            isExpired: urgency == .expired,
            expiredAgoString: urgency == .expired
                ? secondsUntilNextExpiry.map { formatTimeInterval(abs($0)) }
                : nil,
            showActionButton: urgency != .none,
            nextRoundStartTime: nextRoundStartTime,
            totalAmountToRefresh: totalAmountToRefresh > 0 ? totalAmountToRefresh : nil,
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
        case .expired: return "Refresh critical now"
        case .critical: return "Refresh urgent now"
        case .warning: return "Refresh recommended now"
        case .normal: return "Refresh optional now"
        default: return "Refresh in"
        }
    }
    
    private var hasActiveRefresh: Bool {
        walletManager.transactions.contains {
            $0.category == .refresh && $0.status == .pending
        }
    }
    
    /// Returns the total amount (in satoshis) of VTXOs that should be refreshed
    /// based on the current urgency level
    private var totalAmountToRefresh: Int {
        guard let blockHeight = latestBlockHeight,
              let vtxoLifespan = walletManager.arkInfo?.vtxoExpiryDelta else {
            return 0
        }
        
        let vtxosToRefresh = RefreshUrgency.vtxosNeedingRefresh(
            from: vtxos,
            currentBlockHeight: blockHeight,
            vtxoLifespan: vtxoLifespan
        )
        
        return vtxosToRefresh.reduce(0) { $0 + $1.amountSat }
    }
    
    // MARK: - Data loading (same as before)
    
    private func loadData() async {
        do {
            vtxos = try await walletManager.getVTXOs()
            latestBlockHeight = await walletManager.getEstimatedBlockHeight()
            nextRoundStartTime = try? await walletManager.nextRoundStartTime()
        } catch {
            print("BalanceRefreshStatusContainerCompact: \(error)")
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

// MARK: - Compact View

struct BalanceRefreshStatusCompact: View {
    let data: BalanceRefreshData
    let currentTime: Date
    
    private var timeUntilNextRound: String? {
        guard let nextRoundTimestamp = data.nextRoundStartTime else {
            return nil
        }
        
        let currentTimeValue = UInt64(currentTime.timeIntervalSince1970)
        
        guard nextRoundTimestamp > currentTimeValue else {
            return nil  // Round has passed
        }
        
        let secondsUntilRound = Int(nextRoundTimestamp - currentTimeValue)
        return formatTimeInterval(secondsUntilRound)
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
    
    var body: some View {
        Group {
            if data.isLoading {
                loadingView
            } else {
                contentView
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let onRefresh = data.onRefresh {
                Task {
                    await onRefresh()
                }
            }
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise")
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.15))
                .cornerRadius(6)
            
            Text("Loading...")
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.white)
            
            Spacer()
            
            ProgressView()
                .controlSize(.small)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 20)
        #if os(iOS)
        .background(Color(.white).opacity(0.15))
        #else
        .background(Color(white: 0.949))
        #endif
    }
    
    @ViewBuilder
    private var contentView: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "arrow.clockwise")
                .font(.body)
                .foregroundStyle(data.urgencyIconColor)
                .frame(width: 28, height: 28)
                .background(data.urgencyForegroundColor)
                .cornerRadius(6)
            
            // Status text on the left
            if data.hasActiveRefresh {
                Text("Refreshing")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(data.urgencyForegroundColor)
            } else if data.statusMessage.isEmpty {
                Text("Not needed")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(data.urgencyForegroundColor)
            } else {
                Text(data.statusMessage)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(data.urgencyForegroundColor)
            }
            
            Spacer()
            
            // Time on the right
            if data.hasActiveRefresh {
                if let nextRound = timeUntilNextRound {
                    HStack(spacing: 4) {
                        Text("Next round")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(data.urgencyForegroundColor)
                        Text(nextRound)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(data.urgencyForegroundColor)
                    }
                }
            } else if !data.statusMessage.isEmpty {
                if data.isExpired, let ago = data.expiredAgoString {
                    Text("\(ago) ago")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(data.urgencyForegroundColor)
                } else if let expiry = data.timeUntilExpiry {
                    Text(expiry)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(data.urgencyForegroundColor)
                }
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 20)
        #if os(iOS)
        .background(data.urgencyBackgroundColor)
        #else
        .background(Color(white: 0.949))
        #endif
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
