//
//  ExitStatusDetailView_iOS.swift
//  Arké
//
//  Created by Christoph on 1/8/26.
//

import SwiftUI
import Bark
import ArkeUI

struct ExitStatusDetailView_iOS: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.dismiss) private var dismiss
    
    let exitVtxo: ExitVtxo
    
    @State private var status: ExitTransactionStatus?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "label_basic_info")) {
                    LabeledContent("VTXO ID") {
                        Text(exitVtxo.vtxoId)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    
                    LabeledContent("Amount", value: "\(exitVtxo.amountSats) sats")
                    
                    LabeledContent("State") {
                        HStack {
                            Circle()
                                .fill(exitVtxo.isClaimable ? Color.Arke.green : Color.Arke.orange)
                                .frame(width: 8, height: 8)
                            Text(exitVtxo.state)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    LabeledContent(String(localized: "balance_is_claimable")) {
                        HStack {
                            Image(systemName: exitVtxo.isClaimable ? "checkmark.circle.fill" : "clock")
                                .foregroundStyle(exitVtxo.isClaimable ? Color.Arke.green : Color.Arke.orange)
                            Text(exitVtxo.isClaimable ? String(localized: "button_yes") : String(localized: "button_no"))
                        }
                    }
                }
                
                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text(String(localized: "status_loading_status"))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let error = error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Color.Arke.red)
                    }
                } else if let status = status {
                    // Parsed state information
                    if let parsed = status.parsedState {
                        ParsedStateSection(parsed: parsed)
                    }
                    
                    // Transaction chain
                    if !status.transactionChain.isEmpty {
                        TransactionChainSection(transactions: status.transactionChain)
                    }
                    
                    // All extracted transaction IDs
                    if !status.allTransactionIds.isEmpty {
                        TransactionIdsSection(txids: status.allTransactionIds)
                    }
                    
                    // Confirmed transactions
                    if !status.confirmedTransactions.isEmpty {
                        ConfirmedTransactionsSection(confirmed: status.confirmedTransactions)
                    }
                    
                    // Raw state (for debugging)
                    Section("Raw State") {
                        LabeledContent("Current State") {
                            Text(status.state)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(3)
                        }
                        
                        LabeledContent(String(localized: "activity_transaction_count"), value: "\(status.transactionCount)")
                    }
                    
                    // State history
                    if let history = status.history, !history.isEmpty {
                        Section(String(localized: "data_state_history")) {
                            ForEach(Array(history.enumerated()), id: \.offset) { index, state in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("#\(index + 1)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 30, alignment: .leading)
                                        
                                        if let parsed = ExitStatusParser.parseState(state) {
                                            ParsedStateLabel(parsed: parsed)
                                        } else {
                                            Text(state)
                                                .font(.system(.caption, design: .monospaced))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("balance_exit_status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Dismiss the detail sheet
                    Button("button_done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    // Refresh the detailed exit status
                    Button {
                        Task {
                            await loadStatus()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await loadStatus()
            }
        }
    }
    
    private func loadStatus() async {
        isLoading = true
        error = nil
        
        do {
            // Sync wallet and exit state before checking status
            print("🔄 Syncing wallet state...")
            try await walletManager.sync()
            print("✅ Wallet synced")
            
            print("🔄 Syncing exit state...")
            try await walletManager.syncExits()
            print("✅ Exit state synced")
            
            // Now get the detailed exit status
            status = try await walletManager.getExitStatus(
                vtxoId: exitVtxo.vtxoId,
                includeHistory: true,
                includeTransactions: true
            )
            
            if let status = status {
                print("✅ Loaded exit status for \(exitVtxo.vtxoId)")
                print("🔍 DEBUG: Full status object: \(status)")
                print("   State: \(status.state)")
                print("   Transaction count: \(status.transactionCount)")
                if let history = status.history {
                    print("   History: \(history.joined(separator: " → "))")
                }
            } else {
                error = "No detailed status available"
                print("⚠️ No status returned for \(exitVtxo.vtxoId)")
            }
        } catch {
            self.error = "Failed to load status: \(error.localizedDescription)"
            print("❌ Failed to load exit status: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Views

private struct ParsedStateSection: View {
    let parsed: ParsedExitState
    
    var body: some View {
        Section("Parsed State") {
            switch parsed {
            case .start(let data):
                LabeledContent("Type", value: "Start")
                LabeledContent("Tip Height", value: "\(data.tipHeight)")
                
            case .processing(let data):
                LabeledContent("Type", value: "Processing")
                LabeledContent("Tip Height", value: "\(data.tipHeight)")
                LabeledContent("Transactions", value: "\(data.transactions.count)")
                
            case .awaitingDelta(let data):
                LabeledContent("Type", value: "Awaiting Delta")
                LabeledContent("Tip Height", value: "\(data.tipHeight)")
                LabeledContent("Confirmed Block", value: "\(data.confirmedBlock.height)")
                LabeledContent("Claimable Height", value: "\(data.claimableHeight)")
                
            case .claimable(let data):
                LabeledContent("Type", value: "Claimable")
                LabeledContent("Tip Height", value: "\(data.tipHeight)")
                LabeledContent("Claimable Since", value: "\(data.claimableSince.height)")
                
            case .claimInProgress(let data):
                LabeledContent("Type", value: "Claim In Progress")
                LabeledContent("Tip Height", value: "\(data.tipHeight)")
                LabeledContent("Claim TX") {
                    Text(data.claimTxid.prefix(8) + "..." + data.claimTxid.suffix(8))
                        .font(.system(.caption, design: .monospaced))
                }
                
            case .claimed(let data):
                LabeledContent("Type", value: "Claimed")
                LabeledContent("Tip Height", value: "\(data.tipHeight)")
                LabeledContent("Claim TX") {
                    Text(data.txid.prefix(8) + "..." + data.txid.suffix(8))
                        .font(.system(.caption, design: .monospaced))
                }
                LabeledContent("Block", value: "\(data.block.height)")
                
            case .unparsed(let str):
                LabeledContent("Type", value: "Unparsed")
                Text(str)
                    .font(.system(.caption, design: .monospaced))
            }
        }
    }
}

private struct TransactionChainSection: View {
    let transactions: [ExitTransaction]
    
    var body: some View {
        Section("Transaction Chain") {
            ForEach(Array(transactions.enumerated()), id: \.offset) { index, tx in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("#\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.txid.prefix(8) + "..." + tx.txid.suffix(8))
                                .font(.system(.caption, design: .monospaced))
                            
                            TransactionStatusLabel(status: tx.status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct TransactionIdsSection: View {
    let txids: [String]
    
    var body: some View {
        Section("All Transaction IDs (\(txids.count))") {
            ForEach(txids, id: \.self) { txid in
                Text(txid.prefix(8) + "..." + txid.suffix(8))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }
}

private struct ConfirmedTransactionsSection: View {
    let confirmed: [(txid: String, block: ArkeBlockRef)]
    
    var body: some View {
        Section("Confirmed Transactions") {
            ForEach(confirmed, id: \.txid) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.Arke.green)
                            .font(.caption)
                        
                        Text(item.txid.prefix(8) + "..." + item.txid.suffix(8))
                            .font(.system(.caption, design: .monospaced))
                    }
                    
                    Text("Block \(item.block.height)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ParsedStateLabel: View {
    let parsed: ParsedExitState
    
    var body: some View {
        switch parsed {
        case .start:
            Label("Start", systemImage: "flag")
        case .processing:
            Label("Processing", systemImage: "gearshape")
        case .awaitingDelta:
            Label("Awaiting Delta", systemImage: "clock")
        case .claimable:
            Label("Claimable", systemImage: "checkmark.circle")
        case .claimInProgress:
            Label("Claim In Progress", systemImage: "arrow.down.circle")
        case .claimed:
            Label("Claimed", systemImage: "checkmark.circle.fill")
        case .unparsed:
            Label("Unknown", systemImage: "questionmark.circle")
        }
    }
}

private struct TransactionStatusLabel: View {
    let status: ExitTxStatus
    
    var body: some View {
        switch status {
        case .verifyInputs:
            Text("Verify Inputs")
        case .needsSignedPackage:
            Text("Needs Signed Package")
        case .needsBroadcasting:
            Text("Needs Broadcasting")
        case .broadcastWithCpfp:
            Text("Broadcast with CPFP")
        case .awaitingInputConfirmation:
            Text("Awaiting Input Confirmation")
        case .confirmed:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.Arke.green)
                Text("Confirmed")
            }
        case .unparsed:
            Text("Unknown Status")
        }
    }
}

#Preview("Exit Detail") {
    ExitStatusDetailView_iOS(
        exitVtxo: ExitVtxo(
            vtxoId: "abc123def456789xyz0123456789",
            amountSats: 250000,
            state: "broadcasting",
            isClaimable: false
        )
    )
    .environment(WalletManager(useMock: true))
}

