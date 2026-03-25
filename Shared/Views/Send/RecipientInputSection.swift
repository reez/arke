//
//  RecipientInputSection.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/18/25.
//

import SwiftUI
import ArkeUI

struct RecipientInputSection: View {
    @Binding var input: String
    @Binding var state: RecipientState
    @Binding var destination: PaymentDestination?
    let onShowAddressFormats: () -> Void
    
    @FocusState.Binding var isRecipientFieldFocused: Bool
    
    @State private var debounceTask: Task<Void, Never>?
    @State private var showingAddressReview = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Text("send_recipient_address")
                    .font(.body)
                    .fontWeight(.medium)
                
                Button(action: onShowAddressFormats) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("action_show_address_formats")
                
                if case .valid = state {
                    Button(action: { showingAddressReview = true }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("Review address")
                } else if case .bip353Resolved = state {
                    Button(action: { showingAddressReview = true }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("Review address")
                }
                
                Spacer()
            
                // Validation feedback
                ValidationFeedbackView(state: state)
            }
            
            // Input field
            BitcoinAddressField(
                text: $input,
                placeholder: String(localized: "placeholder_enter_address"),
                isFocused: $isRecipientFieldFocused
            )
            .frame(maxHeight: 120)
            .onChange(of: input) { _, newValue in
                validateInput(newValue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.arkeSeparatorColor.opacity(0.5), lineWidth: 1)
        )
        .sheet(isPresented: $showingAddressReview) {
            AddressReviewSheet(address: input.trimmingCharacters(in: .whitespacesAndNewlines))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
            
            // Check for BIP-353 format first
            if BIP353Resolver.isBIP353Format(trimmed) {
                state = .validBIP353Format
                destination = nil
                return
            }
            
            // Parse non-BIP-353 addresses
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

struct AddressReviewSheet: View {
    let address: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Review Address")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 30)
            
            ExpandableAddressView(
                address: address,
                isExpanded: .constant(true),
                animated: false
            )
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        
        @FocusState private var isFocused: Bool
        
        var body: some View {
            VStack(spacing: 40) {
                // Idle state
                RecipientInputSection(
                    input: $idleInput,
                    state: $idleState,
                    destination: $idleDestination,
                    onShowAddressFormats: { print("Show formats") },
                    isRecipientFieldFocused: $isFocused
                )
                
                // Valid state
                RecipientInputSection(
                    input: $validInput,
                    state: $validState,
                    destination: $validDestination,
                    onShowAddressFormats: { print("Show formats") },
                    isRecipientFieldFocused: $isFocused
                )
                
                // Invalid state
                RecipientInputSection(
                    input: $invalidInput,
                    state: $invalidState,
                    destination: $invalidDestination,
                    onShowAddressFormats: { print("Show formats") },
                    isRecipientFieldFocused: $isFocused
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
    }
    
    return PreviewWrapper()
}
