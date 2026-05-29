//
//  LightningInvoiceFormView.swift
//  Arké
//
//  Created by Assistant on 1/28/26.
//

import SwiftUI
import ArkeUI

/// Fluent Lightning invoice creation form with numeric keypad and optional note
struct LightningInvoiceFormView_iOS: View {
    @Binding var amount: String
    @Binding var note: String
    @State private var showNoteField = false
    @FocusState private var isNoteFocused: Bool
    
    let onGenerateInvoice: () -> Void
    
    private var formattedAmount: String {
        guard let sats = Int(amount), sats > 0 else { return "0" }
        return BitcoinFormatter.shared.formatAmount(sats)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Amount display area - fills available space
            VStack(spacing: 16) {
                if amount.isEmpty {
                    Text("0")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.3))
                        .lineLimit(1)
                } else {
                    Text(formattedAmount)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                // Optional note toggle/field
                if showNoteField {
                    TextField("placeholder_note_optional", text: $note)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNoteFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showNoteField = false
                                isNoteFocused = false
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if !note.isEmpty {
                    // Show entered note as tappable text
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNoteField = true
                            isNoteFocused = true
                        }
                    } label: {
                        Text(note)
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 40)
                } else {
                    // Show "+ Add note" button when empty
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNoteField = true
                            isNoteFocused = true
                        }
                    } label: {
                        Text("Add note")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            
            Spacer()
                .frame(minHeight: 0)
            
            // Keypad at bottom (hidden when note field is active)
            if !showNoteField {
                CustomNumericKeypad(amount: $amount, onConfirm: {
                    onGenerateInvoice()
                }, textColor: .primary)
                .frame(height: 240)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: showNoteField)
    }
}

#Preview("Empty Form") {
    @Previewable @State var amount = ""
    @Previewable @State var note = ""
    
    LightningInvoiceFormView_iOS(
        amount: $amount,
        note: $note,
        onGenerateInvoice: {
            print("Generate invoice: \(amount) sats")
        }
    )
}

#Preview("With Amount") {
    @Previewable @State var amount = "50000"
    @Previewable @State var note = ""
    
    LightningInvoiceFormView_iOS(
        amount: $amount,
        note: $note,
        onGenerateInvoice: {
            print("Generate invoice: \(amount) sats, note: \(note)")
        }
    )
}

#Preview("With Note") {
    @Previewable @State var amount = "50000"
    @Previewable @State var note = "Coffee payment"
    
    LightningInvoiceFormView_iOS(
        amount: $amount,
        note: $note,
        onGenerateInvoice: {
            print("Generate invoice: \(amount) sats, note: \(note)")
        }
    )
}
