//
//  AmountInputSection.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/18/25.
//

import SwiftUI
import ArkeUI

struct AmountInputSection: View {
    @Binding var amount: String
    let maxSpendableAmount: Int
    let availableBalanceText: String
    let feeText: String
    let isAmountLocked: Bool
    let lockedAmountReason: String?
    let minimumSendArk: Int
    
    @FocusState.Binding var isAmountFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("placeholder_enter_amount")
                    .font(.title2)
                
                if isAmountLocked, let reason = lockedAmountReason {
                    Text("(\(reason))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            TextField(String(localized: "format_zero"), text: $amount)
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
                    Text("send_amount_fixed")
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
    @Previewable @FocusState var isFocused: Bool
    
    VStack(spacing: 40) {
        // Normal editable amount
        AmountInputSection(
            amount: .constant(""),
            maxSpendableAmount: 100000,
            availableBalanceText: "Ark balance: ₿ 1,000",
            feeText: "Fee: ₿ 100",
            isAmountLocked: false,
            lockedAmountReason: nil,
            minimumSendArk: 330,
            isAmountFieldFocused: $isFocused
        )
        
        // Locked amount (Lightning invoice)
        AmountInputSection(
            amount: .constant("50000"),
            maxSpendableAmount: 100000,
            availableBalanceText: "Ark balance: ₿ 1,000",
            feeText: "Fee: ₿ 100",
            isAmountLocked: true,
            lockedAmountReason: "set by Lightning invoice",
            minimumSendArk: 330,
            isAmountFieldFocused: $isFocused
        )
    }
    .padding()
    .frame(width: 600)
    .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("button_done") {
                isFocused = false
            }
        }
    }
}
