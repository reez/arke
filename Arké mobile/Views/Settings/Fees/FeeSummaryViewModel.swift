//
//  FeeSummaryViewModel.swift
//  Arké
//
//  Created by Christoph on 1/11/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class FeeSummaryViewModel {
    private let walletManager: WalletManager
    
    var statistics: FeeStatistics?
    var isLoading = false
    var errorMessage: String?
    
    init(walletManager: WalletManager) {
        self.walletManager = walletManager
    }
    
    // MARK: - Public Methods
    
    func loadStatistics() async {
        isLoading = true
        errorMessage = nil
        
        let transactions = walletManager.transactions
        statistics = calculateStatistics(from: transactions)
        
        isLoading = false
    }
    
    // MARK: - Calculation
    
    private func calculateStatistics(from transactions: [TransactionModel]) -> FeeStatistics {
        guard !transactions.isEmpty else {
            return .empty
        }
        
        // Classify all transactions
        var sendTransactions: [TransactionModel] = []
        var receiveTransactions: [TransactionModel] = []
        var internalTransactions: [TransactionModel] = []
        
        for tx in transactions {
            switch classifyTransaction(tx) {
            case .send:
                sendTransactions.append(tx)
            case .receive:
                receiveTransactions.append(tx)
            case .internal:
                internalTransactions.append(tx)
            }
        }
        
        // Calculate statistics for each type
        let sendStats = calculateTypeStats(for: sendTransactions, includeInVolume: true)
        let receiveStats = calculateTypeStats(for: receiveTransactions, includeInVolume: false)
        let internalStats = calculateTypeStats(for: internalTransactions, includeInVolume: true)
        
        // Calculate totals
        let totalFees = sendStats.totalFees + receiveStats.totalFees + internalStats.totalFees
        let totalCount = transactions.count
        let totalVolume = sendStats.volume + internalStats.volume
        
        // Calculate global offchain/onchain breakdown
        var totalOffchainFees = 0
        var totalOnchainFees = 0
        
        for tx in transactions {
            totalOffchainFees += tx.fees ?? 0
            totalOnchainFees += tx.onchainFeeSat ?? 0
        }
        
        // Calculate average fee percentage
        let averageFeePercentage: Double = totalVolume > 0 
            ? (Double(totalFees) / Double(totalVolume)) * 100.0 
            : 0.0
        
        // Calculate failed transaction stats
        let failedStats = calculateFailedStats(from: transactions)
        
        // Calculate efficiency metrics
        let efficiencyMetrics = calculateEfficiencyMetrics(from: transactions)
        
        return FeeStatistics(
            totalFeesAllTime: totalFees,
            totalTransactionCount: totalCount,
            totalVolume: totalVolume,
            averageFeePercentage: averageFeePercentage,
            sendStatistics: sendStats,
            receiveStatistics: receiveStats,
            internalStatistics: internalStats,
            offchainFees: totalOffchainFees,
            onchainFees: totalOnchainFees,
            failedTransactionStats: failedStats,
            efficiencyMetrics: efficiencyMetrics
        )
    }
    
    // MARK: - Transaction Classification
    
    private func classifyTransaction(_ tx: TransactionModel) -> TransactionClassification {
        // Internal transfers: boarding, offboarding, refresh, exit
        if tx.isInternalTransfer {
            return .internal
        }
        
        // Receives
        if tx.type == .received {
            return .receive
        }
        
        // Everything else is a send
        return .send
    }
    
    // MARK: - Type Statistics
    
    private func calculateTypeStats(for transactions: [TransactionModel], includeInVolume: Bool) -> TransactionTypeStats {
        guard !transactions.isEmpty else {
            return .empty
        }
        
        let count = transactions.count
        var totalVolume = 0
        var totalFees = 0
        
        // Group by category
        var categoryGroups: [MovementCategory: [TransactionModel]] = [:]
        
        for tx in transactions {
            if includeInVolume {
                totalVolume += tx.amount
            }
            totalFees += tx.totalFees
            
            // Group by category if available
            if let category = tx.category {
                categoryGroups[category, default: []].append(tx)
            }
        }
        
        // Calculate category breakdown
        var categoryBreakdown: [MovementCategory: CategoryStats] = [:]
        for (category, txs) in categoryGroups {
            let stats = calculateCategoryStats(for: txs, includeInVolume: includeInVolume)
            categoryBreakdown[category] = stats
        }
        
        // Calculate average fee per transaction
        let averageFee = count > 0 ? totalFees / count : 0
        
        // Calculate fee as percentage of volume
        let feePercentage: Double? = (totalVolume > 0 && includeInVolume) 
            ? (Double(totalFees) / Double(totalVolume)) * 100.0 
            : nil
        
        return TransactionTypeStats(
            count: count,
            volume: totalVolume,
            totalFees: totalFees,
            averageFeePerTransaction: averageFee,
            feeAsPercentOfVolume: feePercentage,
            categoryBreakdown: categoryBreakdown
        )
    }
    
    // MARK: - Category Statistics
    
    private func calculateCategoryStats(for transactions: [TransactionModel], includeInVolume: Bool) -> CategoryStats {
        var volume = 0
        var totalFees = 0
        var offchainFees = 0
        var onchainFees = 0
        
        for tx in transactions {
            if includeInVolume {
                volume += tx.amount
            }
            totalFees += tx.totalFees
            offchainFees += tx.fees ?? 0
            onchainFees += tx.onchainFeeSat ?? 0
        }
        
        return CategoryStats(
            count: transactions.count,
            volume: volume,
            fees: totalFees,
            offchainFees: offchainFees,
            onchainFees: onchainFees
        )
    }
    
    // MARK: - Failed Transaction Statistics
    
    private func calculateFailedStats(from transactions: [TransactionModel]) -> FailedTransactionStats? {
        let failedTransactions = transactions.filter { tx in
            // Check if status is failed
            tx.status == .failed
        }
        
        guard !failedTransactions.isEmpty else {
            return nil
        }
        
        var feesLost = 0
        for tx in failedTransactions {
            feesLost += tx.totalFees
        }
        
        // Only return if there are actually fees lost
        guard feesLost > 0 else {
            return nil
        }
        
        return FailedTransactionStats(
            count: failedTransactions.count,
            feesLost: feesLost
        )
    }
    
    // MARK: - Efficiency Metrics
    
    private func calculateEfficiencyMetrics(from transactions: [TransactionModel]) -> EfficiencyMetrics {
        // Get all non-zero fees
        let fees = transactions.map { $0.totalFees }.filter { $0 > 0 }
        
        guard !fees.isEmpty else {
            return .empty
        }
        
        let maxFee = fees.max() ?? 0
        let minFee = fees.min() ?? 0
        let averageFee = fees.reduce(0, +) / fees.count
        
        // Calculate median
        let sortedFees = fees.sorted()
        let medianFee: Int
        if sortedFees.count % 2 == 0 {
            let mid = sortedFees.count / 2
            medianFee = (sortedFees[mid - 1] + sortedFees[mid]) / 2
        } else {
            medianFee = sortedFees[sortedFees.count / 2]
        }
        
        return EfficiencyMetrics(
            maxSingleFee: maxFee,
            minSingleFee: minFee,
            averageFee: averageFee,
            medianFee: medianFee
        )
    }
}
