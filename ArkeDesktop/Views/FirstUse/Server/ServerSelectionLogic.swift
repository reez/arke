//
//  ServerSelectionLogic.swift
//  Arké
//
//  Created by Christoph on 11/25/25.
//

import Foundation

// MARK: - Server Configuration

enum RefreshFeeModel {
    /// Fee scales with balance: Balance × Rate × Time
    case percentage(annualRate: Double)
    
    /// Fixed fee per refresh regardless of balance
    case absolute(sats: Int)
    
    /// Percentage with a minimum floor
    case tiered(annualRate: Double, minimumSats: Int)
}

struct ServerFeeConfig {
    /// Unique identifier for the server
    let id: String
    
    /// Display name
    let name: String
    
    /// Logo image name (from asset catalog)
    let logoImage: String
    
    /// Refresh fee model
    let refreshFeeModel: RefreshFeeModel
    
    /// VTXO expiry period in days
    let expiryDays: Int
    
    /// Lightning base fee in sats
    let lightningBaseFee: Int
    
    /// Lightning proportional fee in ppm (parts per million)
    let lightningPPM: Int
    
    /// Optional: Days before expiry where refresh is free
    let freeRefreshWindowDays: Int?
    
    /// Website URL
    let websiteURL: URL
    
    /// Server URL
    let serverURL: URL
    
    let enabled: Bool
}

// MARK: - User Profile

struct ServerUsageProfile: Equatable {
    /// Average balance held in sats
    let averageBalance: Int
    
    /// Total monthly transaction volume in sats
    let monthlyVolume: Int
    
    /// Number of on-Ark payments per month
    let onArkPayments: Int
    
    /// Number of Lightning payments per month
    let lightningPayments: Int
    
    /// Number of refreshes per month
    let refreshesPerMonth: Int
    
    /// Number of VTXOs (for fragmented balances)
    let vtxoCount: Int
    
    /// Casual user: smaller balance, moderate spending
    static let casual = ServerUsageProfile(
        averageBalance: 100_000,
        monthlyVolume: 50_000,
        onArkPayments: 6,
        lightningPayments: 4,
        refreshesPerMonth: 1,
        vtxoCount: 1
    )
    
    /// Spender: deposits larger amounts, makes frequent transactions
    static let spender = ServerUsageProfile(
        averageBalance: 200_000,
        monthlyVolume: 500_000,
        onArkPayments: 10,
        lightningPayments: 15,
        refreshesPerMonth: 2,
        vtxoCount: 2
    )
    
    /// Saver: mostly receives, larger balance, few outgoing transactions
    static let saver = ServerUsageProfile(
        averageBalance: 1_000_000,
        monthlyVolume: 50_000,
        onArkPayments: 1,
        lightningPayments: 1,
        refreshesPerMonth: 1,
        vtxoCount: 1
    )
}

// MARK: - Fee Breakdown

struct ServerFeeEstimate {
    /// On-Ark payment fees (typically 0)
    let onArkFees: Int
    
    /// Lightning payment fees (routing only)
    let lightningFees: Int
    
    /// Refresh fees
    let refreshFees: Int
    
    /// Total monthly cost
    var totalMonthly: Int {
        onArkFees + lightningFees + refreshFees
    }
    
    /// Effective fee rate as percentage of volume
    func effectiveRate(for volume: Int) -> Double {
        guard volume > 0 else { return 0 }
        return Double(totalMonthly) / Double(volume) * 100
    }
}

// MARK: - Calculator

struct ArkFeeCalculator {
    
    private let daysPerYear: Double = 365.0
    
    /// Calculate estimated monthly fees for a server given a usage profile
    func estimateMonthlyFees(
        server: ServerFeeConfig,
        profile: ServerUsageProfile
    ) -> ServerFeeEstimate {
        
        let averagePaymentSize = calculateAveragePaymentSize(profile: profile)
        let averageTimeRemaining = calculateAverageTimeRemaining(server: server)
        
        // On-Ark fees (always 0 - no liquidity required)
        let onArkFees = 0
        
        // Lightning fees (routing only)
        let lightningFees = calculateLightningFees(
            server: server,
            profile: profile,
            averagePaymentSize: averagePaymentSize
        )
        
        // Refresh fees
        let refreshFees = calculateRefreshFees(
            server: server,
            profile: profile,
            averageTimeRemaining: averageTimeRemaining
        )
        
        return ServerFeeEstimate(
            onArkFees: onArkFees,
            lightningFees: lightningFees,
            refreshFees: refreshFees
        )
    }
    
    // MARK: - Private Calculations
    
    private func calculateAveragePaymentSize(profile: ServerUsageProfile) -> Double {
        let totalPayments = profile.onArkPayments + profile.lightningPayments
        guard totalPayments > 0 else { return 0 }
        return Double(profile.monthlyVolume) / Double(totalPayments)
    }
    
    private func calculateAverageTimeRemaining(server: ServerFeeConfig) -> Double {
        // Assume users refresh at mid-life of VTXO
        return Double(server.expiryDays) / 2.0
    }
    
    private func calculateLightningFees(
        server: ServerFeeConfig,
        profile: ServerUsageProfile,
        averagePaymentSize: Double
    ) -> Int {
        
        guard profile.lightningPayments > 0 else {
            return 0
        }
        
        // Routing cost per payment
        // Fee = BaseFee + (Amount × PPM / 1,000,000)
        let routingPerPayment = Double(server.lightningBaseFee)
            + (averagePaymentSize * Double(server.lightningPPM) / 1_000_000.0)
        
        let totalRouting = Int((routingPerPayment * Double(profile.lightningPayments)).rounded())
        
        return totalRouting
    }
    
    private func calculateRefreshFees(
        server: ServerFeeConfig,
        profile: ServerUsageProfile,
        averageTimeRemaining: Double
    ) -> Int {
        
        guard profile.refreshesPerMonth > 0 else { return 0 }
        
        // Check if refresh falls within free window
        if let freeWindow = server.freeRefreshWindowDays {
            // If average time remaining is less than free window, no fee
            if averageTimeRemaining <= Double(freeWindow) {
                return 0
            }
        }
        
        // Calculate fee based on model
        let feePerRefresh: Double
        
        switch server.refreshFeeModel {
        case .percentage(let annualRate):
            // Fee = Balance × (TimeRemaining / 365) × AnnualRate × VTXOCount
            feePerRefresh = Double(profile.averageBalance)
                * (averageTimeRemaining / daysPerYear)
                * annualRate
                * Double(profile.vtxoCount)
            
        case .absolute(let sats):
            // Fixed fee per VTXO
            feePerRefresh = Double(sats * profile.vtxoCount)
            
        case .tiered(let annualRate, let minimumSats):
            // Calculate percentage fee
            let percentageFee = Double(profile.averageBalance)
                * (averageTimeRemaining / daysPerYear)
                * annualRate
                * Double(profile.vtxoCount)
            
            // Apply minimum (per-refresh, not per-VTXO)
            feePerRefresh = max(percentageFee, Double(minimumSats))
        }
        
        let totalRefreshFee = feePerRefresh * Double(profile.refreshesPerMonth)
        
        return Int(totalRefreshFee.rounded())
    }
}

// MARK: - Comparison Helper

struct ServerComparison {
    let server: ServerFeeConfig
    let estimate: ServerFeeEstimate
    let profile: ServerUsageProfile
}

extension ArkFeeCalculator {
    
    /// Compare multiple servers for a given usage profile
    func compareServers(
        servers: [ServerFeeConfig],
        profile: ServerUsageProfile
    ) -> [ServerComparison] {
        
        servers.map { server in
            ServerComparison(
                server: server,
                estimate: estimateMonthlyFees(server: server, profile: profile),
                profile: profile
            )
        }
        .sorted { $0.estimate.totalMonthly < $1.estimate.totalMonthly }
    }
}

// MARK: - Formatting

extension ServerFeeEstimate {
    
    func formatted(profile: ServerUsageProfile) -> String {
        """
        Estimated monthly cost: \(totalMonthly) sats
        ├─ On-Ark payments (\(profile.onArkPayments)×): \(onArkFees) sats
        ├─ Lightning (\(profile.lightningPayments)×): \(lightningFees) sats
        └─ Refresh (\(profile.refreshesPerMonth)×): \(refreshFees) sats
        
        Effective rate: \(String(format: "%.3f", effectiveRate(for: profile.monthlyVolume)))%
        """
    }
}

extension ServerUsageProfile {
    
    var assumptionsDescription: String {
        """
        Based on \(onArkPayments + lightningPayments) txs/month, \(monthlyVolume.formatted()) sats total
        """
    }
}
