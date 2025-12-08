//
//  ContactPaymentView.swift
//  Arké
//
//  Created by Christoph on 11/18/25.
//

import SwiftUI

struct ContactPaymentView: View {
    let contact: ContactModel
    let contactAddress: String?
    let onClear: () -> Void
    let onNavigateToContact: ((ContactModel) -> Void)?
    let onSend: () -> Void
    
    // Amount input properties
    @Binding var amount: String
    let maxSpendableAmount: Int
    let availableBalanceText: String
    let feeText: String
    let isAmountLocked: Bool
    let lockedAmountReason: String?
    let minimumSendArk: Int
    
    // State for destination card
    @State private var selectedDestination: PaymentDestination?
    @State private var showFullAddress: Bool = false
    
    // MARK: - Computed Properties
    
    /// Find the contact address that matches the provided contactAddress string
    private var matchedContactAddress: ContactAddressModel? {
        guard let contactAddress = contactAddress else { return nil }
        
        let normalized = contactAddress.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First try to find exact match on normalized address
        if let match = contact.addresses.first(where: { $0.normalizedAddress == normalized }) {
            return match
        }
        
        // Fallback to case-insensitive match on original address
        return contact.addresses.first(where: { $0.address.lowercased() == normalized })
    }
    
    /// Convert the matched ContactAddressModel to a PaymentDestination
    private var paymentDestination: PaymentDestination? {
        guard let matched = matchedContactAddress else { return nil }
        
        return PaymentDestination(
            format: matched.format,
            network: matched.network,
            address: matched.address,
            scanPublicKey: nil,
            spendPublicKey: nil
        )
    }
    
    /// Create a PaymentRequest from the matched address
    private var paymentRequest: PaymentRequest? {
        guard let destination = paymentDestination else { return nil }
        
        return PaymentRequest(
            destination: destination,
            amount: nil,
            label: matchedContactAddress?.label ?? contact.displayName,
            message: matchedContactAddress?.label != nil ? "Payment to \(contact.displayName)" : nil
        )
    }
    
    /// Check if there's a valid matched address
    private var hasMatchedAddress: Bool {
        matchedContactAddress != nil
    }
    
    /// Check if contactAddress was provided but no match was found
    private var hasUnmatchedAddress: Bool {
        contactAddress != nil && !contactAddress!.isEmpty && matchedContactAddress == nil
    }
    
    /// Determines if the Send button should be enabled
    private var canSend: Bool {
        // Must have a valid matched address
        guard hasMatchedAddress else { return false }
        guard selectedDestination != nil else { return false }
        
        // If amount is locked (e.g., Lightning invoice), we don't need user input
        if isAmountLocked { return true }
        
        // Otherwise, we need a valid amount
        return !amount.isEmpty && Int(amount) != nil
    }
    
    var body: some View {
        VStack(spacing: 24) {
            ContactInfoBanner(
                contact: contact,
                onClear: onClear,
                onViewContact: { onNavigateToContact?(contact) }
            )
            .onAppear {
                // Set the selected destination when the view appears
                if selectedDestination == nil {
                    selectedDestination = paymentDestination
                }
            }
            
            // Destination Card - show matched address or error
            if hasMatchedAddress {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Contact address")
                        .font(.title2)
                    
                    // Address card
                    if let destination = selectedDestination {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showFullAddress.toggle()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(matchedContactAddress?.label ?? destination.format.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    Text(showFullAddress ? destination.address : destination.shortAddress)
                                        .font(.body.monospaced())
                                        .foregroundColor(showFullAddress ? .primary : .secondary)
                                        .lineSpacing(4)
                                        .lineLimit(showFullAddress ? nil : 1)
                                        .animation(.easeInOut(duration: 0.2), value: showFullAddress)
                                }
                                
                                Spacer()
                            }
                            .padding(15)
                            .background(.primary.opacity(0.05))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    /*
                    ConfirmedDestinationCard(
                        paymentRequest: request,
                        selectedDestination: $selectedDestination,
                        rankedDestinations: [],
                        onClear: nil,
                        onChangeDestination: {
                            // Not implemented yet - could show address picker in the future
                        }
                    )
                    .onAppear {
                        // Set the selected destination when the view appears
                        if selectedDestination == nil {
                            selectedDestination = paymentDestination
                        }
                    }
                    */
                }
            } else if hasUnmatchedAddress {
                // Error state: address provided but not found in contact
                AddressNotFoundErrorCard(
                    providedAddress: contactAddress ?? "",
                    contactName: contact.displayName,
                    contactAddressCount: contact.addresses.count
                )
            }
            
            AmountInputSection(
                amount: $amount,
                maxSpendableAmount: maxSpendableAmount,
                availableBalanceText: availableBalanceText,
                feeText: feeText,
                isAmountLocked: isAmountLocked,
                lockedAmountReason: lockedAmountReason,
                minimumSendArk: minimumSendArk
            )
            
            // Send button
            Button("Send") {
                onSend()
            }
            .buttonStyle(ArkeButtonStyle())
            .frame(maxWidth: .infinity)
            .disabled(!canSend)
            .padding(.top, 16)
        }
        .frame(maxWidth: 400)
    }
}
