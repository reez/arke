//
//  ContactPaymentView.swift
//  Arké
//
//  Created by Christoph on 11/18/25.
//

import SwiftUI

struct ContactPaymentView: View {
    let contact: ContactModel
    let showBanner: Bool
    let onClear: () -> Void
    
    // Amount input properties
    @Binding var amount: String
    let maxSpendableAmount: Int
    let availableBalanceText: String
    let isAmountLocked: Bool
    let lockedAmountReason: String?
    
    var body: some View {
        VStack(spacing: 24) {
            if showBanner {
                ContactInfoBanner(contact: contact, onClear: onClear)
            }
            
            AmountInputSection(
                amount: $amount,
                maxSpendableAmount: maxSpendableAmount,
                availableBalanceText: availableBalanceText,
                isAmountLocked: isAmountLocked,
                lockedAmountReason: lockedAmountReason
            )
        }
    }
}
