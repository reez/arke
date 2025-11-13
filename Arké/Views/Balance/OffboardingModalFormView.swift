//
//  OffboardingModalFormView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/19/25.
//

import SwiftUI

struct OffboardingModalFormView: View {
    @State private var amountText: String = ""
    let onchainAddress: String
    let maximumAmount: Int?
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void
    
    private var enteredAmount: Int? {
        Int(amountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private var isValidAmount: Bool {
        guard let amount = enteredAmount else { return false }
        guard amount > 0 else { return false }
        if let maximum = maximumAmount {
            return amount <= maximum
        }
        return true
    }
    
    private var isFormEnabled: Bool {
        !onchainAddress.isEmpty
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 25) {
            Image("offboard")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: 150, maxHeight: .infinity)
                .cornerRadius(15)
                .clipped()
            
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transfer to savings")
                        .font(.system(size: 24, design: .serif))
                    
                    Text("Move funds to the Bitcoin network for the best security.")
                        .font(.default)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
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
                        .disabled(!isFormEnabled)
                        .onChange(of: amountText) { oldValue, newValue in
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if filtered != newValue {
                                amountText = filtered
                            }
                        }
                    
                    if let maximum = maximumAmount {
                        Text("Maximum: \(BitcoinFormatter.shared.formatAmount(maximum))")
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Loading available balance...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Confirm") {
                    if let amount = enteredAmount {
                        onConfirm(amount)
                    }
                }
                .disabled(!isValidAmount)
            }
        }
    }
}

#Preview {
    OffboardingModalFormView(
        onchainAddress: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        maximumAmount: 100000,
        onConfirm: { amount in
            print("Offboarding \(amount) sats")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}

#Preview("No Balance") {
    OffboardingModalFormView(
        onchainAddress: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        maximumAmount: nil,
        onConfirm: { amount in
            print("Offboarding \(amount) sats")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
