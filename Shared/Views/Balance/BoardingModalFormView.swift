//
//  BoardingModalFormView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/19/25.
//

import SwiftUI

struct BoardingModalFormView: View {
    @State private var amountText: String = ""
    let minimumAmount: Int?
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void
    
    @FocusState private var isAmountFieldFocused: Bool
    
    private var enteredAmount: Int? {
        Int(amountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private var isValidAmount: Bool {
        guard let amount = enteredAmount, let minimum = minimumAmount else { return false }
        return amount >= minimum
    }
    
    private var isFormEnabled: Bool {
        minimumAmount != nil
    }
    
    var body: some View {
        VStack(spacing: 25) {
            Image("board")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(25)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 30, height: 30)
                    }
                    .accessibilityLabel("Close")
                    .buttonStyle(.bordered)
                    .clipShape(Circle())
                    .padding(.trailing, 8)
                    .padding(.top, 12)
                }
            
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Transfer to payments")
                        .font(.system(.title, design: .serif))
                    
                    Text("Move funds to the Ark network for fast and low-fee payments.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .lineSpacing(6)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount in satoshis")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    TextField("Enter amount", text: $amountText)
                        .textFieldStyle(.plain)
                        .font(.title)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .disabled(!isFormEnabled)
                        .onChange(of: amountText) { oldValue, newValue in
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if filtered != newValue {
                                amountText = filtered
                            }
                        }
                        .focused($isAmountFieldFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    isAmountFieldFocused = false
                                }
                            }
                        }
                    
                    if let minimum = minimumAmount {
                        Text(BitcoinFormatter.shared.formatAmount(minimum) + " minimum.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Loading minimum amount...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    if let amount = enteredAmount {
                        onConfirm(amount)
                    }
                } label: {
                    Text("Start")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.arkeDark)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                }
                .disabled(!isValidAmount)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(Color.arkeGold)
            }
        }
        .padding()
    }
}

#Preview {
    BoardingModalFormView(
        minimumAmount: 50000,
        onConfirm: { amount in
            print("Boarding \(amount) sats")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
