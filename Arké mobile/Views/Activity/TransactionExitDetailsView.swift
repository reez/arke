//
//  TransactionExitDetailsView.swift
//  Arké
//
//  Created by Assistant on 2/5/26.
//

import SwiftUI
import Bark

/// Expandable exit details section for unilateral exit transactions.
/// Shows information about VTXOs currently in the exit process.
struct TransactionExitDetailsView: View {
    let transaction: TransactionModel
    
    @Environment(WalletManager.self) private var walletManager
    @State private var isExpanded = false
    @State private var exitVtxos: [ExitVtxo] = []
    
    var body: some View {
        // Only show for unilateral exit transactions
        guard transaction.subsystemName == "bark.exit" else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            VStack(spacing: 0) {
                // Header button
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Exit Details")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Image(systemName: "chevron.down")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                
                // Expanded content
                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        if exitVtxos.isEmpty {
                            // No matching exit data found
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No Active Exit Data")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                Text("The VTXOs from this transaction may have already been claimed or are not found in active exits.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // Summary
                            ExitSummaryRow(exitVtxos: exitVtxos)
                            
                            Divider()
                            
                            // Individual VTXO details
                            ForEach(Array(exitVtxos.enumerated()), id: \.element.vtxoId) { index, exitVtxo in
                                if index > 0 {
                                    Divider()
                                }
                                
                                ExitVtxoDetailRow(exitVtxo: exitVtxo)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(25)
                    .padding(.top, 8)
                }
            }
            .padding(.top, 30)
            .onAppear {
                loadExitData()
            }
        )
    }
    
    private func loadExitData() {
        // Match transaction inputVtxoIds with active unilateral exits
        let inputIds = Set(transaction.inputVtxoIds)
        exitVtxos = walletManager.activeUnilateralExits.filter { exit in
            inputIds.contains(exit.vtxoId)
        }
        
        print("📊 [Exit Details] Found \(exitVtxos.count) active exits for transaction \(transaction.txid)")
        for exit in exitVtxos {
            print("   - VTXO: \(exit.vtxoId), Amount: \(exit.amountSats) sats, State: \(exit.state), Claimable: \(exit.isClaimable)")
        }
    }
}

// MARK: - Supporting Views

private struct ExitSummaryRow: View {
    let exitVtxos: [ExitVtxo]
    
    private var totalAmount: UInt64 {
        exitVtxos.reduce(0) { $0 + $1.amountSats }
    }
    
    private var formattedTotal: String {
        BitcoinFormatter.shared.formatAmount(Int(totalAmount))
    }
    
    private var allClaimable: Bool {
        !exitVtxos.isEmpty && exitVtxos.allSatisfy { $0.isClaimable }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VTXOs Exiting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(exitVtxos.count)")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formattedTotal)
                        .font(.body)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                if allClaimable {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("All Claimable")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }
}

private struct ExitVtxoDetailRow: View {
    let exitVtxo: ExitVtxo
    
    private var formattedAmount: String {
        BitcoinFormatter.shared.formatAmount(Int(exitVtxo.amountSats))
    }
    
    private var stateColor: Color {
        exitVtxo.isClaimable ? .green : .orange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // VTXO ID
            VStack(alignment: .leading, spacing: 4) {
                Text("VTXO ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(exitVtxo.vtxoId)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            // Amount
            VStack(alignment: .leading, spacing: 4) {
                Text("Amount")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formattedAmount)
                    .font(.body)
            }
            
            // State
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("State")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 6, height: 6)
                        Text(exitVtxo.state)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                Spacer()
                
                if exitVtxo.isClaimable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    TransactionExitDetailsView(
        transaction: TransactionModel(
            txid: "exit_tx_1",
            movementId: 100,
            recipientIndex: nil,
            type: .transfer,
            amount: -100000,
            date: Date(),
            status: .confirmed,
            address: nil,
            subsystemName: "bark.exit",
            inputVtxoIds: ["vtxo_123", "vtxo_456"]
        )
    )
    .environment(WalletManager(useMock: true))
    .padding()
}

#Preview("Expanded") {
    struct ExpandedPreview: View {
        @State private var transaction = TransactionModel(
            txid: "exit_tx_2",
            movementId: 101,
            recipientIndex: nil,
            type: .transfer,
            amount: -250000,
            date: Date(),
            status: .confirmed,
            address: nil,
            subsystemName: "bark.exit",
            inputVtxoIds: ["vtxo_abc", "vtxo_def", "vtxo_xyz"]
        )
        
        var body: some View {
            TransactionExitDetailsView(transaction: transaction)
                .environment(WalletManager(useMock: true))
                .padding()
        }
    }
    
    return ExpandedPreview()
}
