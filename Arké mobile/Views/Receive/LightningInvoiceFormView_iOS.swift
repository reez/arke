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
            Text(hasInvoice ? "Share Lightning request" : "Create Lightning request")
                .font(.system(size: 24, design: .serif))
                .multilineTextAlignment(.center)
            
            // Form fields
            AmountAndNoteInputView(
                amount: $amount,
                note: $note,
                showingAmountAndNote: .constant(true),
                amountPlaceholder: "Enter amount (required)",
                notePlaceholder: "Add note (optional)",
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
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal, 20)
            }
            
            // Action button
            if hasInvoice {
                Button {
                    onClearInvoice()
                } label: {
                    HStack(spacing: 6) {
                        Text("Clear Request")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
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
                        Text(isGeneratingInvoice ? "Generating..." : "Generate Request")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.arkeDark)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.arkeGold)
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
