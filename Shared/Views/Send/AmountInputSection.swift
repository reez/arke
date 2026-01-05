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
    let feeText: String
    let isAmountLocked: Bool
    let lockedAmountReason: String?
    let minimumSendArk: Int
    
    @FocusState private var isAmountFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Enter amount")
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
                #if os(iOS)
                .keyboardType(.numberPad)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                #endif
                .focused($isAmountFieldFocused)
                .background(Color.gray.opacity(isAmountLocked ? 0.05 : 0.1))
                .cornerRadius(16)
                .disabled(isAmountLocked)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isAmountFieldFocused = false
                        }
                    }
                }
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Minimum: " + BitcoinFormatter.shared.formatAmount(minimumSendArk))
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
                
                if !feeText.isEmpty {
                    Text("Fee: " + feeText)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
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
            availableBalanceText: "Ark balance: ₿ 1,000",
            feeText: "Fee: ₿ 100",
            isAmountLocked: false,
            lockedAmountReason: nil,
            minimumSendArk: 330
        )
        
        // Locked amount (Lightning invoice)
        AmountInputSection(
            amount: .constant("50000"),
            maxSpendableAmount: 100000,
            availableBalanceText: "Ark balance: ₿ 1,000",
            feeText: "Fee: ₿ 100",
            isAmountLocked: true,
            lockedAmountReason: "set by Lightning invoice",
            minimumSendArk: 330
        )
    }
    .padding()
    .frame(width: 600)
}
