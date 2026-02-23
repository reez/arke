//
//  NoExitView.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//

import SwiftUI
import ArkeUI

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
                Text("Start a solo move")
                    .font(.system(.title, design: .serif))
                
                Text("This is an emergency feature for moving your bitcoin from savings to payments, without the involvement of the server that is usually involved.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("This takes about 24 hours")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("It cannot be cancelled")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("The final step will incur a fee")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .lineSpacing(6)
            }
            
            if spendableBalance > 0 {
                // Amount card
                VStack(spacing: 6) {
                    Text("Amount to recover")
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
                Text("You don't have any bitcoin in your payments balance to recover.")
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
