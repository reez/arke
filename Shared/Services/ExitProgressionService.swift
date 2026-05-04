//
//  ExitProgressionService.swift
//  Ark wallet prototype
//
//  Created by Assistant on 2/5/26.
//

import Foundation
import SwiftUI
import Bark

/// Service responsible for automatically progressing unilateral exits in the background
/// 
/// This service runs a timer that periodically checks for active exits and progresses them
/// through their state machine. The Bark SDK handles all the complex exit logic - this
/// service just polls it regularly and triggers progression.
///
/// Exit Flow (Fully Automatic):
/// 1. User starts exit → SDK creates exit transactions (fee pre-approved)
/// 2. Service auto-progresses: Start → Processing → AwaitingDelta → Claimable (automatic)
/// 3. Service auto-claims: Claimable → ClaimInProgress → Claimed (automatic)
/// 4. Exit complete - funds moved to onchain wallet
///
/// Design:
/// - Foreground only: Pauses when app goes to background
/// - Timer-based: Checks every 5 minutes (configurable)
/// - SDK-driven: No complex state tracking, just polls SDK
/// - Silent failures: Logs errors but doesn't interrupt user
@MainActor
@Observable
class ExitProgressionService {
    
    // MARK: - Configuration
    
    /// How often to check for exit progression (in seconds)
    private let checkInterval: TimeInterval = 5 * 60 // 5 minutes
    
    // MARK: - State
    
    /// Whether the service is currently running
    private(set) var isRunning: Bool = false
    
    /// Last time exits were checked/progressed
    private(set) var lastCheckTime: Date?
    
    /// Last error encountered (for debugging)
    private(set) var lastError: String?
    
    // MARK: - Dependencies
    
    private let wallet: BarkWalletProtocol
    private weak var walletManager: WalletManager?
    
    // MARK: - Timer
    
    private var timer: Timer?
    
    // MARK: - Initialization
    
    init(wallet: BarkWalletProtocol) {
        self.wallet = wallet
    }
    
    /// Set the wallet manager reference (needed for cache invalidation)
    func setWalletManager(_ manager: WalletManager) {
        self.walletManager = manager
    }
    
    // MARK: - Lifecycle
    
    /// Start the exit progression service
    func start() {
        guard !isRunning else {
            print("⚠️ [ExitProgression] Service already running")
            return
        }
        
        print("▶️ [ExitProgression] Starting service (check interval: \(Int(checkInterval))s)")
        isRunning = true
        
        // Run initial check immediately
        Task {
            await checkAndProgressExits()
        }
        
        // Schedule timer for periodic checks
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndProgressExits()
            }
        }
    }
    
    /// Stop the exit progression service
    func stop() {
        guard isRunning else { return }
        
        print("⏹️ [ExitProgression] Stopping service")
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    /// Manually trigger an immediate check (in addition to scheduled checks)
    func triggerImmediateCheck() {
        guard isRunning else {
            print("⚠️ [ExitProgression] Cannot trigger check - service not running")
            return
        }
        
        print("🔄 [ExitProgression] Manual check triggered")
        Task {
            await checkAndProgressExits()
        }
    }
    
    // MARK: - Exit Progression Logic
    
    /// Check for active exits and progress them if needed
    private func checkAndProgressExits() async {
        let startTime = Date()
        print("🔍 [ExitProgression] Starting check at \(startTime)")
        
        do {
            // Step 1: Quick check - do we have any pending exits?
            let hasPending = try await wallet.hasPendingExits()
            
            if !hasPending {
                print("✅ [ExitProgression] No pending exits - skipping progression")
                lastCheckTime = Date()
                lastError = nil
                return
            }
            
            print("📋 [ExitProgression] Found pending exits - progressing...")
            
            // Step 2: Progress all exits (broadcasts, fee bumps, state updates)
            let statuses = try await wallet.progressExits(feeRateSatPerVb: nil)
            
            // Log what happened
            if statuses.isEmpty {
                print("   ℹ️ No exits progressed")
            } else {
                print("   ✅ Progressed \(statuses.count) exit(s):")
                for (index, status) in statuses.enumerated() {
                    if let error = status.error {
                        print("      [\(index)] VTXO \(status.vtxoId): ❌ Error: \(error)")
                    } else {
                        print("      [\(index)] VTXO \(status.vtxoId): ✅ Success")
                    }
                }
            }
            
            // Step 3: Check for claimable exits and auto-claim them
            let claimableExits = try await wallet.listClaimableExits()
            
            if !claimableExits.isEmpty {
                print("   💰 Found \(claimableExits.count) claimable exit(s) - auto-claiming...")
                try await autoClaimExits(claimableExits)
            }
            
            // Step 4: Sync exit state with blockchain
            try await wallet.syncExits()
            print("   ✅ Synced exit state")
            
            // Step 5: Invalidate cache to trigger UI updates
            walletManager?.invalidateExitCache()
            print("   ✅ Invalidated exit cache")
            
            // Success
            lastCheckTime = Date()
            lastError = nil
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ [ExitProgression] Check completed in \(String(format: "%.2f", duration))s")
            
        } catch {
            // Log error but don't stop the service
            let errorMessage = error.localizedDescription
            print("❌ [ExitProgression] Error during check: \(errorMessage)")
            lastError = errorMessage
            lastCheckTime = Date()
            
            // Continue running despite errors - will retry on next interval
        }
    }
    
    /// Automatically claim exits that have become claimable
    private func autoClaimExits(_ claimableExits: [ExitVtxo]) async throws {
        // Get the onchain address to send claimed funds to
        let address = try await wallet.getOnchainAddress()
        let claimableVtxoIds = claimableExits.map { $0.vtxoId }
        
        print("      Creating claim transaction for \(claimableVtxoIds.count) VTXO(s)...")
        
        // Step 1: Create the claim transaction
        let claimTx = try await wallet.drainExits(
            vtxoIds: claimableVtxoIds,
            address: address,
            feeRateSatPerVb: nil as UInt64?
        )
        
        let totalAmount = claimableExits.reduce(0) { $0 + $1.amountSats }
        print("      ✅ Claim transaction created (Amount: \(totalAmount) sats, Fee: \(claimTx.feeSats) sats)")
        
        // Step 2: Extract the raw transaction from PSBT
        let txHex = try wallet.extractTxFromPsbt(psbtBase64: claimTx.psbtBase64)
        
        // Step 3: Broadcast the transaction
        let txid = try await wallet.broadcastTx(txHex: txHex)
        print("      ✅ Claim transaction broadcast! TXID: \(txid)")
        
        // Step 4: Progress exits to sync state (updates to ClaimInProgress)
        let _ = try await wallet.progressExits(feeRateSatPerVb: nil as UInt64?)
        print("      ✅ Exit states updated to ClaimInProgress")
    }
    
    // MARK: - Manual Operations
    
    /// Manually progress exits (exposed for UI triggers)
    func progressExitsManually() async throws {
        print("🔄 [ExitProgression] Manual progression requested")
        
        let hasPending = try await wallet.hasPendingExits()
        guard hasPending else {
            print("   ℹ️ No pending exits to progress")
            return
        }
        
        let statuses = try await wallet.progressExits(feeRateSatPerVb: nil)
        try await wallet.syncExits()
        walletManager?.invalidateExitCache()
        
        print("   ✅ Manually progressed \(statuses.count) exit(s)")
    }
}
