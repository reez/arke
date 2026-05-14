//
//  ReadOnlyBalanceService.swift
//  Arke
//
//  Created by Christoph on 5/7/26.
//

import Foundation
import SwiftData

/// Lightweight balance service for read-only mode (secondary devices)
/// Only loads balances from SwiftData/CloudKit - no wallet operations
@MainActor
@Observable
class ReadOnlyBalanceService {
    
    // MARK: - Published Properties
    
    /// Current Ark balance (loaded from SwiftData)
    var arkBalance: ArkBalanceModel?
    
    /// Current onchain balance (loaded from SwiftData)
    var onchainBalance: OnchainBalanceModel?
    
    /// Combined total balance across all wallets
    var totalBalance: TotalBalanceModel?
    
    /// Error message for balance operations
    var error: String?
    
    // MARK: - Dependencies
    
    private var modelContext: ModelContext?
    
    // MARK: - Computed Properties for UI
    
    /// True if there are any pending balances
    var hasPendingBalance: Bool {
        totalBalance?.hasPendingBalance ?? false
    }
    
    /// True if user has any spendable funds
    var hasSpendableBalance: Bool {
        totalBalance?.hasSpendableBalance ?? false
    }
    
    // MARK: - Initialization
    
    init() {
        // No dependencies needed for read-only mode
    }
    
    // MARK: - Model Context Setup
    
    /// Set the model context and load persisted balances
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        
        // Load persisted balances synchronously for instant UI display
        loadPersistedArkBalanceSync()
        loadPersistedOnchainBalanceSync()
        updateTotalBalance()
    }
    
    // MARK: - Balance Loading
    
    /// Load persisted Ark balance from SwiftData (synchronous)
    private func loadPersistedArkBalanceSync() {
        guard let modelContext = modelContext else {
            print("⚠️ [ReadOnlyBalanceService] No model context available for loading Ark balance")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<ArkBalanceModel>(
                predicate: #Predicate<ArkBalanceModel> { $0.id == "ark_balance" }
            )
            let persistedBalances = try modelContext.fetch(descriptor)
            
            if let persistedBalance = persistedBalances.first {
                self.arkBalance = persistedBalance
                print("📱 [ReadOnlyBalanceService] Loaded Ark balance from CloudKit (spendable: \(persistedBalance.spendableSat) sats)")
            } else {
                print("📱 [ReadOnlyBalanceService] No Ark balance found in CloudKit yet")
            }
        } catch {
            print("❌ [ReadOnlyBalanceService] Failed to load Ark balance: \(error)")
        }
    }
    
    /// Load persisted Onchain balance from SwiftData (synchronous)
    private func loadPersistedOnchainBalanceSync() {
        guard let modelContext = modelContext else {
            print("⚠️ [ReadOnlyBalanceService] No model context available for loading Onchain balance")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<OnchainBalanceModel>(
                predicate: #Predicate<OnchainBalanceModel> { $0.id == "onchain_balance" }
            )
            let persistedBalances = try modelContext.fetch(descriptor)
            
            if let persistedBalance = persistedBalances.first {
                self.onchainBalance = persistedBalance
                print("📱 [ReadOnlyBalanceService] Loaded Onchain balance from CloudKit (spendable: \(persistedBalance.spendableSat) sats)")
            } else {
                print("📱 [ReadOnlyBalanceService] No Onchain balance found in CloudKit yet")
            }
        } catch {
            print("❌ [ReadOnlyBalanceService] Failed to load Onchain balance: \(error)")
        }
    }
    
    /// Update the total balance based on current ark and onchain balances
    func updateTotalBalance() {
        // Create zero-balance models for any missing balances
        // This ensures the UI always shows something, even during partial loads or CloudKit sync delays
        let ark = arkBalance ?? ArkBalanceModel(
            spendableSat: 0,
            pendingLightningSendSat: 0,
            pendingInRoundSat: 0,
            pendingExitSat: 0,
            pendingBoardSat: 0
        )
        
        let onchain = onchainBalance ?? OnchainBalanceModel(
            totalSat: 0,
            confirmedSat: 0,
            pendingSat: 0
        )
        
        totalBalance = TotalBalanceModel(arkBalance: ark, onchainBalance: onchain)
        
        if arkBalance == nil && onchainBalance == nil {
            print("📊 [ReadOnlyBalanceService] Total balance: \(totalBalance?.grandTotalSat ?? 0) sats (waiting for CloudKit sync)")
        } else if arkBalance == nil {
            print("📊 [ReadOnlyBalanceService] Total balance: \(totalBalance?.grandTotalSat ?? 0) sats (ark balance not synced yet, using onchain only)")
        } else if onchainBalance == nil {
            print("📊 [ReadOnlyBalanceService] Total balance: \(totalBalance?.grandTotalSat ?? 0) sats (onchain balance not synced yet, using ark only)")
        } else {
            print("📊 [ReadOnlyBalanceService] Total balance: \(totalBalance?.grandTotalSat ?? 0) sats (\(totalBalance?.totalSpendableSat ?? 0) spendable)")
        }
    }
    
    /// Refresh balances by reloading from SwiftData
    /// (In read-only mode, this just reloads from local cache - data is synced via CloudKit push)
    func refreshBalances() {
        loadPersistedArkBalanceSync()
        loadPersistedOnchainBalanceSync()
        updateTotalBalance()
    }
}
