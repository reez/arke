//
//  RecipientInputSection.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/18/25.
//

import SwiftUI

struct RecipientInputSection: View {
    @Binding var input: String
    let onValidPaymentRequest: (PaymentRequest) -> Void
    let onShowAddressFormats: () -> Void
    
    @State private var validationState: ValidationState = .idle
    
    enum ValidationState {
        case idle
        case valid(PaymentRequest)
        case invalid(String)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Text("Recipient Address")
                    .font(.title2)
                
                Button(action: onShowAddressFormats) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("Show supported address formats")
            }
            
            // Input field
            TextField("Enter address...", text: $input)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
                .font(.system(.body, design: .monospaced))
                .onChange(of: input) { _, newValue in
                    validateInput(newValue)
                }
            
            // Validation feedback
            switch validationState {
            case .idle:
                EmptyView()
                
            case .valid(let paymentRequest):
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let primary = paymentRequest.primaryDestination {
                            Text("Valid \(primary.format.displayName) address")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                        
                        if paymentRequest.hasAlternatives {
                            Text("\(paymentRequest.destinations.count) payment options available")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Continue →") {
                        onValidPaymentRequest(paymentRequest)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
            case .invalid(let error):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private func validateInput(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            validationState = .idle
            return
        }
        
        if let paymentRequest = AddressValidator.parsePaymentRequest(trimmed) {
            validationState = .valid(paymentRequest)
        } else {
            validationState = .invalid("Invalid address format")
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        // Idle state
        RecipientInputSection(
            input: .constant(""),
            onValidPaymentRequest: { _ in print("Valid!") },
            onShowAddressFormats: { print("Show formats") }
        )
        
        // Valid state
        RecipientInputSection(
            input: .constant("bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"),
            onValidPaymentRequest: { _ in print("Valid!") },
            onShowAddressFormats: { print("Show formats") }
        )
        
        // Invalid state
        RecipientInputSection(
            input: .constant("invalid_address_xyz"),
            onValidPaymentRequest: { _ in print("Valid!") },
            onShowAddressFormats: { print("Show formats") }
        )
    }
    .padding()
    .frame(width: 600)
}
