//
//  OffboardingModalFormView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/19/25.
//

import SwiftUI
import ArkeUI

struct OffboardingModalFormView: View {
    @State private var amountText: String = ""
    let onchainAddress: String
    let maximumAmount: Int?
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void
    
    @FocusState private var isAmountFieldFocused: Bool
    
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
        NavigationStack {
            VStack(spacing: 25) {
                Image("offboard")
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
                
                VStack(alignment: .leading, spacing: 25) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Move to savings")
                            .font(.system(.title, design: .serif))
                        
                        Text("Transfer funds to the savings balance for slower and more expensive payments, with the benefit of no maintenance fees.")
                            .font(.title3)
                            .foregroundColor(.arkeSecondary)
                            .lineSpacing(6)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        /*
                        Text("Amount in satoshis")
                            .font(.headline)
                            .fontWeight(.medium)
                        */
                        
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
                    
                    Button {
                        if let amount = enteredAmount {
                            onConfirm(amount)
                        }
                    } label: {
                        Text("Start")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Color.Arke.gold3)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(Color.Arke.gold)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding()
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
