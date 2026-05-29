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
    @State private var gradientPhase: CGFloat = 0
    
    let onGenerateInvoice: () -> Void
    
    private var formattedAmount: String {
        // If user is typing a partial decimal (e.g., "0.", "0.00"), show the raw input with symbol
        if BitcoinFormatter.shared.allowsDecimalInput && amount.contains(".") {
            return BitcoinFormatter.shared.formatPartialDecimalInput(amount)
        }
        
        // Otherwise, parse and format the complete value
        guard let sats = BitcoinFormatter.shared.parseUserInput(amount) else {
            return BitcoinFormatter.shared.formatAmount(0)
        }
        return BitcoinFormatter.shared.formatAmount(sats)
    }
    
    /// Check if the amount is 21 or 21 followed by zeros (e.g., 21, 210, 2100, 21000, etc.)
    private var isTwentyOnePattern: Bool {
        guard let sats = BitcoinFormatter.shared.parseUserInput(amount), sats > 0 else { return false }
        let str = String(sats)
        return str.hasPrefix("21") && str.dropFirst(2).allSatisfy { $0 == "0" }
    }
    
    /// Dynamic font size that shrinks as text gets longer
    private var dynamicFontSize: CGFloat {
        let baseSize: CGFloat = 56
        let threshold = 6
        let length = formattedAmount.count
        
        if length <= threshold {
            return baseSize
        }
        
        // Reduce by 1 point for each character beyond threshold
        let reduction = CGFloat(length - threshold)
        return max(baseSize - reduction*1.5, 20) // Minimum size of 20 to keep it readable
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Amount display area - fills available space
            VStack(spacing: 16) {
                Group {
                    if isTwentyOnePattern {
                        Text(formattedAmount)
                            .font(.system(size: dynamicFontSize, weight: .bold, design: .rounded))
                            .overlay {
                                LinearGradient(
                                    colors: [Color.Arke.orange, Color.Arke.yellow, Color.Arke.orange, Color.Arke.yellow, Color.Arke.orange],
                                    startPoint: UnitPoint(x: -1 + gradientPhase * 3, y: 0.2),
                                    endPoint: UnitPoint(x: 0 + gradientPhase * 3, y: 0.8)
                                )
                                .mask {
                                    Text(formattedAmount)
                                        .font(.system(size: dynamicFontSize, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundStyle(.clear)
                    } else {
                        Text(formattedAmount)
                            .font(.system(size: dynamicFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(amount.isEmpty ? 0.3 : 1.0))
                    }
                }
                .frame(height: 56) // Fixed height to prevent layout shifts
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: formattedAmount)
                .onAppear {
                    if isTwentyOnePattern {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                            gradientPhase = 1.0
                        }
                    }
                }
                .onChange(of: isTwentyOnePattern) { _, isSpecial in
                    if isSpecial {
                        gradientPhase = 0
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                            gradientPhase = 1.0
                        }
                    } else {
                        gradientPhase = 0
                    }
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
                CustomNumericKeypad(
                    amount: $amount,
                    onConfirm: {
                        onGenerateInvoice()
                    },
                    textColor: .primary,
                    showPeriod: BitcoinFormatter.shared.allowsDecimalInput,
                    validateInput: { newAmount in
                        // Validate that amount doesn't exceed limits
                        guard let sats = BitcoinFormatter.shared.parseUserInput(newAmount) else {
                            return true // Allow partial input while typing
                        }
                        // Lightning invoice limit: max 1 BTC (100,000,000 sats)
                        return sats <= 100_000_000
                    }
                )
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
