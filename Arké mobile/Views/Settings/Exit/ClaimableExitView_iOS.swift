//
//  ClaimableExitView.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//

import SwiftUI
import Bark

struct ClaimableExitView_iOS: View {
    let exit: OngoingUnilateralExit
    let isProcessing: Bool
    let onClaim: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Success banner
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.arkeGold)
                
                Text("Finish your Claim")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 20)
            
            // Amount
            VStack(spacing: 8) {
                Text("Amount to Claim")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(exit.formattedAmount)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Info
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("The bitcoin will be added to your savings balance.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Claim button
            Button {
                onClaim()
            } label: {
                Text("Claim Funds")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.arkeDark)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Color.arkeGold)
            .disabled(isProcessing)
            
            Spacer()
        }
    }
}

#Preview {
    ClaimableExitView_iOS(
        exit: OngoingUnilateralExit(
            exitTxid: "abc123def456",
            status: .claimable,
            challengePeriodEndHeight: 850000,
            vtxoOutpoints: [],
            totalAmountSat: 100000
        ),
        isProcessing: false,
        onClaim: {}
    )
    .padding()
}
