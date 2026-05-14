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
                    .accessibilityLabel(String(localized: "status_loading_fee_stats"))
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
            .init(label: String(localized: "fee_transactions"), value: "\(sendStats.count)"),
            .init(label: String(localized: "activity_fees_paid"), value: BitcoinFormatter.shared.formatAmount(sendStats.totalFees)),
            .init(label: String(localized: "fee_amount_sent"), value: BitcoinFormatter.shared.formatAmount(sendStats.volume))
        ]
        
        let networkBreakdown = sendStats.networkBreakdown
        let networkSection = FeeDetailCardView_iOS.Section(
            title: String(localized: "fee_by_network"),
            items: [
                .init(
                    label: networkBreakdown.arkCount > 0 
                        ? String(format: String(localized: "fee_network_with_count"), String(localized: "network_ark"), networkBreakdown.arkCount)
                        : String(localized: "network_ark"),
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.arkFees)
                ),
                .init(
                    label: networkBreakdown.lightningCount > 0 
                        ? String(format: String(localized: "fee_network_with_count"), String(localized: "network_lightning"), networkBreakdown.lightningCount)
                        : String(localized: "network_lightning"),
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.lightningFees)
                ),
                .init(
                    label: networkBreakdown.bitcoinCount > 0 
                        ? String(format: String(localized: "fee_network_with_count"), String(localized: "network_bitcoin"), networkBreakdown.bitcoinCount)
                        : String(localized: "network_bitcoin"),
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.bitcoinFees)
                )
            ]
        )
        
        return FeeDetailCardView_iOS(
            title: String(localized: "fee_average_send"),
            subtitle: nil,
            prominentMetric: percentageString,
            prominentMetricAccessibilityLabel: String(format: String(localized: "a11y_average_fee_percentage"), percentageString),
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
                label: refreshStats?.count ?? 0 > 0 
                    ? String(format: String(localized: "maintenance_refresh_with_count"), refreshStats!.count)
                    : String(localized: "maintenance_refresh"),
                value: BitcoinFormatter.shared.formatAmount(refreshStats?.fees ?? 0)
            ),
            .init(
                label: boardingStats?.count ?? 0 > 0 
                    ? String(format: String(localized: "maintenance_boarding_with_count"), boardingStats!.count)
                    : String(localized: "maintenance_boarding"),
                value: BitcoinFormatter.shared.formatAmount(boardingStats?.fees ?? 0)
            ),
            .init(
                label: offboardingStats?.count ?? 0 > 0 
                    ? String(format: String(localized: "maintenance_offboarding_with_count"), offboardingStats!.count)
                    : String(localized: "maintenance_offboarding"),
                value: BitcoinFormatter.shared.formatAmount(offboardingStats?.fees ?? 0)
            ),
            .init(
                label: recoveryCount > 0 
                    ? String(format: String(localized: "maintenance_exit_with_count"), recoveryCount)
                    : String(localized: "maintenance_exit"),
                value: BitcoinFormatter.shared.formatAmount(recoveryFees)
            )
        ]
        
        return FeeDetailCardView_iOS(
            title: String(localized: "fee_maintenance"),
            subtitle: String(localized: "fee_maintenance_subtitle"),
            prominentMetric: BitcoinFormatter.shared.formatAmount(internalStats.totalFees),
            prominentMetricAccessibilityLabel: nil,
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
            .init(label: String(localized: "fee_transactions"), value: "\(receiveStats.count)"),
            .init(label: String(localized: "activity_fees_paid"), value: BitcoinFormatter.shared.formatAmount(receiveStats.totalFees)),
            .init(label: String(localized: "fee_amount_received"), value: BitcoinFormatter.shared.formatAmount(receiveStats.volume))
        ]
        
        let networkBreakdown = receiveStats.networkBreakdown
        let networkSection = FeeDetailCardView_iOS.Section(
            title: String(localized: "fee_network_breakdown"),
            items: [
                .init(
                    label: networkBreakdown.arkCount > 0 
                        ? String(format: String(localized: "fee_network_with_count"), String(localized: "network_ark"), networkBreakdown.arkCount)
                        : String(localized: "network_ark"),
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.arkFees)
                ),
                .init(
                    label: networkBreakdown.lightningCount > 0 
                        ? String(format: String(localized: "fee_network_with_count"), String(localized: "network_lightning"), networkBreakdown.lightningCount)
                        : String(localized: "network_lightning"),
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.lightningFees)
                ),
                .init(
                    label: networkBreakdown.bitcoinCount > 0 
                        ? String(format: String(localized: "fee_network_with_count"), String(localized: "network_bitcoin"), networkBreakdown.bitcoinCount)
                        : String(localized: "network_bitcoin"),
                    value: BitcoinFormatter.shared.formatAmount(networkBreakdown.bitcoinFees)
                )
            ]
        )
        
        return FeeDetailCardView_iOS(
            title: String(localized: "fee_average_receive"),
            subtitle: nil,
            prominentMetric: percentageString,
            prominentMetricAccessibilityLabel: String(format: String(localized: "a11y_average_fee_percentage"), percentageString),
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
                .accessibilityLabel(String(localized: "a11y_loading_fee_stats"))
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
