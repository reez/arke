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
    @State private var viewModel: BalanceRefreshStatusViewModel?
    @State private var updateTimer: Timer?
    
    /// Logger for balance refresh tag operations
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.arke", category: "BalanceRefreshTag")
    
    // MARK: - Computed Properties
    
    private var urgencyLevel: RefreshUrgency {
        viewModel?.urgencyLevel ?? .none
    }
    
    private var hasCompletedInitialLoad: Bool {
        viewModel?.hasCompletedInitialLoad ?? false
    }
    
    private var hasActiveRefresh: Bool {
        viewModel?.hasActiveRefresh ?? false
    }
    
    /// Generate the display message based on urgency
    private var displayMessage: String {
        Self.logger.debug("displayMessage computation: urgency=\(String(describing: self.urgencyLevel))")
        
        guard let viewModel = viewModel, viewModel.hasCompletedInitialLoad else {
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
    
    // MARK: - Body
    
    var body: some View {
        let shouldShow = hasCompletedInitialLoad && (urgencyLevel == .warning || urgencyLevel == .critical || urgencyLevel == .expired)

        let _ = Self.logger.debug("Visibility check: hasCompletedInitialLoad=\(self.hasCompletedInitialLoad), hasActiveRefresh=\(self.hasActiveRefresh), urgency=\(String(describing: self.urgencyLevel)), shouldShow=\(shouldShow)")
        
        return contentView
            .opacity(shouldShow ? 1 : 0)
            .task {
                Self.logger.debug(".task modifier triggered")
                if viewModel == nil {
                    viewModel = BalanceRefreshStatusViewModel(walletManager: walletManager)
                }
                await viewModel?.loadData()
            }
            .onAppear {
                Self.logger.debug(".onAppear triggered")
                startBlockHeightUpdater()
            }
            .onDisappear {
                Self.logger.debug(".onDisappear triggered")
                stopBlockHeightUpdater()
            }
            .onChange(of: walletManager.transactionVersion) { _, _ in
                Task {
                    await viewModel?.loadData()
                }
            }
            .onChange(of: walletManager.arkInfo) { _, newArkInfo in
                Self.logger.debug("arkInfo changed, newArkInfo exists: \(newArkInfo != nil)")
                
                // If wallet just became initialized and we haven't loaded data yet, load it now
                if newArkInfo != nil && !hasCompletedInitialLoad {
                    Self.logger.debug("Wallet initialized, loading data")
                    Task {
                        await viewModel?.loadData()
                    }
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
    
    /// Start timer to update block height every 30 seconds
    private func startBlockHeightUpdater() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                viewModel?.latestBlockHeight = await walletManager.getEstimatedBlockHeight()
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

/// Preview wrapper that shows the tag in different states
private struct BalanceRefreshTagPreview: View {
    let urgency: RefreshUrgency
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(urgency.foregroundColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(urgency.backgroundColor)
        .cornerRadius(5)
        .padding()
        .frame(width: 200)
    }
}

#Preview("Warning") {
    BalanceRefreshTagPreview(urgency: .warning, message: "Refresh now")
}

#Preview("Critical") {
    BalanceRefreshTagPreview(urgency: .critical, message: "Refresh now")
}

#Preview("Expired") {
    BalanceRefreshTagPreview(urgency: .expired, message: "Refresh now")
}
