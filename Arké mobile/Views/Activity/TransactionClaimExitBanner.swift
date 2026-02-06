//
//  TransactionClaimExitBanner.swift
//  Arké
//
//  Created by Assistant on 2/6/26.
//

import SwiftUI
import Bark

/// Banner displayed when a unilateral exit transaction has claimable VTXOs.
/// Allows the user to finalize the withdrawal by claiming the exits to their onchain wallet.
struct TransactionClaimExitBanner: View {
    let exitVtxos: [ExitVtxo]
    let estimatedFee: UInt64?
    let isCalculatingFee: Bool
    let isClaiming: Bool
    let onClaim: () -> Void
    
    @State private var showClaimConfirmation = false
    
    var body: some View {
        if hasClaimableExit {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        Text("Ready to Finalize Withdrawal")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    // Amount and fee info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Amount:")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(formattedClaimableAmount)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("Network Fee:")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            
                            if isCalculatingFee {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else if let fee = estimatedFee {
                                Text(BitcoinFormatter.shared.formatAmount(Int(fee)))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            } else {
                                Text("Calculating...")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    
                    // Action button
                    Button(action: {
                        showClaimConfirmation = true
                    }) {
                        HStack {
                            if isClaiming {
                                ProgressView()
                                    .tint(.blue)
                                Text("Finalizing...")
                            } else {
                                Text("Finalize Claim")
                                Image(systemName: "arrow.right")
                            }
                        }
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isClaiming || isCalculatingFee)
                    .padding(.top, 4)
                }
                .padding(16)
                .background(Color.blue)
                .cornerRadius(16)
            }
            .alert("Finalize Withdrawal", isPresented: $showClaimConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Finalize") {
                    onClaim()
                }
            } message: {
                if let fee = estimatedFee {
                    Text("Withdraw \(formattedClaimableAmount) to your wallet's savings balance?\n\nNetwork fee: \(BitcoinFormatter.shared.formatAmount(Int(fee)))")
                } else {
                    Text("Withdraw \(formattedClaimableAmount) to your wallet's savings balance?")
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasClaimableExit: Bool {
        exitVtxos.contains { $0.isClaimable }
    }
    
    private var claimableAmount: UInt64 {
        exitVtxos.filter { $0.isClaimable }.reduce(0) { $0 + $1.amountSats }
    }
    
    private var formattedClaimableAmount: String {
        BitcoinFormatter.shared.formatAmount(Int(claimableAmount))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TransactionClaimExitBanner(
            exitVtxos: [
                ExitVtxo(
                    vtxoId: "vtxo_abc123",
                    amountSats: 100000,
                    state: "Claimable",
                    isClaimable: true
                ),
                ExitVtxo(
                    vtxoId: "vtxo_def456",
                    amountSats: 50000,
                    state: "Claimable",
                    isClaimable: true
                )
            ],
            estimatedFee: 1500,
            isCalculatingFee: false,
            isClaiming: false,
            onClaim: {
                print("Claim tapped")
            }
        )
        
        Text("With calculated fee")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}

#Preview("Calculating Fee") {
    VStack(spacing: 20) {
        TransactionClaimExitBanner(
            exitVtxos: [
                ExitVtxo(
                    vtxoId: "vtxo_abc123",
                    amountSats: 100000,
                    state: "Claimable",
                    isClaimable: true
                )
            ],
            estimatedFee: nil,
            isCalculatingFee: true,
            isClaiming: false,
            onClaim: {
                print("Claim tapped")
            }
        )
        
        Text("Calculating fee state")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}

#Preview("Claiming") {
    VStack(spacing: 20) {
        TransactionClaimExitBanner(
            exitVtxos: [
                ExitVtxo(
                    vtxoId: "vtxo_abc123",
                    amountSats: 100000,
                    state: "Claimable",
                    isClaimable: true
                )
            ],
            estimatedFee: 1500,
            isCalculatingFee: false,
            isClaiming: true,
            onClaim: {
                print("Claim tapped")
            }
        )
        
        Text("Claiming in progress")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
