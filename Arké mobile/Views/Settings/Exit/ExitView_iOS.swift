//
//  ExitView_iOS.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//

// MARK: - Outstanding Issues & TODOs

// TODO: Exit Transaction ID Generation (HIGH PRIORITY)
// Currently using a workaround to generate exit IDs by prefixing VTXO txids with "exit_"
// or falling back to timestamps. The manager.startExit() should return the actual exit
// transaction ID from the Bark SDK.
// Location: startExit() -> exitTxid generation
// Fix: Update WalletManager.startExit() to return the exit transaction ID

// TODO: Hard-coded Challenge Period (MEDIUM PRIORITY)
// The 144-block challenge period is hard-coded. This should come from the Bark SDK
// or server configuration, as different Ark implementations may use different periods.
// Location: startExit() -> challengePeriodEndHeight calculation
// Also affects: ExitProgressBar_iOS totalBlocks calculation
// Fix: Add manager.getChallengePeriod() or include in exit result

// TODO: Fee Rate Estimation (MEDIUM PRIORITY)
// Both progressExits() and drainExits() currently pass nil for fee rates.
// Should implement proper fee estimation or provide user selection UI.
// Locations: refreshExitStatus() and claimExit()
// Fix: Integrate fee estimation service (mempool.space, Bitcoin Core, etc.)
// Consider: Add user preference for fee urgency (low/medium/high)

// TODO: PSBT Handling Clarification (HIGH PRIORITY)
// After drainExits() creates a claim transaction PSBT, it's unclear if it's
// automatically signed and broadcast, or if additional steps are needed.
// Location: claimExit() after manager.drainExits()
// Fix: Document or implement explicit signing/broadcasting if needed

// TODO: Silent Refresh Failures (MEDIUM PRIORITY)
// refreshExitStatus() silently fails without user feedback. Consider adding
// a "last updated" timestamp or retry mechanism for better UX.
// Location: refreshExitStatus() catch block
// Consider: Add @State var lastRefreshDate and display in UI

// NOTE: Exit Status State Machine
// The app tracks exit status through OngoingUnilateralExit.status enum:
// broadcasted -> inChallengePeriod -> matured -> claimable -> claimed
// The Bark SDK may have its own state tracking that needs to be synchronized.

import SwiftUI
import Bark

struct ExitView_iOS: View {
    @Environment(WalletManager.self) var manager
    
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingStartConfirmation = false
    @State private var showingClaimConfirmation = false
    @State private var showingError = false
    
    // Computed properties
    private var activeExit: OngoingUnilateralExit? {
        manager.activeUnilateralExits.first
    }
    
    private var hasActiveExit: Bool {
        activeExit != nil
    }
    
    private var currentBlockHeight: Int {
        manager.estimatedBlockHeight ?? 0
    }
    
    private var spendableBalance: Int {
        manager.arkBalance?.spendableSat ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let exit = activeExit {
                    // State B or C: Exit exists
                    if exit.status == .claimable {
                        ClaimableExitView_iOS(
                            exit: exit,
                            isProcessing: isProcessing,
                            onClaim: { showingClaimConfirmation = true }
                        )
                    } else {
                        ActiveExitView_iOS(
                            exit: exit,
                            currentBlockHeight: currentBlockHeight
                        )
                    }
                } else {
                    // State A: No active exit
                    NoExitView_iOS(
                        spendableBalance: spendableBalance,
                        isProcessing: isProcessing,
                        onStartExit: { showingStartConfirmation = true }
                    )
                }
            }
            .padding()
        }
        .task {
            await refreshExitStatus()
        }
        .refreshable {
            await refreshExitStatus()
        }
        .alert("Start Unilateral Exit", isPresented: $showingStartConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Start Exit") {
                Task {
                    await startExit()
                }
            }
        } message: {
            Text("Exit \(BitcoinFormatter.shared.formatAmount(spendableBalance))? This process takes approximately 24 hours to complete and cannot be cancelled.")
        }
        .alert("Claim Funds", isPresented: $showingClaimConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Claim") {
                Task {
                    await claimExit()
                }
            }
        } message: {
            if let exit = activeExit {
                Text("Claim \(exit.formattedAmount) to your wallet's onchain address?")
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .overlay {
            if isProcessing {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .controlSize(.large)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startExit() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Get all spendable VTXOs to track them
            let vtxos = try await manager.getVTXOs()
            let spendableVTXOs = vtxos.filter { $0.state == .spendable }
            let vtxoOutpoints = spendableVTXOs.map { $0.id }
            
            print("🚪 Starting unilateral exit for \(spendableVTXOs.count) VTXOs...")
            
            // Start exit via wallet manager
            let result = try await manager.startExit()
            print("✅ Exit started: \(result)")
            
            // Generate exit ID from the VTXOs being exited
            // Since we don't have direct access to the exit transaction ID yet,
            // we'll use a combination of the first VTXO ID and timestamp
            let exitTxid: String
            if let firstVtxoId = vtxoOutpoints.first {
                // Extract the txid from the first VTXO outpoint (format: "txid:vout")
                if let colonIndex = firstVtxoId.firstIndex(of: ":") {
                    let vtxoTxid = String(firstVtxoId[..<colonIndex])
                    exitTxid = "exit_\(vtxoTxid)"
                } else {
                    exitTxid = "exit_\(firstVtxoId)"
                }
                print("   Exit ID: \(exitTxid)")
            } else {
                // Fallback to timestamp-based ID if no VTXOs
                exitTxid = "exit_\(Date().timeIntervalSince1970)"
                print("   Exit ID (fallback): \(exitTxid)")
            }
            
            // Estimate challenge period end (typically ~144 blocks from now)
            let challengePeriodEndHeight = currentBlockHeight + 144
            
            // Track in ProcessStateService
            try manager.startUnilateralExit(
                exitTxid: exitTxid,
                challengePeriodEndHeight: challengePeriodEndHeight,
                vtxoOutpoints: vtxoOutpoints,
                totalAmountSat: spendableBalance
            )
            
            print("✅ Unilateral exit started and tracked")
            
            // Refresh wallet state
            await manager.refresh()
            
        } catch {
            print("❌ Failed to start exit: \(error)")
            errorMessage = "Failed to start exit: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func claimExit() async {
        guard let exit = activeExit else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            print("💰 Claiming exit funds...")
            
            // Get a new address from the wallet
            let address = manager.onchainAddress
            
            print("   Claiming to address: \(address)")
            
            // Claim the exit funds
            let claimTx = try await manager.drainExits(
                vtxoIds: exit.vtxoOutpoints,
                address: address,
                feeRateSatPerVb: nil as UInt64?
            )
            
            print("✅ Exit claim transaction created")
            print("   Fee: \(claimTx.feeSats) sats")
            print("   PSBT length: \(claimTx.psbtBase64.count) bytes")
            
            // Mark exit as claimed in ProcessStateService
            try manager.markExitClaimed(exitTxid: exit.exitTxid)
            
            print("✅ Exit marked as claimed")
            
            // Refresh wallet state
            await manager.refresh()
            
        } catch {
            print("❌ Failed to claim exit: \(error)")
            errorMessage = "Failed to claim exit: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func refreshExitStatus() async {
        guard hasActiveExit else { return }
        
        do {
            // Progress exits (broadcast, fee bump, advance state machine)
            let statuses = try await manager.progressExits(feeRateSatPerVb: nil as UInt64?)
            print("✅ Progressed \(statuses.count) exit(s)")
            
            // Sync exit state
            try await manager.syncExits()
            print("✅ Exit state synced")
            
            // Refresh the wallet
            await manager.refresh()
            
        } catch {
            print("⚠️ Failed to refresh exit status: \(error)")
            // Don't show error to user for background refresh failures
        }
    }
}

// MARK: - Preview

#Preview("No Exit") {
    NavigationStack {
        ExitView_iOS()
            .environment(WalletManager())
    }
}

#Preview("Exit In Progress") {
    NavigationStack {
        ExitView_iOS()
            .environment(WalletManager())
    }
}

#Preview("Exit Claimable") {
    NavigationStack {
        ExitView_iOS()
            .environment(WalletManager())
    }
}
