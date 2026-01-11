//
//  ExitView_iOS.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//

// MARK: - Outstanding Issues & TODOs

// TODO: Fee Rate Estimation (MEDIUM PRIORITY)
// Both progressExits() and drainExits() currently pass nil for fee rates.
// Should implement proper fee estimation or provide user selection UI.
// Locations: refreshExitStatus() and claimExit()
// Fix: Integrate fee estimation service (mempool.space, Bitcoin Core, etc.)
// Consider: Add user preference for fee urgency (low/medium/high)

// TODO: Offline Claim Broadcast Fallback (LOW PRIORITY)
// Currently, drainExits() creates a signed PSBT and progressExits() broadcasts it
// via the Ark server. In the future, we may want a fallback option to manually
// broadcast the PSBT if the Ark server is unavailable.
// Location: claimExit() after manager.drainExits()
// Enhancement: Add manual broadcast capability using Bitcoin Core/Esplora API

// NOTE: Exit Status State Machine
// The Bark SDK tracks exit status through its own state machine:
// Start → Processing → AwaitingDelta → Claimable → ClaimInProgress → Claimed
// We query this directly and no longer maintain app-level tracking.

import SwiftUI
import Bark

struct ExitView_iOS: View {
    @Environment(WalletManager.self) var manager
    
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingStartConfirmation = false
    @State private var showingClaimConfirmation = false
    @State private var showingError = false
    @State private var activeExits: [ExitVtxo] = []
    @State private var claimableHeight: UInt32?
    
    // Computed properties
    private var firstExit: ExitVtxo? {
        activeExits.first
    }
    
    private var hasActiveExit: Bool {
        !activeExits.isEmpty
    }
    
    private var hasClaimableExit: Bool {
        activeExits.contains { $0.isClaimable }
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
                if let exit = firstExit {
                    // State B or C: Exit exists
                    if exit.isClaimable {
                        ClaimableExitView_iOS(
                            exit: exit,
                            isProcessing: isProcessing,
                            onClaim: { showingClaimConfirmation = true }
                        )
                    } else {
                        ActiveExitView_iOS(
                            exit: exit,
                            currentBlockHeight: currentBlockHeight,
                            claimableHeight: Int(claimableHeight ?? 0)
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
            await loadExitData()
        }
        .refreshable {
            await loadExitData()
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
            if let exit = firstExit {
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
    
    private func loadExitData() async {
        do {
            // Load active exits from Bark SDK
            activeExits = try await manager.getExitVtxos()
            
            // Get claimable height if there are exits
            if !activeExits.isEmpty {
                claimableHeight = try await manager.allExitsClaimableAtHeight()
            }
            
            // Progress exits (broadcast, fee bump, advance state machine)
            if !activeExits.isEmpty {
                let statuses = try await manager.progressExits(feeRateSatPerVb: nil as UInt64?)
                print("✅ Progressed \(statuses.count) exit(s)")
            }
            
            // Sync exit state
            try await manager.syncExits()
            
        } catch {
            print("⚠️ Failed to load exit data: \(error)")
            // Don't show error to user for background refresh failures
        }
    }
    
    private func startExit() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            print("🚪 Starting unilateral exit...")
            
            // Start exit via wallet manager (Bark SDK handles all tracking)
            let result = try await manager.startExit()
            print("✅ Exit started: \(result)")
            
            // Refresh wallet state and exit data
            await manager.refresh()
            await loadExitData()
            
        } catch {
            print("❌ Failed to start exit: \(error)")
            errorMessage = "Failed to start exit: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func claimExit() async {
        guard let exit = firstExit, exit.isClaimable else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            print("💰 Claiming exit funds...")
            
            // Get a new address from the wallet
            let address = manager.onchainAddress
            
            print("   Claiming to address: \(address)")
            
            // Claim the exit funds - use all exits or just this one?
            // For now, claim all claimable exits
            let claimableVtxoIds = activeExits.filter { $0.isClaimable }.map { $0.vtxoId }
            
            // Step 1: Create the claim transaction (returns signed PSBT)
            let claimTx = try await manager.drainExits(
                vtxoIds: claimableVtxoIds,
                address: address,
                feeRateSatPerVb: nil as UInt64?
            )
            
            print("✅ Exit claim transaction created")
            print("   📦 ClaimTx Object Details:")
            print("      Fee: \(claimTx.feeSats) sats")
            print("      PSBT Base64 length: \(claimTx.psbtBase64.count) characters")
            print("      PSBT Base64 prefix (first 100 chars): \(String(claimTx.psbtBase64.prefix(100)))")
            print("      PSBT Base64 suffix (last 50 chars): \(String(claimTx.psbtBase64.suffix(50)))")
            
            // Step 2: Extract the raw transaction hex from the PSBT
            print("🔧 Extracting raw transaction from PSBT...")
            let txHex = try await manager.extractTxFromPsbt(psbtBase64: claimTx.psbtBase64)
            print("✅ Transaction extracted")
            print("   Tx hex length: \(txHex.count) characters")
            print("   Tx hex prefix (first 100 chars): \(String(txHex.prefix(100)))")
            print("   Tx hex suffix (last 50 chars): \(String(txHex.suffix(50)))")
            
            // Step 3: Broadcast the transaction to the Bitcoin network
            print("📡 Broadcasting claim transaction to Bitcoin network...")
            let txid = try await manager.broadcastTx(txHex: txHex)
            print("✅ Transaction broadcast successful!")
            print("   🎉 TXID: \(txid)")
            
            // Step 4: Progress exits to sync the state machine with the SDK
            print("🔄 Syncing exit state via progressExits()...")
            let progressStatuses = try await manager.progressExits(feeRateSatPerVb: nil as UInt64?)
            print("✅ Progressed \(progressStatuses.count) exit(s) after claim")
            
            // Log progress status details for debugging
            if !progressStatuses.isEmpty {
                print("   📋 Progress Statuses Details:")
                for (index, status) in progressStatuses.enumerated() {
                    print("      [\(index)] VTXO ID: \(status.vtxoId)")
                    if let error = status.error {
                        print("          ⚠️ Error: \(error)")
                    }
                }
            }
            
            // Refresh wallet state and exit data
            await manager.refresh()
            await loadExitData()
            
        } catch {
            print("❌ Failed to claim exit: \(error)")
            errorMessage = "Failed to claim exit: \(error.localizedDescription)"
            showingError = true
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
