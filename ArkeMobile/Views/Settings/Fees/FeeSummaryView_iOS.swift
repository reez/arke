//
//  FeeSummaryView_iOS.swift
//  Arké
//
//  Created by Christoph on 1/11/26.
//

import SwiftUI
import ArkeUI

struct FeeSummaryView_iOS: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel: FeeSummaryViewModel?
    
    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else if let statistics = viewModel.statistics {
                    if statistics.hasTransactions {
                        statisticsView(statistics: statistics)
                    } else {
                        emptyStateView
                    }
                } else {
                    emptyStateView
                }
            } else {
                ProgressView()
                    .task {
                        viewModel = FeeSummaryViewModel(walletManager: walletManager)
                        await viewModel?.loadStatistics()
                    }
            }
        }
        //.navigationTitle("activity_fee_summary")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel?.loadStatistics()
        }
    }
    
    // MARK: - Statistics View
    
    @ViewBuilder
    private func statisticsView(statistics: FeeStatistics) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Large serif title
                Text("activity_fee_summary")
                    .font(.system(.largeTitle, design: .serif))
                    .padding(.horizontal)
                
                // Overview Section
                overviewCards(statistics: statistics)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Overview Cards
    
    @ViewBuilder
    private func overviewCards(statistics: FeeStatistics) -> some View {
        VStack(spacing: 40) {
            // Card 1: Send Fee Summary
            sendFeeSummaryCard(statistics: statistics)
            
            // Card 2: Maintenance Fees (Internal Transfers)
            maintenanceFeesCard(statistics: statistics)
            
            // Card 3: Receive Fees
            // receiveFeesCard(statistics: statistics)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Send Fee Summary Card
    
    private func sendFeeSummaryCard(statistics: FeeStatistics) -> some View {
        let sendStats = statistics.sendStatistics
        let percentageString: String
        
        if let feePercentage = sendStats.feeAsPercentOfVolume {
            percentageString = String(format: "%.2f%%", feePercentage)
        } else {
            percentageString = "0%"
        }
        
        let keyMetrics: [FeeDetailCardView_iOS.KeyMetric] = [
            .init(label: "Transactions", value: "\(sendStats.count)"),
            .init(label: "Fees Paid", value: BitcoinFormatter.shared.formatAmount(sendStats.totalFees)),
            .init(label: "Amount Sent", value: BitcoinFormatter.shared.formatAmount(sendStats.volume))
        ]
        
        let networkBreakdown = sendStats.networkBreakdown
        let networkSection = FeeDetailCardView_iOS.Section(
            title: "Fees by Network",
            items: [
                .init(
                    label: networkBreakdown.arkCount > 0 ? "Ark network (\(networkBreakdown.arkCount))" : "Ark network",
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.arkFees)
                ),
                .init(
                    label: networkBreakdown.lightningCount > 0 ? "Lightning network (\(networkBreakdown.lightningCount))" : "Lightning network",
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.lightningFees)
                ),
                .init(
                    label: networkBreakdown.bitcoinCount > 0 ? "Bitcoin network (\(networkBreakdown.bitcoinCount))" : "Bitcoin network",
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.bitcoinFees)
                )
            ]
        )
        
        return FeeDetailCardView_iOS(
            title: "Average Send Fee",
            subtitle: nil,
            prominentMetric: percentageString,
            keyMetrics: keyMetrics,
            sections: [networkSection],
            iconSymbol: "arrow.up",
            iconBackgroundImage: "card"
        )
    }
    
    // MARK: - Maintenance Fees Card
    
    private func maintenanceFeesCard(statistics: FeeStatistics) -> some View {
        let internalStats = statistics.internalStatistics
        let categoryBreakdown = internalStats.categoryBreakdown
        
        // Extract specific categories for maintenance
        let refreshStats = categoryBreakdown[.refresh]
        let boardingStats = categoryBreakdown[.boarding]
        let offboardingStats = categoryBreakdown[.offboarding]
        let exitStats = categoryBreakdown[.exit]
        
        // Exit fees now include linked onchain transaction fees via totalFeesIncludingLinked()
        // No need to add onchainStats separately (would cause double-counting)
        let recoveryFees = exitStats?.fees ?? 0
        let recoveryCount = exitStats?.count ?? 0
        
        let keyMetrics: [FeeDetailCardView_iOS.KeyMetric] = [
            .init(
                label: refreshStats?.count ?? 0 > 0 ? "Refresh (\(refreshStats!.count))" : "Refresh",
                value: BitcoinFormatter.shared.formatAmount(refreshStats?.fees ?? 0)
            ),
            .init(
                label: boardingStats?.count ?? 0 > 0 ? "Move to payments (\(boardingStats!.count))" : "Move to payments",
                value: BitcoinFormatter.shared.formatAmount(boardingStats?.fees ?? 0)
            ),
            .init(
                label: offboardingStats?.count ?? 0 > 0 ? "Move to savings (\(offboardingStats!.count))" : "Move to savings",
                value: BitcoinFormatter.shared.formatAmount(offboardingStats?.fees ?? 0)
            ),
            .init(
                label: recoveryCount > 0 ? "Recovery (\(recoveryCount))" : "Recovery",
                value: BitcoinFormatter.shared.formatAmount(recoveryFees)
            )
        ]
        
        return FeeDetailCardView_iOS(
            title: "Maintenance Fees",
            subtitle: "Your payments balance requires occassional refreshes and transfers.",
            prominentMetric: BitcoinFormatter.shared.formatAmount(internalStats.totalFees),
            keyMetrics: keyMetrics,
            sections: [],
            iconSymbol: "repeat",
            iconBackgroundImage: "card"
        )
    }
    
    // MARK: - Receive Fees Card
    
    private func receiveFeesCard(statistics: FeeStatistics) -> some View {
        let receiveStats = statistics.receiveStatistics
        let percentageString: String
        
        if let feePercentage = receiveStats.feeAsPercentOfVolume {
            percentageString = String(format: "%.2f%%", feePercentage)
        } else {
            percentageString = "—"
        }
        
        let keyMetrics: [FeeDetailCardView_iOS.KeyMetric] = [
            .init(label: "Transactions", value: "\(receiveStats.count)"),
            .init(label: "Fees Paid", value: BitcoinFormatter.shared.formatAmount(receiveStats.totalFees)),
            .init(label: "Amount Received", value: BitcoinFormatter.shared.formatAmount(receiveStats.volume))
        ]
        
        let networkBreakdown = receiveStats.networkBreakdown
        let networkSection = FeeDetailCardView_iOS.Section(
            title: "Network Breakdown",
            items: [
                .init(
                    label: networkBreakdown.arkCount > 0 ? "Ark network (\(networkBreakdown.arkCount)x)" : "Ark network",
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.arkFees)
                ),
                .init(
                    label: networkBreakdown.lightningCount > 0 ? "Lightning network (\(networkBreakdown.lightningCount)x)" : "Lightning network",
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.lightningFees)
                ),
                .init(
                    label: networkBreakdown.bitcoinCount > 0 ? "Bitcoin network (\(networkBreakdown.bitcoinCount)x)" : "Bitcoin network",
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.bitcoinFees)
                )
            ]
        )
        
        return FeeDetailCardView_iOS(
            title: "Average Receive Fee",
            subtitle: nil,
            prominentMetric: percentageString,
            keyMetrics: keyMetrics,
            sections: [networkSection]
        )
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("activity_empty_title", systemImage: "chart.bar.xaxis")
        } description: {
            Text("activity_fee_stats_empty")
        }
    }
    
    // MARK: - Loading View
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(String(localized: "status_loading_fee_stats"))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Error View
    
    @ViewBuilder
    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("error_load_statistics", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("button_try_again") {
                Task {
                    await viewModel?.loadStatistics()
                }
            }
        }
    }
}
