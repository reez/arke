//
//  NoExitView.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//

import SwiftUI

struct NoExitView_iOS: View {
    let spendableBalance: Int
    let isProcessing: Bool
    let onStartExit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Icon and title
            VStack(alignment: .leading, spacing: 10) {
                Text("Unilateral Exit")
                    .font(.system(.title, design: .serif))
                
                Text("An exit allows you to withdraw your funds from without cooperation from the server. It takes approximately 24 hours due to a challenge period required for security.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
                
                Text("Once started, the exit cannot be cancelled. During the challenge period, your funds will be locked and unavailable for spending.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
            }
            
            // Amount card
            VStack(spacing: 8) {
                Text("Amount to exit")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(BitcoinFormatter.shared.formatAmount(spendableBalance))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Start button
            Button {
                onStartExit()
            } label: {
                Text("Start")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.arkeDark)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Color.arkeGold)
            .disabled(spendableBalance == 0 || isProcessing)
            
            if spendableBalance == 0 {
                Text("No spendable balance available to exit")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    NoExitView_iOS(
        spendableBalance: 100000,
        isProcessing: false,
        onStartExit: {}
    )
    .padding()
}
