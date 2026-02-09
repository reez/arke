//
//  BalanceRefreshStatus.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/24/25.
//

import SwiftUI

struct BalanceRefreshStatus: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var vtxos: [VTXOModel] = []
    @State private var latestBlockHeight: Int?
    @State private var updateTimer: Timer?
    @State private var isLoading = false
    @State private var hasCompletedInitialLoad = false
    
    /// Callback to execute when refresh button is tapped
    var onRefresh: (() async -> Void)?
    
    // MARK: - Computed Properties
    
    /// Filter out spent VTXOs - only consider active ones
    private var activeVTXOs: [VTXOModel] {
        vtxos.filter { $0.state != .spent }
    }
    
    /// Find the VTXO that will expire soonest
    private var nextExpiryVTXO: VTXOModel? {
        guard let blockHeight = latestBlockHeight else { return nil }
        
        return activeVTXOs.min { vtxo1, vtxo2 in
            let rounds1 = vtxo1.expiryHeight - blockHeight
            let rounds2 = vtxo2.expiryHeight - blockHeight
            return rounds1 < rounds2
        }
    }
    
    /// Calculate seconds until the next VTXO expires
    private var secondsUntilNextExpiry: Int? {
        guard let vtxo = nextExpiryVTXO,
              let blockHeight = latestBlockHeight else {
            return nil
        }
        
        let roundsUntilExpiry = vtxo.expiryHeight - blockHeight
        let secondsPerRound = walletManager.arkInfo?.roundIntervalSeconds ?? 30
        return roundsUntilExpiry * secondsPerRound
    }
    
    /// Get status message based on urgency level
    private var statusMessage: String {
        switch urgencyLevel {
        case .expired:
            return "Critical"
        case .critical:
            return "Urgent"
        case .warning:
            return "Recommended"
        case .normal:
            return "Optional"
        case .safe:
            return "Not needed"
        case .none:
            return "Not needed"
        }
    }
    
    /// Determine the urgency level based on time until expiry
    private var urgencyLevel: RefreshUrgency {
        guard let blockHeight = latestBlockHeight else { return .none }
        guard let vtxoLifespan = walletManager.arkInfo?.vtxoExpiryDelta else {
            return .none // Can't calculate without knowing total lifespan
        }
        
        return RefreshUrgency.calculateOverallUrgency(
            for: vtxos,
            currentBlockHeight: blockHeight,
            vtxoLifespan: vtxoLifespan
        )
    }
    
    /// Button label based on urgency
    private var buttonLabel: String {
        return "Start"
    }
    
    /// Button color based on urgency
    private var buttonColor: Color {
        switch urgencyLevel {
        case .expired, .critical:
            return .red
        case .warning:
            return .yellow
        default:
            return .yellow
        }
    }
    
    /// Count of VTXOs that need urgent attention (< 24 hours)
    private var urgentVTXOCount: Int {
        guard let blockHeight = latestBlockHeight else { return 0 }
        let secondsPerRound = walletManager.arkInfo?.roundIntervalSeconds ?? 30
        
        return activeVTXOs.filter { vtxo in
            let roundsUntilExpiry = vtxo.expiryHeight - blockHeight
            let secondsUntilExpiry = roundsUntilExpiry * secondsPerRound
            let hoursUntilExpiry = secondsUntilExpiry / 3600
            return hoursUntilExpiry < 24
        }.count
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if hasCompletedInitialLoad {
                contentView
            } else {
                loadingView
            }
        }
        .task {
            await loadData()
        }
        .onAppear {
            startBlockHeightUpdater()
            // Debug: Check for active refresh operations
            Task {
                await checkForActiveRefresh()
            }
        }
        .onDisappear {
            stopBlockHeightUpdater()
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise")
                .font(.title3)
                .foregroundColor(.gray)
                .frame(width: 32, height: 32)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Payments balance refresh")
                    .font(.body)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
                Text("Loading...")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            ProgressView()
                .controlSize(.small)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 15)
        .background(.gray.opacity(0.1))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(urgencyLevel.color)
                    .cornerRadius(8)
                
                Text("Payments balance refresh")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 15)
            .padding(.top, 15)
            .padding(.bottom, 15)
            
            // Content based on state
            if hasActiveRefresh {
                refreshingContent
            } else if urgencyLevel == .none {
                emptyStateContent
            } else {
                timeDisplayContent
            }
        }
        .background(Color(white: 0.95))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private var refreshingContent: some View {
        VStack(spacing: 8) {
            Text("Refreshing...")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 15)
    }
    
    @ViewBuilder
    private var emptyStateContent: some View {
        VStack(spacing: 8) {
            Text("Not needed for empty balance")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 15)
    }
    
    @ViewBuilder
    private var timeDisplayContent: some View {
        VStack(spacing: 15) {
            if urgencyLevel == .expired {
                expiredContent
            } else {
                timesContent
            }
            
            // Action button
            if urgencyLevel != .none {
                Button {
                    Task {
                        await onRefresh?()
                    }
                } label: {
                    Text(buttonLabel)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.arkeDark)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
                .tint(Color.arkeGold)
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 15)
    }
    
    @ViewBuilder
    private var expiredContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Status")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Text(statusMessage)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            if let expirySeconds = secondsUntilNextExpiry {
                Text("Expired \(formatTimeInterval(abs(expirySeconds))) ago")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var timesContent: some View {
        HStack(spacing: 20) {
            // Status
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Text(statusMessage)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Time until expiry
            VStack(alignment: .leading, spacing: 4) {
                Text("Time until expiry")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                if let expirySeconds = secondsUntilNextExpiry {
                    Text(formatTimeInterval(abs(expirySeconds)))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Format time interval into human-readable string
    private func formatTimeInterval(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        
        // For very short durations, show "< 1m"
        if seconds < 60 {
            return "< 1m"
        }
        
        return formatter.string(from: TimeInterval(seconds)) ?? "< 1m"
    }
    
    /// Load VTXOs and block height
    private func loadData() async {
        print("BalanceRefreshStatus loadData")
        isLoading = true
        
        do {
            vtxos = try await walletManager.getVTXOs()
            latestBlockHeight = await walletManager.getEstimatedBlockHeight()
        } catch {
            print("BalanceRefreshStatus: Error loading VTXO data for refresh status: \(error)")
        }
        
        isLoading = false
        hasCompletedInitialLoad = true
    }
    
    /// Start timer to update block height every 30 seconds
    private func startBlockHeightUpdater() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                latestBlockHeight = await walletManager.getEstimatedBlockHeight()
            }
        }
    }
    
    /// Stop the update timer
    private func stopBlockHeightUpdater() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// Debug method to check for active refresh operations
    private func checkForActiveRefresh() async {
        print("🔍 [BalanceRefreshStatus] Checking for active refresh operations...")
        
        // Option 1: Check pendingRoundStates
        var pendingRoundsCount = 0
        do {
            let pendingRounds = try await walletManager.pendingRoundStates()
            pendingRoundsCount = pendingRounds.count
            print("   📋 Pending round states: \(pendingRounds.count)")
            for (index, round) in pendingRounds.enumerated() {
                print("      [\(index)] Round: \(round)")
            }
            
            // Note: RoundState doesn't directly indicate operation type
            // We need to use transaction history instead
        } catch {
            print("   ⚠️ Error checking pending round states: \(error)")
        }
        
        // Option 2: Check transaction history for incomplete refresh transactions
        let refreshTransactions = walletManager.transactions.filter { transaction in
            // Check if it's a refresh transaction
            guard let category = transaction.category else { return false }
            return category == .refresh
        }
        
        print("   📊 Refresh transactions in history: \(refreshTransactions.count)")
        for (index, tx) in refreshTransactions.enumerated() {
            print("      [\(index)] Status: \(tx.status.displayName), Date: \(tx.formattedDate)")
        }
        
        // Check for pending refresh transactions
        let pendingRefreshTransactions = refreshTransactions.filter { $0.status == .pending }
        print("   ⏳ Pending refresh transactions: \(pendingRefreshTransactions.count)")
        
        if !pendingRefreshTransactions.isEmpty {
            print("   ✅ There IS an active payments balance refresh!")
        } else if pendingRoundsCount > 0 {
            print("   ℹ️ There are pending rounds, but they're not refresh operations")
        } else {
            print("   ✅ No active refresh operations detected")
        }
    }
    
    /// Check if there is currently an active payments balance refresh
    /// Returns true if there are pending refresh transactions in the transaction history
    private var hasActiveRefresh: Bool {
        walletManager.transactions.contains { transaction in
            transaction.category == .refresh && transaction.status == .pending
        }
    }
}

// MARK: - Previews

/// Preview wrapper that allows us to inject custom state
private struct BalanceRefreshStatusPreview: View {
    let vtxos: [VTXOModel]
    let blockHeight: Int
    let vtxoExpiryDelta: Int
    
    var body: some View {
        BalanceRefreshStatusWithData(vtxos: vtxos, blockHeight: blockHeight, vtxoExpiryDelta: vtxoExpiryDelta)
            .environment(WalletManager(useMock: true))
            .padding()
            .frame(width: 450)
    }
}

/// Version of BalanceRefreshStatus that accepts injected data for previews
private struct BalanceRefreshStatusWithData: View {
    let vtxos: [VTXOModel]
    let blockHeight: Int
    let vtxoExpiryDelta: Int
    @Environment(WalletManager.self) private var walletManager
    @State private var updateTimer: Timer?
    
    private var activeVTXOs: [VTXOModel] {
        vtxos.filter { $0.state != .spent }
    }
    
    private var nextExpiryVTXO: VTXOModel? {
        activeVTXOs.min { vtxo1, vtxo2 in
            let rounds1 = vtxo1.expiryHeight - blockHeight
            let rounds2 = vtxo2.expiryHeight - blockHeight
            return rounds1 < rounds2
        }
    }
    
    private var secondsUntilNextExpiry: Int? {
        guard let vtxo = nextExpiryVTXO else { return nil }
        let roundsUntilExpiry = vtxo.expiryHeight - blockHeight
        let secondsPerRound = walletManager.arkInfo?.roundIntervalSeconds ?? 30
        return roundsUntilExpiry * secondsPerRound
    }
    
    private var urgencyLevel: RefreshUrgency {
        RefreshUrgency.calculateOverallUrgency(
            for: vtxos,
            currentBlockHeight: blockHeight,
            vtxoLifespan: vtxoExpiryDelta
        )
    }
    
    private var statusMessage: String {
        switch urgencyLevel {
        case .expired:
            return "Balance expired"
        case .critical:
            return "Refresh urgently needed"
        case .warning:
            return "Refresh recommended"
        case .normal:
            return "Refresh available"
        case .safe:
            return "No action needed"
        case .none:
            return "Not needed for empty balance"
        }
    }
    
    private var buttonLabel: String {
        return "Start"
    }
    
    private var buttonColor: Color {
        switch urgencyLevel {
        case .expired, .critical:
            return .red
        case .warning:
            return .yellow
        default:
            return .yellow
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(urgencyLevel.color)
                    .cornerRadius(8)
                
                Text("Payments balance refresh")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 15)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Content based on state
            if urgencyLevel == .none {
                emptyStateContent
            } else if urgencyLevel == .expired {
                expiredContent
            } else {
                timesContent
            }
            
            // Action button
            if urgencyLevel != .none {
                Button(action: {}) {
                    Text(buttonLabel)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(buttonColor)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 15)
                .padding(.bottom, 12)
            }
        }
        .background(Color(white: 0.95))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private var emptyStateContent: some View {
        VStack(spacing: 8) {
            Text("Not needed for empty balance")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var expiredContent: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Text(statusMessage)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                if let expirySeconds = secondsUntilNextExpiry {
                    Text("Expired \(formatTimeInterval(abs(expirySeconds))) ago")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 15)
    }
    
    @ViewBuilder
    private var timesContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Status
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    Text(statusMessage)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Time until expiry
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time until expiry")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    if let expirySeconds = secondsUntilNextExpiry {
                        Text(formatTimeInterval(abs(expirySeconds)))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 15)
    }
    
    private func formatTimeInterval(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        
        if seconds < 60 {
            return "< 1m"
        }
        
        return formatter.string(from: TimeInterval(seconds)) ?? "< 1m"
    }
}

#Preview("Safe - 10 days") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.80) // 80% remaining - safe
    
    let vtxos = [
        VTXOModel(
            id: "safe123:0",
            amountSat: 10000,
            policyType: .pubkey,
            userPubkey: "03abc",
            serverPubkey: "02def",
            expiryHeight: currentBlock + blocksRemaining,
            exitDelta: 12,
            chainAnchor: "anchor:0",
            exitDepth: 1,
            arkoorDepth: 0,
            state: .spendable
        )
    ]
    
    return BalanceRefreshStatusPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Normal - 5 days") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.40) // 40% remaining - normal
    
    let vtxos = [
        VTXOModel(
            id: "normal123:0",
            amountSat: 15000,
            policyType: .pubkey,
            userPubkey: "03abc",
            serverPubkey: "02def",
            expiryHeight: currentBlock + blocksRemaining,
            exitDelta: 12,
            chainAnchor: "anchor:0",
            exitDepth: 1,
            arkoorDepth: 0,
            state: .spendable
        )
    ]
    
    return BalanceRefreshStatusPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Warning - 2 days") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.20) // 20% remaining - warning
    
    let vtxos = [
        VTXOModel(
            id: "warning123:0",
            amountSat: 20000,
            policyType: .pubkey,
            userPubkey: "03abc",
            serverPubkey: "02def",
            expiryHeight: currentBlock + blocksRemaining,
            exitDelta: 12,
            chainAnchor: "anchor:0",
            exitDepth: 1,
            arkoorDepth: 0,
            state: .spendable
        )
    ]
    
    return BalanceRefreshStatusPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Critical - 12 hours") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.05) // 5% remaining - critical
    
    let vtxos = [
        VTXOModel(
            id: "critical123:0",
            amountSat: 25000,
            policyType: .pubkey,
            userPubkey: "03abc",
            serverPubkey: "02def",
            expiryHeight: currentBlock + blocksRemaining,
            exitDelta: 12,
            chainAnchor: "anchor:0",
            exitDepth: 1,
            arkoorDepth: 0,
            state: .spendable
        )
    ]
    
    return BalanceRefreshStatusPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Expired") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    
    let vtxos = [
        VTXOModel(
            id: "expired123:0",
            amountSat: 5000,
            policyType: .pubkey,
            userPubkey: "03abc",
            serverPubkey: "02def",
            expiryHeight: currentBlock - 10, // Already expired 10 blocks ago
            exitDelta: 12,
            chainAnchor: "anchor:0",
            exitDepth: 1,
            arkoorDepth: 0,
            state: .spendable
        )
    ]
    
    return BalanceRefreshStatusPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Multiple Urgent") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.08) // 8% remaining - critical
    
    let vtxos = [
        VTXOModel(
            id: "urgent1:0",
            amountSat: 5000,
            policyType: .pubkey,
            userPubkey: "03abc",
            serverPubkey: "02def",
            expiryHeight: currentBlock + blocksRemaining,
            exitDelta: 12,
            chainAnchor: "anchor:0",
            exitDepth: 1,
            arkoorDepth: 0,
            state: .spendable
        ),
        VTXOModel(
            id: "urgent2:0",
            amountSat: 8000,
            policyType: .pubkey,
            userPubkey: "03abc",
            serverPubkey: "02def",
            expiryHeight: currentBlock + blocksRemaining + 5,
            exitDelta: 12,
            chainAnchor: "anchor:0",
            exitDepth: 1,
            arkoorDepth: 0,
            state: .spendable
        ),
        VTXOModel(
            id: "urgent3:0",
            amountSat: 12000,
            policyType: .pubkey,
            userPubkey: "03abc",
            serverPubkey: "02def",
            expiryHeight: currentBlock + blocksRemaining + 10,
            exitDelta: 12,
            chainAnchor: "anchor:0",
            exitDepth: 1,
            arkoorDepth: 0,
            state: .spendable
        )
    ]
    
    return BalanceRefreshStatusPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("No VTXOs") {
    BalanceRefreshStatusPreview(vtxos: [], blockHeight: 274000, vtxoExpiryDelta: 144)
}
