//
//  BalanceRefreshStatus.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/24/25.
//

import SwiftUI
import Combine

struct BalanceRefreshTag: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var vtxos: [VTXOModel] = []
    @State private var latestBlockHeight: Int?
    @State private var updateTimer: Timer?
    @State private var isLoading = false
    @State private var urgencyLevel: RefreshUrgency = .none
    
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
    
    /// Generate the display message based on urgency
    private var displayMessage: String {
        guard let seconds = secondsUntilNextExpiry else {
            return "Calculating..."
        }
        
        // Check urgency level first
        switch urgencyLevel {
        case .expired:
            return "Refresh needed"
        case .critical:
            let timeString = formatTimeInterval(abs(seconds))
            return "Refresh in \(timeString)"
        case .warning:
            let timeString = formatTimeInterval(abs(seconds))
            return "Refresh in \(timeString)"
        default:
            return ""
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
            if urgencyLevel == .warning || urgencyLevel == .critical || urgencyLevel == .expired {
                contentView
            } else {
                Color.clear
                    .frame(width: 0, height: 0)
            }
        }
        .task {
            await loadData()
        }
        .onAppear {
            startBlockHeightUpdater()
        }
        .onDisappear {
            stopBlockHeightUpdater()
        }
        .onChange(of: vtxos) { _, _ in
            updateUrgencyLevel()
        }
        .onChange(of: latestBlockHeight) { _, _ in
            updateUrgencyLevel()
        }
        .onChange(of: walletManager.arkInfo) { _, _ in
            updateUrgencyLevel()
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        HStack(spacing: 8) {
            //iconView
            messageView
            
            if isLoading {
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.arkeGold)
        .cornerRadius(5)
    }
    
    private var iconView: some View {
        Image(systemName: urgencyLevel.iconName)
            .foregroundStyle(urgencyLevel.color)
            .font(.system(size: 14, weight: .semibold))
            .imageScale(.medium)
    }
    
    private var messageView: some View {
        Text(displayMessage)
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(.black)
            //.foregroundStyle(urgencyLevel.color)
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
        isLoading = true
        
        do {
            vtxos = try await walletManager.getVTXOs()
            latestBlockHeight = await walletManager.getEstimatedBlockHeight()
            updateUrgencyLevel()
        } catch {
            print("Error loading VTXO data for refresh status: \(error)")
        }
        
        isLoading = false
    }
    
    /// Update the urgency level based on current state
    private func updateUrgencyLevel() {
        guard let blockHeight = latestBlockHeight,
              let vtxoLifespan = walletManager.arkInfo?.vtxoExpiryDelta else {
            urgencyLevel = .none
            return
        }
        
        urgencyLevel = RefreshUrgency.calculateOverallUrgency(
            for: vtxos,
            currentBlockHeight: blockHeight,
            vtxoLifespan: vtxoLifespan
        )
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
}

// MARK: - Previews

/// Preview wrapper that allows us to inject custom state
private struct BalanceRefreshTagPreview: View {
    let vtxos: [VTXOModel]
    let blockHeight: Int
    let vtxoExpiryDelta: Int
    
    var body: some View {
        BalanceRefreshTagWithData(vtxos: vtxos, blockHeight: blockHeight, vtxoExpiryDelta: vtxoExpiryDelta)
            .environment(WalletManager(useMock: true))
            .padding()
            .frame(width: 450)
    }
}

/// Version of BalanceRefreshStatus that accepts injected data for previews
private struct BalanceRefreshTagWithData: View {
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
    
    private var displayMessage: String {
        guard !activeVTXOs.isEmpty else {
            return "No refresh needed for an empty payments balance"
        }
        
        guard let seconds = secondsUntilNextExpiry else {
            return "Calculating..."
        }
        
        let timeString = formatTimeInterval(abs(seconds))
        
        switch urgencyLevel {
        case .expired:
            return "Refresh needed now"
        case .critical:
            return "Refresh needed in \(timeString)"
        case .warning:
            return "Refresh recommended in \(timeString)"
        case .normal:
            return "Refresh in \(timeString)"
        case .safe:
            return "Next refresh in \(timeString)"
        case .none:
            return "No refresh needed for an empty payments balance"
        }
    }
    
    private var urgentVTXOCount: Int {
        let secondsPerRound = walletManager.arkInfo?.roundIntervalSeconds ?? 30
        
        return activeVTXOs.filter { vtxo in
            let roundsUntilExpiry = vtxo.expiryHeight - blockHeight
            let secondsUntilExpiry = roundsUntilExpiry * secondsPerRound
            let hoursUntilExpiry = secondsUntilExpiry / 3600
            return hoursUntilExpiry < 24
        }.count
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: urgencyLevel.iconName)
                .foregroundStyle(urgencyLevel.color)
                .font(.system(size: 14, weight: .semibold))
                .imageScale(.medium)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayMessage)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(urgencyLevel == .none ? .secondary : .primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(urgencyLevel == .critical ? Color.red.opacity(0.1) : Color.clear)
        .cornerRadius(8)
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

#Preview("Safe - 80% lifespan remaining") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.80) // 80% remaining
    
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
    
    return BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Normal - 40% lifespan remaining") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.40) // 40% remaining
    
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
    
    return BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Warning - 20% lifespan remaining") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.20) // 20% remaining
    
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
    
    return BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Critical - 5% lifespan remaining") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.05) // 5% remaining
    
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
    
    return BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
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
    
    return BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
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
    
    return BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("No VTXOs") {
    BalanceRefreshTagPreview(vtxos: [], blockHeight: 274000, vtxoExpiryDelta: 144)
}
