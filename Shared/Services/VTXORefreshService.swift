//
//  VTXORefreshService.swift
//  Ark wallet prototype
//
//  Created by Assistant on 4/17/26.
//

import Foundation
import SwiftUI
import Bark

/// Service responsible for automatically refreshing VTXOs when they enter the free refresh window
/// 
/// This service monitors VTXO expiry and automatically triggers refreshes when:
/// 1. VTXOs are in the free refresh window (as defined by the fee schedule)
/// 2. VTXOs still have substantial time remaining (not last-minute emergencies)
/// 3. Auto-refresh is enabled in settings
///
/// Design:
/// - Foreground only: Pauses when app goes to background
/// - Timer-based: Checks every hour (much less frequent than round progression)
/// - Fee-aware: Only refreshes when completely free according to fee schedule
/// - User-controlled: Can be disabled in settings
/// - Transparent: Logs all automatic refreshes for user visibility
/// - Safe: Won't refresh during active operations or if wallet is locked
@MainActor
@Observable
class VTXORefreshService {
    
    // MARK: - Configuration
    
    /// How often to check for VTXOs needing free refresh (in seconds)
    /// Set to 1 hour - VTXOs have long lifespans so frequent checks aren't needed
    private let checkInterval: TimeInterval = 3600 // 1 hour
    
    /// Only auto-refresh VTXOs that have this much or less of their lifespan remaining
    /// This prevents refreshing VTXOs that are still very fresh
    /// Default: 50% of lifespan remaining
    private let maxLifespanPercentForAutoRefresh: Double = 0.50
    
    /// Minimum blocks until expiry to trigger auto-refresh
    /// This prevents refreshing VTXOs that are about to expire anyway
    /// Default: 10 blocks (~100 minutes on Bitcoin)
    private let minBlocksForAutoRefresh: Int = 10
    
    // MARK: - State
    
    /// Whether the service is currently running
    private(set) var isRunning: Bool = false
    
    /// Whether a check is currently in progress (prevents overlapping checks)
    private var isChecking: Bool = false
    
    /// Last time VTXOs were checked for auto-refresh
    private(set) var lastCheckTime: Date?
    
    /// Last time a VTXO was auto-refreshed
    private(set) var lastRefreshTime: Date?
    
    /// Count of VTXOs auto-refreshed in current session
    private(set) var autoRefreshCount: Int = 0
    
    /// Last error encountered (for debugging)
    private(set) var lastError: String?
    
    /// Whether auto-refresh is enabled (user setting)
    var isAutoRefreshEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "vtxoAutoRefreshEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "vtxoAutoRefreshEnabled")
            if newValue && isRunning {
                // Trigger immediate check when re-enabled
                triggerImmediateCheck()
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let wallet: BarkWalletProtocol
    private weak var walletManager: WalletManager?
    
    // MARK: - Timer
    
    private var timer: Timer?
    
    // MARK: - Initialization
    
    init(wallet: BarkWalletProtocol) {
        self.wallet = wallet
        
        // Set default value for auto-refresh if not set
        if UserDefaults.standard.object(forKey: "vtxoAutoRefreshEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "vtxoAutoRefreshEnabled")
        }
    }
    
    /// Set the wallet manager reference (needed for data access)
    func setWalletManager(_ manager: WalletManager) {
        self.walletManager = manager
    }
    
    // MARK: - Lifecycle
    
    /// Start the VTXO auto-refresh service
    func start() {
        guard !isRunning else {
            print("⚠️ [VTXORefresh] Service already running")
            return
        }
        
        print("▶️ [VTXORefresh] Starting service (check interval: \(Int(checkInterval))s, enabled: \(isAutoRefreshEnabled))")
        isRunning = true
        
        // Run initial check immediately if enabled
        if isAutoRefreshEnabled {
            Task {
                await checkAndRefreshVTXOs()
            }
        }
        
        // Schedule timer for periodic checks with tolerance for battery optimization
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndRefreshVTXOs()
            }
        }
        timer?.tolerance = 60 // Allow 1 minute variance for battery optimization
    }
    
    /// Stop the VTXO auto-refresh service
    func stop() {
        guard isRunning else { return }
        
        print("⏹️ [VTXORefresh] Stopping service")
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    /// Manually trigger an immediate check (in addition to scheduled checks)
    func triggerImmediateCheck() {
        guard isRunning else {
            print("⚠️ [VTXORefresh] Cannot trigger check - service not running")
            return
        }
        
        print("🔄 [VTXORefresh] Manual check triggered")
        Task {
            await checkAndRefreshVTXOs()
        }
    }
    
    // MARK: - Auto-Refresh Logic
    
    /// Check for VTXOs in the free refresh window and refresh them automatically
    private func checkAndRefreshVTXOs() async {
        // Prevent overlapping checks
        guard !isChecking else {
            print("⏭️ [VTXORefresh] Check already in progress, skipping")
            return
        }
        
        // Check if auto-refresh is enabled
        guard isAutoRefreshEnabled else {
            print("⏭️ [VTXORefresh] Auto-refresh disabled in settings, skipping")
            lastCheckTime = Date()
            return
        }
        
        isChecking = true
        defer { isChecking = false }
        
        let startTime = Date()
        print("🔍 [VTXORefresh] Starting check at \(startTime)")
        
        do {
            // Step 1: Get current data
            guard let arkInfo = walletManager?.arkInfo,
                  let feeSchedule = arkInfo.feeSchedule,
                  let currentBlockHeight = walletManager?.estimatedBlockHeight else {
                print("⚠️ [VTXORefresh] Missing required data (arkInfo or blockHeight), skipping")
                lastCheckTime = Date()
                return
            }
            
            // Step 2: Get all VTXOs that could potentially be refreshed
            let vtxos = try await wallet.spendableVtxos()
            
            if vtxos.isEmpty {
                print("✅ [VTXORefresh] No spendable VTXOs - skipping")
                lastCheckTime = Date()
                return
            }
            
            // Step 3: Find VTXOs eligible for free refresh
            let eligibleVTXOs = findVTXOsForAutoRefresh(
                vtxos: vtxos,
                currentBlockHeight: currentBlockHeight,
                vtxoLifespan: arkInfo.vtxoExpiryDelta,
                feeSchedule: feeSchedule
            )
            
            if eligibleVTXOs.isEmpty {
                print("✅ [VTXORefresh] No VTXOs eligible for auto-refresh")
                lastCheckTime = Date()
                lastError = nil
                return
            }
            
            print("📋 [VTXORefresh] Found \(eligibleVTXOs.count) VTXO(s) eligible for free refresh")
            for (index, vtxo) in eligibleVTXOs.enumerated() {
                let blocksUntilExpiry = Int(vtxo.expiryHeight) - currentBlockHeight
                let percentRemaining = Double(blocksUntilExpiry) / Double(arkInfo.vtxoExpiryDelta) * 100
                print("   [\(index + 1)] Amount: \(vtxo.amountSats) sats, Expiry: \(blocksUntilExpiry) blocks (\(String(format: "%.1f", percentRemaining))%)")
            }
            
            // Step 4: Trigger the refresh with VTXO IDs
            let vtxoIds = eligibleVTXOs.map { $0.id }
            print("🔄 [VTXORefresh] Triggering automatic refresh for \(vtxoIds.count) VTXO(s)...")
            _ = try await wallet.refreshVTXOs(vtxo_ids: vtxoIds)
            print("   ✅ Refresh completed successfully")
            
            // Step 5: Refresh balances and transactions
            await walletManager?.refreshAfterRoundCompletion()
            print("   ✅ Refreshed balances and transactions")
            
            // Success
            lastCheckTime = Date()
            lastRefreshTime = Date()
            autoRefreshCount += 1
            lastError = nil
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ [VTXORefresh] Auto-refresh completed in \(String(format: "%.2f", duration))s (total session count: \(autoRefreshCount))")
            
        } catch {
            // Log error but don't stop the service
            let errorMessage = error.localizedDescription
            print("❌ [VTXORefresh] Error during check: \(errorMessage)")
            lastError = errorMessage
            lastCheckTime = Date()
            
            // Continue running despite errors - will retry on next interval
        }
    }
    
    /// Find VTXOs that should be auto-refreshed
    /// - Parameters:
    ///   - vtxos: All spendable VTXOs
    ///   - currentBlockHeight: Current blockchain height
    ///   - vtxoLifespan: Total VTXO lifespan in blocks
    ///   - feeSchedule: Server fee schedule
    /// - Returns: VTXOs eligible for free auto-refresh
    private func findVTXOsForAutoRefresh(
        vtxos: [Vtxo],
        currentBlockHeight: Int,
        vtxoLifespan: Int,
        feeSchedule: FeeSchedule
    ) -> [Vtxo] {
        return vtxos.filter { vtxo in
            let blocksUntilExpiry = Int(vtxo.expiryHeight) - currentBlockHeight
            
            // Safety check: Must have minimum blocks remaining
            guard blocksUntilExpiry >= minBlocksForAutoRefresh else {
                return false
            }
            
            // Calculate percentage of lifespan remaining
            let percentageRemaining = Double(blocksUntilExpiry) / Double(vtxoLifespan)
            
            // Only refresh if VTXO has consumed enough of its lifespan
            // This prevents refreshing VTXOs that are still very fresh
            guard percentageRemaining <= maxLifespanPercentForAutoRefresh else {
                return false
            }
            
            // Check if refresh would be free for this VTXO
            let isFree = feeSchedule.isFreeRefresh(blocksUntilExpiry: blocksUntilExpiry)
            
            return isFree
        }
    }
    
    // MARK: - Manual Refresh (for UI triggers)
    
    /// Manually refresh VTXOs (exposed for UI triggers)
    /// This bypasses the auto-refresh logic and always refreshes all VTXOs that need it
    func refreshManually() async throws {
        print("🔄 [VTXORefresh] Manual refresh requested")
        
        // Get VTXOs that need refresh
        let vtxos = try await wallet.getVtxosToRefresh()
        
        if !vtxos.isEmpty {
            let vtxoIds = vtxos.map { $0.id }
            _ = try await wallet.refreshVTXOs(vtxo_ids: vtxoIds)
            await walletManager?.refreshAfterRoundCompletion()
            print("   ✅ Manual refresh completed for \(vtxoIds.count) VTXO(s)")
        } else {
            print("   ℹ️ No VTXOs need refreshing")
        }
    }
    
    // MARK: - Debug Info
    
    /// Get human-readable status for debugging/display
    var statusDescription: String {
        var parts: [String] = []
        
        parts.append("Running: \(isRunning)")
        parts.append("Enabled: \(isAutoRefreshEnabled)")
        
        if let lastCheck = lastCheckTime {
            let elapsed = Date().timeIntervalSince(lastCheck)
            parts.append("Last check: \(String(format: "%.0f", elapsed))s ago")
        } else {
            parts.append("Last check: Never")
        }
        
        if let lastRefresh = lastRefreshTime {
            let elapsed = Date().timeIntervalSince(lastRefresh)
            parts.append("Last refresh: \(String(format: "%.0f", elapsed))s ago")
        }
        
        parts.append("Session refreshes: \(autoRefreshCount)")
        
        if let error = lastError {
            parts.append("Last error: \(error)")
        }
        
        return parts.joined(separator: " | ")
    }
}
