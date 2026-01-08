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
            Image("exit")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(25)
                .clipped()
            
            // Icon and title
            VStack(alignment: .leading, spacing: 10) {
                Text("Claim your bitcoin")
                    .font(.system(.title, design: .serif))
                
                Text("It may happen that the server that facilitates your payments goes away. In that case, you can still claim your bitcoin.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
                
                Text("For security, this takes about 24 hours. Once started, the claim process cannot be cancelled.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
            }
            
            if spendableBalance > 0 {
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
            }
            
            if spendableBalance == 0 {
                Text("You don't have any bitcoin to exit right now.")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .padding(.top, 10)
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
