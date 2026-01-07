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
                    .foregroundColor(.green)
                
                Text("Ready to Claim")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 20)
            
            // Amount
            VStack(spacing: 8) {
                Text("Claimable Amount")
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
                    
                    Text("Funds will be claimed to your wallet's onchain address. This transaction will be broadcast to the Bitcoin network.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Claim button
            Button {
                onClaim()
            } label: {
                Text("Claim Funds")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
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
