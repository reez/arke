//
//  ManualSendView.swift
//  Arké
//
//  Created by Christoph on 11/18/25.
//

import SwiftUI

struct ManualSendView: View {
    // MARK: - Mode
    enum Mode {
        case entering  // User is typing/pasting an address
        case confirmed // Address validated and confirmed
    }
    
    // MARK: - Bindings
    @Binding var manualInput: String
    @Binding var amount: String
    @Binding var showAddressFormatsPopover: Bool
    @Binding var selectedDestination: PaymentDestination?
    
    // MARK: - Properties
    let mode: Mode
    let currentPaymentRequest: PaymentRequest?
    let rankedDestinations: [PaymentDestinationSelector.RankedDestination]
    let maxSpendableAmount: Int
    let availableBalanceText: String
    let isAmountLocked: Bool
    let lockedAmountReason: String?
    
    // MARK: - Callbacks
    let onValidPaymentRequest: (PaymentRequest) -> Void
    let onClear: () -> Void
    let onChangeDestination: () -> Void
    let onSend: () -> Void
    
    // MARK: - Computed Properties
    
    /// Determines if the Send button should be enabled
    private var canSend: Bool {
        guard mode == .confirmed else { return false }
        guard selectedDestination != nil else { return false }
        
        // If amount is locked (e.g., Lightning invoice), we don't need user input
        if isAmountLocked { return true }
        
        // Otherwise, we need a valid amount
        return !amount.isEmpty && Int(amount) != nil
    }
    
    var body: some View {
        VStack(spacing: 24) {
            switch mode {
            case .entering:
                // Recipient input section
                RecipientInputSection(
                    input: $manualInput,
                    onValidPaymentRequest: onValidPaymentRequest,
                    onShowAddressFormats: {
                        showAddressFormatsPopover = true
                    }
                )
                
            case .confirmed:
                // Show confirmed destination card
                if let paymentRequest = currentPaymentRequest {
                    ConfirmedDestinationCard(
                        paymentRequest: paymentRequest,
                        selectedDestination: $selectedDestination,
                        rankedDestinations: rankedDestinations,
                        onClear: onClear,
                        onChangeDestination: onChangeDestination
                    )
                }
            }
                
            // Amount section (shown in confirmed mode)
            AmountInputSection(
                amount: $amount,
                maxSpendableAmount: maxSpendableAmount,
                availableBalanceText: availableBalanceText,
                isAmountLocked: isAmountLocked,
                lockedAmountReason: lockedAmountReason
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
    }
}
