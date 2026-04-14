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
                    Section(String(localized: "data_detailed_status")) {
                        LabeledContent("Current State") {
                            Text(status.state)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        LabeledContent(String(localized: "activity_transaction_count"), value: "\(status.transactionCount)")
                    }
                    
                    if let history = status.history, !history.isEmpty {
                        Section(String(localized: "data_state_history")) {
                            ForEach(Array(history.enumerated()), id: \.offset) { index, state in
                                HStack {
                                    Text("#\(index + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 30, alignment: .leading)
                                    
                                    Text(state)
                                        .font(.system(.body, design: .monospaced))
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

