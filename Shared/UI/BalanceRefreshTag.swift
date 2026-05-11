//
//  BalanceRefreshStatus.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/24/25.
//

import SwiftUI
import ArkeUI
import Combine
import OSLog

struct BalanceRefreshTag: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var vtxos: [VTXOModel] = []
    @State private var latestBlockHeight: Int?
    @State private var updateTimer: Timer?
    @State private var isLoading = false
    @State private var urgencyLevel: RefreshUrgency = .none
    @State private var hasCompletedInitialLoad = false
    @State private var hasActiveRefresh = false
    
    /// Logger for balance refresh tag operations
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.arke", category: "BalanceRefreshTag")
    
    // MARK: - Computed Properties
    
    /// Filter out spent VTXOs - only consider active ones
    private var activeVTXOs: [VTXOModel] {
        vtxos.filter { $0.state != .spent }
    }
    
    /// Find the VTXO that will expire soonest
    private var nextExpiryVTXO: VTXOModel? {
        guard let blockHeight = latestBlockHeight else { return nil }
        
        return activeVTXOs.min { vtxo1, vtxo2 in
            let blocks1 = vtxo1.expiryHeight - blockHeight
            let blocks2 = vtxo2.expiryHeight - blockHeight
            return blocks1 < blocks2
        }
    }
    
    /// Calculate seconds until the next VTXO expires
    private var secondsUntilNextExpiry: Int? {
        guard let vtxo = nextExpiryVTXO,
              let blockHeight = latestBlockHeight else {
            return nil
        }
        
        let blocksUntilExpiry = vtxo.expiryHeight - blockHeight
        let secondsPerBlock = 600 // 10 minutes per block
        return blocksUntilExpiry * secondsPerBlock
    }
    
    /// Generate the display message based on urgency
    private var displayMessage: String {
        Self.logger.debug("displayMessage computation: vtxos=\(self.vtxos.count), activeVTXOs=\(self.activeVTXOs.count), blockHeight=\(String(describing: self.latestBlockHeight)), nextExpiryVTXO=\(self.nextExpiryVTXO?.id ?? "nil"), secondsUntilExpiry=\(String(describing: self.secondsUntilNextExpiry)), urgency=\(String(describing: self.urgencyLevel))")
        
        guard secondsUntilNextExpiry != nil else {
            Self.logger.debug("returning: Calculating...")
            return String(localized: "status_calculating")
        }
        
        // Check urgency level first
        let message: String
        switch urgencyLevel {
        case .expired:
            message = "Refresh now"
        case .critical:
            message = "Refresh now"
        case .warning:
            message = "Refresh now"
        default:
            message = ""
        }
        
        Self.logger.debug("returning: \(message)")
        return message
    }
    
    /// Count of VTXOs that need urgent attention (< 24 hours)
    private var urgentVTXOCount: Int {
        guard let blockHeight = latestBlockHeight else { return 0 }
        let secondsPerBlock = 600 // 10 minutes per block
        
        return activeVTXOs.filter { vtxo in
            let blocksUntilExpiry = vtxo.expiryHeight - blockHeight
            let secondsUntilExpiry = blocksUntilExpiry * secondsPerBlock
            let hoursUntilExpiry = secondsUntilExpiry / 3600
            return hoursUntilExpiry < 24
        }.count
    }
    
    // MARK: - Body
    
    var body: some View {
        let shouldShow = hasCompletedInitialLoad && !hasActiveRefresh && (urgencyLevel == .warning || urgencyLevel == .critical || urgencyLevel == .expired)

        let _ = Self.logger.debug("Visibility check: hasCompletedInitialLoad=\(self.hasCompletedInitialLoad), hasActiveRefresh=\(self.hasActiveRefresh), urgency=\(String(describing: self.urgencyLevel)), shouldShow=\(shouldShow)")
        
        return contentView
            .opacity(shouldShow ? 1 : 0)
            .task {
                Self.logger.debug(".task modifier triggered")
                await loadData()
            }
            .onAppear {
                Self.logger.debug(".onAppear triggered")
                startBlockHeightUpdater()
            }
            .onDisappear {
                Self.logger.debug(".onDisappear triggered")
                stopBlockHeightUpdater()
            }
            .onChange(of: vtxos) { _, _ in
                updateUrgencyLevel()
            }
            .onChange(of: latestBlockHeight) { _, _ in
                updateUrgencyLevel()
            }
            .onChange(of: walletManager.transactionVersion) { _, _ in
                updateUrgencyLevel()
                updateActiveRefreshStatus()
            }
            .onChange(of: walletManager.arkInfo) { _, newArkInfo in
                Self.logger.debug("arkInfo changed, newArkInfo exists: \(newArkInfo != nil)")
                
                // If wallet just became initialized and we haven't loaded data yet, load it now
                if newArkInfo != nil && !hasCompletedInitialLoad {
                    Self.logger.debug("Wallet initialized, loading data")
                    Task {
                        await loadData()
                    }
                } else {
                    updateUrgencyLevel()
                }
            }
    }
    
    @ViewBuilder
    private var contentView: some View {
        HStack(spacing: 8) {
            //iconView
            messageView
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(urgencyLevel.backgroundColor)
        .cornerRadius(5)
    }
    
    private var iconView: some View {
        Image(systemName: urgencyLevel.iconName)
            .foregroundStyle(urgencyLevel.iconColor)
            .font(.system(size: 14, weight: .semibold))
            .imageScale(.medium)
    }
    
    private var messageView: some View {
        Text(displayMessage)
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(urgencyLevel.foregroundColor)
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
        Self.logger.debug("loadData started")
        isLoading = true
        
        do {
            vtxos = try await walletManager.getVTXOs()
            latestBlockHeight = await walletManager.getEstimatedBlockHeight()
            Self.logger.debug("Loaded \(self.vtxos.count) VTXOs, blockHeight: \(self.latestBlockHeight ?? -1)")
            updateUrgencyLevel()
            hasCompletedInitialLoad = true
            updateActiveRefreshStatus()
        } catch {
            Self.logger.error("Error loading VTXO data: \(error.localizedDescription)")
            // Don't mark as completed if wallet isn't initialized - we'll retry
            if case BarkWalletFFIError.walletNotInitialized = error {
                Self.logger.debug("Wallet not initialized, will retry when wallet becomes available")
                hasCompletedInitialLoad = false
            } else {
                // For other errors, mark as completed to avoid infinite loading
                hasCompletedInitialLoad = true
            }
        }
        
        isLoading = false
        Self.logger.debug("loadData completed, hasCompletedInitialLoad: \(self.hasCompletedInitialLoad)")
    }
    
    /// Update the urgency level based on current state
    private func updateUrgencyLevel() {
        guard let blockHeight = latestBlockHeight,
              let vtxoLifespan = walletManager.arkInfo?.vtxoExpiryDelta else {
            let blockHeightStr = latestBlockHeight?.description ?? "nil"
            let vtxoLifespanStr = walletManager.arkInfo?.vtxoExpiryDelta.description ?? "nil"
            Self.logger.debug("updateUrgencyLevel - missing data (blockHeight: \(blockHeightStr), vtxoLifespan: \(vtxoLifespanStr))")
            urgencyLevel = .none
            return
        }
        
        let oldUrgency = urgencyLevel
        urgencyLevel = RefreshUrgency.calculateOverallUrgency(
            for: vtxos,
            currentBlockHeight: blockHeight,
            vtxoLifespan: vtxoLifespan
        )
        Self.logger.debug("updateUrgencyLevel - changed from \(String(describing: oldUrgency)) to \(String(describing: self.urgencyLevel))")
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
    
    /// Update the active refresh status by checking for pending refresh transactions
    private func updateActiveRefreshStatus() {
        let refreshTransactions = walletManager.transactions.filter { transaction in
            transaction.category == .refresh && transaction.status == .pending
        }
        hasActiveRefresh = !refreshTransactions.isEmpty
        Self.logger.debug("hasActiveRefresh: \(self.hasActiveRefresh) (found \(refreshTransactions.count) pending refresh transactions)")
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
            let blocks1 = vtxo1.expiryHeight - blockHeight
            let blocks2 = vtxo2.expiryHeight - blockHeight
            return blocks1 < blocks2
        }
    }
    
    private var secondsUntilNextExpiry: Int? {
        guard let vtxo = nextExpiryVTXO else { return nil }
        let blocksUntilExpiry = vtxo.expiryHeight - blockHeight
        let secondsPerBlock = 600 // 10 minutes per block
        return blocksUntilExpiry * secondsPerBlock
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
            return String(localized: "status_calculating")
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
        let secondsPerBlock = 600 // 10 minutes per block
        
        return activeVTXOs.filter { vtxo in
            let blocksUntilExpiry = vtxo.expiryHeight - blockHeight
            let secondsUntilExpiry = blocksUntilExpiry * secondsPerBlock
            let hoursUntilExpiry = secondsUntilExpiry / 3600
            return hoursUntilExpiry < 24
        }.count
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: urgencyLevel.iconName)
                .foregroundStyle(urgencyLevel.foregroundColor)
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
        .background(urgencyLevel == .critical ? Color.Arke.red.opacity(0.1) : Color.clear)
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
            expiryHeight: currentBlock + blocksRemaining,
            kind: VTXOKind.pubkey,
            state: .spendable
        )
    ]
    
    BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Normal - 40% lifespan remaining") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.40) // 40% remaining
    
    let vtxos = [
        VTXOModel(
            id: "normal123:0",
            amountSat: 15000,
            expiryHeight: currentBlock + blocksRemaining,
            kind: VTXOKind.pubkey,
            state: .spendable
        )
    ]
    
    BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Warning - 20% lifespan remaining") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.20) // 20% remaining
    
    let vtxos = [
        VTXOModel(
            id: "warning123:0",
            amountSat: 20000,
            expiryHeight: currentBlock + blocksRemaining,
            kind: VTXOKind.pubkey,
            state: .spendable
        )
    ]
    
    BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Critical - 5% lifespan remaining") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.05) // 5% remaining
    
    let vtxos = [
        VTXOModel(
            id: "critical123:0",
            amountSat: 25000,
            expiryHeight: currentBlock + blocksRemaining,
            kind: VTXOKind.pubkey,
            state: .spendable
        )
    ]
    
    BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Expired") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    
    let vtxos = [
        VTXOModel(
            id: "expired123:0",
            amountSat: 5000,
            expiryHeight: currentBlock - 10, // Already expired 10 blocks ago
            kind: VTXOKind.pubkey,
            state: .spendable
        )
    ]
    
    BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("Multiple Urgent") {
    let currentBlock = 274000
    let vtxoLifespan = 144 // Mock arkInfo.vtxoExpiryDelta
    let blocksRemaining = Int(Double(vtxoLifespan) * 0.08) // 8% remaining - critical
    
    let vtxos = [
        VTXOModel(
            id: "urgent1:0",
            amountSat: 5000,
            expiryHeight: currentBlock + blocksRemaining,
            kind: VTXOKind.pubkey,
            state: .spendable
        ),
        VTXOModel(
            id: "urgent2:0",
            amountSat: 8000,
            expiryHeight: currentBlock + blocksRemaining + 5,
            kind: VTXOKind.pubkey,
            state: .spendable
        ),
        VTXOModel(
            id: "urgent3:0",
            amountSat: 12000,
            expiryHeight: currentBlock + blocksRemaining + 10,
            kind: VTXOKind.pubkey,
            state: .spendable
        )
    ]
    
    BalanceRefreshTagPreview(vtxos: vtxos, blockHeight: currentBlock, vtxoExpiryDelta: vtxoLifespan)
}

#Preview("No VTXOs") {
    BalanceRefreshTagPreview(vtxos: [], blockHeight: 274000, vtxoExpiryDelta: 144)
}
