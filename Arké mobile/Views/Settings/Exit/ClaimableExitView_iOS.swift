//
//  ClaimableExitView.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//

import SwiftUI
import Bark

struct ClaimableExitView_iOS: View {
    let exit: ExitVtxo
    let isProcessing: Bool
    let onClaim: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Success banner
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Finalize your Claim")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 20)
            
            // Amount
            VStack(spacing: 8) {
                Text("Amount")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(exit.formattedAmount)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            Text("The amount will be added to your savings balance.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Claim button
            Button {
                onClaim()
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 27))
                    .foregroundStyle(Color.arkeDark)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Color.arkeGold)
            .accessibilityLabel("Finalize Claim")
            .disabled(isProcessing)
            
            Spacer()
        }
    }
}

#Preview {
    ClaimableExitView_iOS(
        exit: ExitVtxo(
            vtxoId: "abc123def456789xyz0123456789",
            amountSats: 100000,
            state: "Claimable",
            isClaimable: true
        ),
        isProcessing: false,
        onClaim: {}
    )
    .padding()
}
