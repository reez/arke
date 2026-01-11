//
//  FeeSummaryView_iOS.swift
//  Arké
//
//  Created by Christoph on 1/11/26.
//

import SwiftUI

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
        .navigationTitle("Fee Summary")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel?.loadStatistics()
        }
    }
    
    // MARK: - Statistics View
    
    @ViewBuilder
    private func statisticsView(statistics: FeeStatistics) -> some View {
        List {
            // Overview Section
            Section {
                overviewCards(statistics: statistics)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // Fee Type Breakdown
            Section {
                feeTypeBreakdown(statistics: statistics)
            } header: {
                Text("Fee Breakdown by Type")
            }
            
            // Transaction Type Statistics
            if statistics.sendStatistics.hasTransactions {
                Section {
                    transactionTypeDetails(
                        stats: statistics.sendStatistics,
                        classification: .send
                    )
                } header: {
                    Text("Sends (Outgoing Payments)")
                }
            }
            
            if statistics.receiveStatistics.hasTransactions {
                Section {
                    transactionTypeDetails(
                        stats: statistics.receiveStatistics,
                        classification: .receive
                    )
                } header: {
                    Text("Receives (Incoming Payments)")
                }
            }
            
            if statistics.internalStatistics.hasTransactions {
                Section {
                    transactionTypeDetails(
                        stats: statistics.internalStatistics,
                        classification: .internal
                    )
                } header: {
                    Text("Internal Transfers")
                }
            }
            
            // Failed Transactions (if any)
            if let failedStats = statistics.failedTransactionStats {
                Section {
                    failedTransactionsView(stats: failedStats)
                } header: {
                    Text("Failed Transactions")
                }
            }
            
            // Efficiency Metrics
            if statistics.efficiencyMetrics.hasData {
                Section {
                    efficiencyMetricsView(metrics: statistics.efficiencyMetrics)
                } header: {
                    Text("Efficiency Metrics")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Overview Cards
    
    @ViewBuilder
    private func overviewCards(statistics: FeeStatistics) -> some View {
        VStack(spacing: 16) {
            // Total Fees Card
            FeeStatCardView_iOS(
                title: "Total Fees Paid (All Time)",
                value: BitcoinFormatter.shared.formatAmount(statistics.totalFeesAllTime),
                subtitle: "Across \(statistics.totalTransactionCount) transaction\(statistics.totalTransactionCount == 1 ? "" : "s")",
                color: .orange
            )
            
            // Total Volume Card
            if statistics.totalVolume > 0 {
                FeeStatCardView_iOS(
                    title: "Total Volume Moved",
                    value: BitcoinFormatter.shared.formatAmount(statistics.totalVolume),
                    subtitle: String(format: "Average Fee: %.2f%%", statistics.averageFeePercentage),
                    color: .blue
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Fee Type Breakdown
    
    @ViewBuilder
    private func feeTypeBreakdown(statistics: FeeStatistics) -> some View {
        let total = statistics.totalFeesAllTime
        
        if total > 0 {
            FeeBreakdownRow_iOS(
                label: "Offchain Fees",
                amount: statistics.offchainFees,
                total: total,
                color: .purple
            )
            
            FeeBreakdownRow_iOS(
                label: "Onchain Fees",
                amount: statistics.onchainFees,
                total: total,
                color: .blue
            )
        } else {
            Text("No fees paid yet")
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Transaction Type Details
    
    @ViewBuilder
    private func transactionTypeDetails(stats: TransactionTypeStats, classification: TransactionClassification) -> some View {
        // Summary row
        HStack {
            Text("Total Transactions")
            Spacer()
            Text("\(stats.count)")
                .foregroundStyle(.secondary)
        }
        
        if stats.volume > 0 {
            HStack {
                Text("Total Volume")
                Spacer()
                Text(BitcoinFormatter.shared.formatAmount(stats.volume))
                    .foregroundStyle(.secondary)
            }
        }
        
        if stats.hasFees {
            HStack {
                Text("Total Fees")
                Spacer()
                Text(BitcoinFormatter.shared.formatAmount(stats.totalFees))
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Average Fee")
                Spacer()
                Text(BitcoinFormatter.shared.formatAmount(stats.averageFeePerTransaction))
                    .foregroundStyle(.secondary)
            }
            
            if let feePercentage = stats.feeAsPercentOfVolume {
                HStack {
                    Text("Fee as % of Volume")
                    Spacer()
                    Text(String(format: "%.2f%%", feePercentage))
                        .foregroundStyle(.secondary)
                }
            }
        }
        
        // Category breakdown
        if !stats.categoryBreakdown.isEmpty {
            Divider()
                .padding(.vertical, 4)
            
            Text("Breakdown by Category")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ForEach(Array(stats.categoryBreakdown.keys.sorted(by: { $0.displayName < $1.displayName })), id: \.self) { category in
                if let categoryStats = stats.categoryBreakdown[category] {
                    categoryBreakdownRow(category: category, stats: categoryStats)
                }
            }
        }
    }
    
    @ViewBuilder
    private func categoryBreakdownRow(category: MovementCategory, stats: CategoryStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category.displayName)
                    .font(.subheadline)
                Spacer()
                Text("\(stats.count) tx")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if stats.hasFees {
                HStack {
                    Text("Fees:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(BitcoinFormatter.shared.formatAmount(stats.fees))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Failed Transactions
    
    @ViewBuilder
    private func failedTransactionsView(stats: FailedTransactionStats) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Failed Transactions")
                    .font(.headline)
                Text("\(stats.count) transaction\(stats.count == 1 ? "" : "s") failed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Fees Lost")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(BitcoinFormatter.shared.formatAmount(stats.feesLost))
                    .font(.headline)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Efficiency Metrics
    
    @ViewBuilder
    private func efficiencyMetricsView(metrics: EfficiencyMetrics) -> some View {
        HStack {
            Text("Highest Fee")
            Spacer()
            Text(BitcoinFormatter.shared.formatAmount(metrics.maxSingleFee))
                .foregroundStyle(.secondary)
        }
        
        HStack {
            Text("Lowest Fee")
            Spacer()
            Text(BitcoinFormatter.shared.formatAmount(metrics.minSingleFee))
                .foregroundStyle(.secondary)
        }
        
        HStack {
            Text("Average Fee")
            Spacer()
            Text(BitcoinFormatter.shared.formatAmount(metrics.averageFee))
                .foregroundStyle(.secondary)
        }
        
        HStack {
            Text("Median Fee")
            Spacer()
            Text(BitcoinFormatter.shared.formatAmount(metrics.medianFee))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Transactions Yet", systemImage: "chart.bar.xaxis")
        } description: {
            Text("Fee statistics will appear here once you start making transactions")
        }
    }
    
    // MARK: - Loading View
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading fee statistics...")
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Error View
    
    @ViewBuilder
    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to Load Statistics", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel?.loadStatistics()
                }
            }
        }
    }
}
