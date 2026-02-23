//
//  ManualSendView.swift
//  Arké
//
//  Created by Christoph on 11/18/25.
//

import SwiftUI
import ArkeUI

struct ManualSendView: View {
    // MARK: - Bindings
    @Binding var manualInput: String
    @Binding var recipientState: RecipientState
    @Binding var amount: String
    @Binding var showAddressFormatsPopover: Bool
    @Binding var selectedDestination: PaymentDestination?
    
    // MARK: - Properties
    let maxSpendableAmount: Int
    let availableBalanceText: String
    let feeText: String
    let isAmountLocked: Bool
    let lockedAmountReason: String?
    let minimumSendArk: Int
    
    // MARK: - Callbacks
    let onSend: () -> Void
    
    // MARK: - Computed Properties
    
    /// Determines if we're in confirmed mode (valid address)
    private var isConfirmed: Bool {
        if case .valid = recipientState {
            return true
        }
        return false
    }
    
    /// Determines if the Send button should be enabled
    private var canSend: Bool {
        guard isConfirmed else { return false }
        guard let destination = selectedDestination else { return false }
        
        // If amount is locked (e.g., Lightning invoice), we don't need user input
        if isAmountLocked { return true }
        
        // Otherwise, we need a valid amount
        guard !amount.isEmpty, let amountValue = Int(amount) else { return false }
        
        // For Ark addresses, enforce minimum send amount
        if destination.format == .ark && amountValue < minimumSendArk {
            return false
        }
        
        return true
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Recipient input section
            RecipientInputSection(
                input: $manualInput,
                state: $recipientState,
                destination: $selectedDestination,
                onShowAddressFormats: {
                    showAddressFormatsPopover = true
                }
            )
                
            // Amount section (shown in confirmed mode)
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
            Button {
                onSend()
            } label: {
                Text("Send")
                    .font(.title2)
                    .foregroundStyle(Color.arkeDark)
                    .padding(.horizontal, 40)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Color.arkeGold)
            .frame(maxWidth: .infinity)
            .disabled(!canSend)
            .padding(.top, 16)
        }
        .frame(maxWidth: 400)
    }
}
