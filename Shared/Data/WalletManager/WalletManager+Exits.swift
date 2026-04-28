//
//  WalletManager+Exits.swift
//  Arke
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension WalletManager {
    
    /// Active unilateral exits (from Bark SDK)
    /// Note: Filters out claimed exits, as they are no longer active
    var activeUnilateralExits: [ExitVtxo] {
        // Get all exit VTXOs (claimed and unclaimed)
        let allExits: [ExitVtxo]
        
        // Return cached value if fresh
        if let cacheTime = exitVtxosCacheTime,
           Date().timeIntervalSince(cacheTime) < exitCacheTimeout {
            let age = Date().timeIntervalSince(cacheTime)
            print("📦 [Exit Cache] Returning cached exit VTXOs (age: \(String(format: "%.1f", age))s, count: \(cachedExitVtxos.count))")
            if !cachedExitVtxos.isEmpty {
                print("   └─ Cached VTXOs:")
                for (index, vtxo) in cachedExitVtxos.enumerated() {
                    print("      [\(index)] ID: \(vtxo.vtxoId), Amount: \(vtxo.amountSats) sats, Claimable: \(vtxo.isClaimable), State: \(vtxo.stateDisplayName)")
                }
            }
            allExits = cachedExitVtxos
        } else {
            // Otherwise return cached value but trigger background refresh
            print("🔄 [Exit Cache] Cache stale or missing, triggering background refresh (cached count: \(cachedExitVtxos.count))")
            if !cachedExitVtxos.isEmpty {
                print("   └─ Returning stale cached VTXOs:")
                for (index, vtxo) in cachedExitVtxos.enumerated() {
                    print("      [\(index)] ID: \(vtxo.vtxoId), Amount: \(vtxo.amountSats) sats, Claimable: \(vtxo.isClaimable), State: \(vtxo.stateDisplayName)")
                }
            }
            Task {
                await refreshExitCache()
            }
            allExits = cachedExitVtxos
        }
        
        // Filter out claimed exits - they're complete and no longer active
        let activeExits = allExits.filter { !$0.isClaimed }
        
        if activeExits.count < allExits.count {
            print("   └─ Filtered out \(allExits.count - activeExits.count) claimed exit(s)")
        }
        
        return activeExits
    }
    
    /// Get all unilateral exits including claimed/completed ones
    /// Use this when you need to display complete exit history
    /// Uses cached data with 30-second TTL for performance
    var allUnilateralExits: [ExitVtxo] {
        // Get all exit VTXOs (claimed and unclaimed)
        let allExits: [ExitVtxo]
        
        // Return cached value if fresh
        if let cacheTime = exitVtxosCacheTime,
           Date().timeIntervalSince(cacheTime) < exitCacheTimeout {
            allExits = cachedExitVtxos
        } else {
            // Otherwise return cached value but trigger background refresh
            Task {
                await refreshExitCache()
            }
            allExits = cachedExitVtxos
        }
        
        return allExits
    }
    
    /// Get exits that require user action (claimable exits ready to be claimed)
    var exitsRequiringAction: [ExitVtxo] {
        activeUnilateralExits.filter { $0.isClaimable }
    }
    
    /// Check if there are any active unilateral exits in progress
    var hasActiveUnilateralExits: Bool {
        !activeUnilateralExits.isEmpty
    }
    
    /// Check if any exits require user action (ready to claim)
    var hasExitsRequiringAction: Bool {
        !exitsRequiringAction.isEmpty
    }
    
    // MARK: - Exit Cache Management
    
    /// Refresh exit cache from Bark SDK
    /// Called automatically when cache expires (30s TTL)
    func refreshExitCache() async {
        do {
            print("🔄 [Exit Cache] Refreshing exit cache...")
            cachedExitVtxos = try await getExitVtxos()
            exitVtxosCacheTime = Date()
            print("   ✅ Fetched \(cachedExitVtxos.count) exit VTXO(s)")
            
            // Also fetch and cache exit statuses for all active exits
            var newExitStatuses: [String: ExitTransactionStatus] = [:]
            var statusCount = 0
            var totalTxids = 0
            
            for exitVtxo in cachedExitVtxos where !exitVtxo.isClaimed {
                if let status = try? await getExitStatus(
                    vtxoId: exitVtxo.vtxoId,
                    includeHistory: true,
                    includeTransactions: true
                ) {
                    newExitStatuses[exitVtxo.vtxoId] = status
                    statusCount += 1
                    
                    // Log txids extracted from this status
                    let txids = ExitStatusParser.extractAllTransactionIds(from: status)
                    if !txids.isEmpty {
                        print("      📋 VTXO \(exitVtxo.vtxoId.prefix(16))... has \(txids.count) txid(s)")
                        totalTxids += txids.count
                    }
                }
            }
            cachedExitStatuses = newExitStatuses
            exitStatusesCacheTime = Date()
            
            print("   ✅ Cached \(statusCount) exit status(es) with \(totalTxids) total txid(s)")
            
            // Trigger re-linking after cache is refreshed
            print("   🔗 Triggering exit transaction re-linking...")
            await relinkExitTransactions()
            
        } catch {
            print("⚠️ Failed to refresh exit cache: \(error)")
            // Keep stale cache on error
        }
    }
    
    /// Force immediate exit cache refresh bypassing TTL
    /// Use this when you know exit state has changed
    func invalidateExitCache() {
        exitVtxosCacheTime = nil
        exitStatusesCacheTime = nil
        Task {
            await refreshExitCache()
            // After refreshing exit cache, trigger re-linking for exits
            await relinkExitTransactions()
        }
    }
    
    /// Re-link exit movements after exit status cache updates
    /// Called automatically when exit cache is refreshed
    private func relinkExitTransactions() async {
        guard let context = modelContext,
              let linkingService = transactionLinkingService else {
            return
        }
        await linkingService.relinkExitMovements(context: context)
    }
    
    /// Get cached exit status for a VTXO
    /// Returns nil if not in cache
    func getCachedExitStatus(for vtxoId: String) -> ExitTransactionStatus? {
        return cachedExitStatuses[vtxoId]
    }
    
    // MARK: - Exit Progression
    
    /// Manually trigger exit progression check
    /// Normally runs automatically, but can be triggered manually if needed
    func triggerExitProgression() {
        exitProgressionService?.triggerImmediateCheck()
    }
    
    /// Check if exit progression service is running
    var isExitProgressionRunning: Bool {
        exitProgressionService?.isRunning ?? false
    }
}
