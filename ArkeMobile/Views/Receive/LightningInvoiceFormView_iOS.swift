//
//  LightningInvoiceFormView.swift
//  Arké
//
//  Created by Assistant on 1/28/26.
//

import SwiftUI
import ArkeUI

/// Form view for creating Lightning invoices (used in Addresses mode)
struct LightningInvoiceFormView_iOS: View {
    @Binding var amount: String
    @Binding var note: String
    let lightningInvoice: String?
    let invoiceError: String?
    let isGeneratingInvoice: Bool
    let onGenerateInvoice: () -> Void
    let onClearInvoice: () -> Void
    
    private var hasInvoice: Bool {
        lightningInvoice != nil
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text(hasInvoice ? String(localized: "action_share_lightning") : String(localized: "action_create_lightning_request"))
                .font(.system(size: 24, design: .serif))
                .multilineTextAlignment(.center)
            
            // Form fields
            AmountAndNoteInputView(
                amount: $amount,
                note: $note,
                showingAmountAndNote: .constant(true),
                amountPlaceholder: String(localized: "placeholder_amount_required"),
                notePlaceholder: String(localized: "placeholder_note_optional"),
                unitLabel: nil,
                isDisabled: hasInvoice,
                allowDecimal: false,
                keyboardType: .numberPad
            )
            .background(.ultraThinMaterial)
            .cornerRadius(25)
            
            // Error message
            if let error = invoiceError {
                Text(error)
                    .foregroundColor(.Arke.red)
                    .font(.caption)
                    .padding(.horizontal, 20)
            }
            
            // Action button
            if hasInvoice {
                Button {
                    onClearInvoice()
                } label: {
                    HStack(spacing: 6) {
                        Text("button_clear_request")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.Arke.red)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.Arke.red)
                .controlSize(.large)
                .padding(.horizontal, 20)
            } else {
                Button {
                    onGenerateInvoice()
                } label: {
                    HStack(spacing: 6) {
                        if isGeneratingInvoice {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(isGeneratingInvoice ? String(localized: "status_generating") : String(localized: "button_generate_request"))
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.Arke.gold3)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.Arke.gold)
                .controlSize(.large)
                .disabled(amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGeneratingInvoice)
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
    }
}

#Preview("Empty Form") {
    @Previewable @State var amount = ""
    @Previewable @State var note = ""
    
    LightningInvoiceFormView_iOS(
        amount: $amount,
        note: $note,
        lightningInvoice: nil,
        invoiceError: nil,
        isGeneratingInvoice: false,
        onGenerateInvoice: {},
        onClearInvoice: {}
    )
    .frame(width: 400, height: 600)
}

#Preview("With Amount") {
    @Previewable @State var amount = "50000"
    @Previewable @State var note = "Payment for services"
    
    LightningInvoiceFormView_iOS(
        amount: $amount,
        note: $note,
        lightningInvoice: nil,
        invoiceError: nil,
        isGeneratingInvoice: false,
        onGenerateInvoice: {},
        onClearInvoice: {}
    )
    .frame(width: 400, height: 600)
}

#Preview("Generating") {
    @Previewable @State var amount = "50000"
    @Previewable @State var note = ""
    
    LightningInvoiceFormView_iOS(
        amount: $amount,
        note: $note,
        lightningInvoice: nil,
        invoiceError: nil,
        isGeneratingInvoice: true,
        onGenerateInvoice: {},
        onClearInvoice: {}
    )
    .frame(width: 400, height: 600)
}

#Preview("With Error") {
    @Previewable @State var amount = "999999999"
    @Previewable @State var note = ""
    
    LightningInvoiceFormView_iOS(
        amount: $amount,
        note: $note,
        lightningInvoice: nil,
        invoiceError: "Amount too large. Maximum is 10,000,000 sats",
        isGeneratingInvoice: false,
        onGenerateInvoice: {},
        onClearInvoice: {}
    )
    .frame(width: 400, height: 600)
}

#Preview("Invoice Generated") {
    @Previewable @State var amount = "50000"
    @Previewable @State var note = "Payment for services"
    
    LightningInvoiceFormView_iOS(
        amount: $amount,
        note: $note,
        lightningInvoice: "{\"invoice\":\"lnbc500n1...\"}",
        invoiceError: nil,
        isGeneratingInvoice: false,
        onGenerateInvoice: {},
        onClearInvoice: {}
    )
    .frame(width: 400, height: 600)
}
