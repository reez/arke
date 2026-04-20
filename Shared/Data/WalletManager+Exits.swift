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
    
    /// All unilateral exits (including claimed/completed ones)
    /// Use this when you need to show complete exit history
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
    
    /// Exits requiring user action (claimable)
    var exitsRequiringAction: [ExitVtxo] {
        activeUnilateralExits.filter { $0.isClaimable }
    }
    
    /// Whether there are active unilateral exits
    var hasActiveUnilateralExits: Bool {
        !activeUnilateralExits.isEmpty
    }
    
    /// Whether any exits require user action
    var hasExitsRequiringAction: Bool {
        !exitsRequiringAction.isEmpty
    }
    
    /// Refresh exit cache from Bark SDK
    private func refreshExitCache() async {
        do {
            cachedExitVtxos = try await getExitVtxos()
            exitVtxosCacheTime = Date()
        } catch {
            print("⚠️ Failed to refresh exit cache: \(error)")
            // Keep stale cache on error
        }
    }
    
    /// Force immediate exit cache refresh
    func invalidateExitCache() {
        exitVtxosCacheTime = nil
        Task {
            await refreshExitCache()
        }
    }
    
    // MARK: - Exit Progression Service
    
    /// Manually trigger exit progression (in addition to automatic checks)
    func triggerExitProgression() {
        exitProgressionService?.triggerImmediateCheck()
    }
    
    /// Check if exit progression service is running
    var isExitProgressionRunning: Bool {
        exitProgressionService?.isRunning ?? false
    }
}
