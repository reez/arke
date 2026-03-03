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
                Text("action_start_forced_move")
                    .font(.system(.title, design: .serif))
                
                Text("This is an emergency feature for moving your bitcoin from payments to savings, without the involvement of the server that is usually involved.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("symbol_bullet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("message_takes_24_hours")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("symbol_bullet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("message_cannot_cancel")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("symbol_bullet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("balance_final_step_fee")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .lineSpacing(6)
            }
            
            if spendableBalance > 0 {
                // Amount card
                VStack(spacing: 6) {
                    Text("balance_amount_to_recover")
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
                    Text("button_start")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.Arke.gold2)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(Color.Arke.gold)
                .disabled(spendableBalance == 0 || isProcessing)
            }
            
            if spendableBalance == 0 {
                Text("You don't have any bitcoin in your payments balance to move.")
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
