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
import ArkeUI

struct ExitView_iOS: View {
    @Environment(WalletManager.self) var manager
    
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingStartConfirmation = false
    @State private var showingClaimConfirmation = false
    @State private var showingError = false
    @State private var activeExits: [ExitVtxo] = []
    @State private var claimableHeight: UInt32?
    @State private var exitCostEstimate: ExitCostEstimate?
    @State private var isEstimatingCost = false
    
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
    
    private var onchainBalance: UInt64 {
        UInt64(manager.onchainBalance?.totalSat ?? 0)
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
                        isProcessing: isProcessing || isEstimatingCost,
                        onStartExit: { 
                            Task {
                                await estimateExitCost()
                                showingStartConfirmation = true
                            }
                        },
                        exitCostEstimate: exitCostEstimate,
                        onchainBalance: onchainBalance,
                        isConnectedToServer: manager.connectionStatus.isConnected
                    )
                }
            }
            .padding()
        }
        .task {
            await loadExitData()
            if !hasActiveExit && spendableBalance > 0 {
                await estimateExitCost()
            }
        }
        .refreshable {
            await loadExitData()
            if !hasActiveExit && spendableBalance > 0 {
                await estimateExitCost()
            }
        }
        .alert("button_start_recovery", isPresented: $showingStartConfirmation) {
            Button("Cancel", role: .cancel) { }
            if let estimate = exitCostEstimate, !estimate.canAfford {
                Button("Board Funds") {
                    // TODO: Navigate to board flow
                }
            } else {
                Button("button_start") {
                    Task {
                        await startExit()
                    }
                }
            }
        } message: {
            if let estimate = exitCostEstimate {
                if estimate.canAfford {
                    /*
                    Text("""
                    Recover \(BitcoinFormatter.shared.formatAmount(spendableBalance))?
                    
                    Estimated cost: \(BitcoinFormatter.shared.formatAmount(Int(estimate.totalCost)))
                    Fee rate: \(estimate.feeRate) sat/vB
                    
                    This takes about 24 hours and cannot be cancelled.
                    """)
                    */
                    Text("This takes about 24 hours and cannot be cancelled.")
                } else {
                    Text("""
                    ⚠️ Insufficient onchain balance
                    
                    Required: \(BitcoinFormatter.shared.formatAmount(Int(estimate.totalCost)))
                    Available: \(BitcoinFormatter.shared.formatAmount(Int(estimate.onchainBalance)))
                    Need to board: \(BitcoinFormatter.shared.formatAmount(Int(estimate.shortfall)))
                    
                    Please board more Bitcoin to your savings balance before starting.
                    """)
                }
            } else {
                Text(String(localized: "balance_confirm_recover", defaultValue: "Recover \(BitcoinFormatter.shared.formatAmount(spendableBalance))? It takes about 24 hours and cannot be cancelled."))
            }
        }
        .tint(Color.Arke.gold3)
        .alert("button_start_withdrawal", isPresented: $showingClaimConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("button_start") {
                Task {
                    await claimExit()
                }
            }
        } message: {
            if let exit = firstExit {
                Text(String(localized: "balance_confirm_withdraw_alt", defaultValue: "Withdraw \(exit.formattedAmount) to your wallet's savings balance?"))
            }
        }
        .alert("error_title", isPresented: $showingError) {
            Button("button_ok") { }
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
    
    private func estimateExitCost() async {
        guard spendableBalance > 0 else { return }
        
        isEstimatingCost = true
        defer { isEstimatingCost = false }
        
        do {
            print("💰 Estimating exit cost...")
            
            // Get current fee rate (query Esplora or use estimate)
            let feeRate = try await estimateCurrentFeeRate()
            print("   Fee rate: \(feeRate) sat/vB")
            
            // Get spendable VTXOs count (approximate - we'll exit all of them)
            let vtxos = try await manager.getVTXOs()
            // Count only spendable ones (not locked in pending operations)
            let vtxoCount = vtxos.filter { $0.state == .spendable }.count
            print("   VTXOs to exit: \(vtxoCount)")
            
            // Estimate transaction costs
            let estimate = calculateExitCost(
                vtxoCount: vtxoCount,
                feeRateSatPerVb: feeRate,
                onchainBalance: onchainBalance
            )
            
            print("   Estimated cost: \(estimate.totalCost) sats")
            print("   Can afford: \(estimate.canAfford)")
            
            exitCostEstimate = estimate
            
        } catch {
            print("⚠️ Failed to estimate exit cost: \(error)")
            // Don't block the user - just skip the estimate
            exitCostEstimate = nil
        }
    }
    
    private func estimateCurrentFeeRate() async throws -> UInt64 {
        // Try to get fee estimate from config
        let config = try await manager.getConfig()
        
        // For Signet, use conservative estimate
        // For mainnet, would query fee estimation API
        let defaultFeeRate: UInt64 = switch config.network {
        case "mainnet": 50
        case "signet": 10
        case "regtest": 1
        default: 10
        }
        
        // TODO: Query Esplora fee estimates endpoint for more accurate rates
        // let esploraUrl = config.esploraBaseURL
        // let feeEstimates = try await fetchEsploraFees(esploraUrl)
        // return feeEstimates.fastTarget
        
        return defaultFeeRate
    }
    
    private func calculateExitCost(
        vtxoCount: Int,
        feeRateSatPerVb: UInt64,
        onchainBalance: UInt64
    ) -> ExitCostEstimate {
        // Base transaction size estimates (in weight units)
        // These are conservative estimates based on typical exit transaction sizes
        let baseExitTxWeight: UInt64 = 2000  // ~500 vbytes per exit tx
        let cpfpTxWeight: UInt64 = 600       // ~150 vbytes for CPFP child
        
        // Calculate per-VTXO cost
        let perVtxoPackageWeight = baseExitTxWeight + cpfpTxWeight
        let totalWeight = perVtxoPackageWeight * UInt64(max(vtxoCount, 1))
        
        // Convert weight to vbytes and calculate base fee
        let totalVbytes = totalWeight / 4
        let baseFee = totalVbytes * feeRateSatPerVb
        
        // Apply CPFP multiplier (Bark uses 2x - see util.rs:43 in Bark repo)
        // This accounts for the need to bump parent transaction fees
        let cpfpMultiplier: Double = 2.0
        let totalFee = UInt64(Double(baseFee) * cpfpMultiplier)
        
        // Add safety margin (20% for fee rate fluctuations and estimation errors)
        let safetyMargin = UInt64(Double(totalFee) * 0.20)
        let totalCost = totalFee + safetyMargin
        
        let canAfford = onchainBalance >= totalCost
        
        return ExitCostEstimate(
            totalCost: totalCost,
            feeRate: feeRateSatPerVb,
            canAfford: canAfford,
            onchainBalance: onchainBalance
        )
    }
    
    private func loadExitData() async {
        do {
            // Load active exits from Bark SDK (filter out completed/claimed exits)
            let allExits = try await manager.getExitVtxos()
            
            print("📊 All Exit VTXOs from getExitVtxos():")
            print("   Count: \(allExits.count)")
            for (index, exit) in allExits.enumerated() {
                print("\n   [\(index)] Full Object Dump:")
                
                // Use Mirror to inspect all properties
                let mirror = Mirror(reflecting: exit)
                for child in mirror.children {
                    if let label = child.label {
                        print("       \(label): \(child.value)")
                    }
                }
                
                // Print the computed/extension properties we know about
                print("\n       Computed Properties:")
                print("       vtxoId: \(exit.vtxoId)")
                print("       amountSats: \(exit.amountSats)")
                print("       formattedAmount: \(exit.formattedAmount)")
                print("       shortVtxoId: \(exit.shortVtxoId)")
                print("       state: \(exit.state)")
                print("       stateDisplayName: \(exit.stateDisplayName)")
                print("       isActive: \(exit.isActive)")
                print("       isClaimable: \(exit.isClaimable)")
                print("       isClaimed: \(exit.isClaimed)")
                print("       stateIcon: \(exit.stateIcon)")
                print("       stateColor: \(exit.stateColor)")
            }
            
            activeExits = allExits.filter { $0.isActive }
            
            print("\n🔍 Filtered Active Exits:")
            print("   Count: \(activeExits.count)")
            for (index, exit) in activeExits.enumerated() {
                print("   [\(index)] VTXO ID: \(exit.vtxoId)")
                print("       Amount: \(exit.amountSats) sats (\(exit.formattedAmount))")
                print("       State: \(exit.state)")
                print("       State Display: \(exit.stateDisplayName)")
                print("       isClaimable: \(exit.isClaimable)")
            }
            
            // Get claimable height if there are exits
            if !activeExits.isEmpty {
                claimableHeight = try await manager.allExitsClaimableAtHeight()
            }
            
            print("   claimableHeight: \(claimableHeight.map(String.init) ?? "nil")")
            
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
