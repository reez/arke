//
//  AmountInputSection.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/18/25.
//

import SwiftUI

struct AmountInputSection: View {
    @Binding var amount: String
    let maxSpendableAmount: Int
    let availableBalanceText: String
    let isAmountLocked: Bool
    let lockedAmountReason: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Amount in satoshis")
                    .font(.title2)
                
                if isAmountLocked, let reason = lockedAmountReason {
                    Text("(\(reason))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            TextField("0", text: $amount)
                .textFieldStyle(.plain)
                .font(.title2)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(isAmountLocked ? 0.05 : 0.1))
                .cornerRadius(16)
                .disabled(isAmountLocked)
            
            HStack(spacing: 0) {
                Text(BitcoinFormatter.shared.formatAmount(330) + " minimum · ")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if !isAmountLocked {
                    Button(availableBalanceText) {
                        amount = "\(maxSpendableAmount)"
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                    .buttonStyle(.plain)
                    .disabled(maxSpendableAmount == 0)
                } else {
                    Text("Amount is fixed by the payment request")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        // Normal editable amount
        AmountInputSection(
            amount: .constant(""),
            maxSpendableAmount: 100000,
            availableBalanceText: "Available: 0.001 BTC (Ark balance)",
            isAmountLocked: false,
            lockedAmountReason: nil
        )
        
        // Locked amount (Lightning invoice)
        AmountInputSection(
            amount: .constant("50000"),
            maxSpendableAmount: 100000,
            availableBalanceText: "Available: 0.001 BTC (Ark balance)",
            isAmountLocked: true,
            lockedAmountReason: "set by Lightning invoice"
        )
    }
    .padding()
    .frame(width: 600)
}
