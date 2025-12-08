//
//  RecipientInputSection.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/18/25.
//

import SwiftUI

struct RecipientInputSection: View {
    @Binding var input: String
    @Binding var state: RecipientState
    @Binding var destination: PaymentDestination?
    let onShowAddressFormats: () -> Void
    
    @State private var debounceTask: Task<Void, Never>?
    
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
                
                Spacer()
            
                // Validation feedback
                ValidationFeedbackView(state: state)
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
        }
    }
    
    private func validateInput(_ input: String) {
        // Cancel any pending validation
        debounceTask?.cancel()
        
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            state = .idle
            destination = nil
            return
        }
        
        // Show typing state immediately
        state = .typing
        
        // Debounce the actual validation
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(2000))
            
            guard !Task.isCancelled else { return }
            
            if let paymentRequest = AddressValidator.parsePaymentRequest(trimmed),
               let parsedDestination = paymentRequest.primaryDestination {
                state = .valid
                destination = parsedDestination
            } else {
                state = .invalid("Invalid address format")
                destination = nil
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var idleInput = ""
        @State private var idleState: RecipientState = .idle
        @State private var idleDestination: PaymentDestination?
        
        @State private var validInput = "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
        @State private var validState: RecipientState = .idle
        @State private var validDestination: PaymentDestination?
        
        @State private var invalidInput = "invalid_address_xyz"
        @State private var invalidState: RecipientState = .idle
        @State private var invalidDestination: PaymentDestination?
        
        var body: some View {
            VStack(spacing: 40) {
                // Idle state
                RecipientInputSection(
                    input: $idleInput,
                    state: $idleState,
                    destination: $idleDestination,
                    onShowAddressFormats: { print("Show formats") }
                )
                
                // Valid state
                RecipientInputSection(
                    input: $validInput,
                    state: $validState,
                    destination: $validDestination,
                    onShowAddressFormats: { print("Show formats") }
                )
                
                // Invalid state
                RecipientInputSection(
                    input: $invalidInput,
                    state: $invalidState,
                    destination: $invalidDestination,
                    onShowAddressFormats: { print("Show formats") }
                )
            }
            .padding()
            .frame(width: 600)
        }
    }
    
    return PreviewWrapper()
}
