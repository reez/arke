//
//  CustomNumericKeypad.swift
//  Arké
//
//  Created by Christoph on 5/23/26.
//

import SwiftUI
import ArkeUI

/// Custom numeric keypad for quick amount input in TiltShareOverlay
struct CustomNumericKeypad: View {
    @Binding var amount: String
    let onConfirm: () -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            // Row 1: 1, 2, 3
            keypadButton("1")
            keypadButton("2")
            keypadButton("3")
            
            // Row 2: 4, 5, 6
            keypadButton("4")
            keypadButton("5")
            keypadButton("6")
            
            // Row 3: 7, 8, 9
            keypadButton("7")
            keypadButton("8")
            keypadButton("9")
            
            // Row 4: backspace, 0, confirm
            backspaceButton()
            keypadButton("0")
            confirmButton()
        }
        .padding(20)
    }
    
    // MARK: - Button Views
    
    private func keypadButton(_ digit: String) -> some View {
        Button {
            appendDigit(digit)
        } label: {
            Text(digit)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(2/1, contentMode: .fit)
                .background(Material.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func backspaceButton() -> some View {
        Button {
            deleteLastDigit()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(2/1, contentMode: .fit)
                .background(Material.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(amount.isEmpty)
        .opacity(amount.isEmpty ? 0.5 : 1.0)
    }
    
    private func confirmButton() -> some View {
        Button {
            confirmAmount()
        } label: {
            ZStack {
                if amount.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Material.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.Arke.gold.opacity(0.8))
                }
                
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(2/1, contentMode: .fit)
        }
        .disabled(amount.isEmpty)
    }
    
    // MARK: - Actions
    
    private func appendDigit(_ digit: String) {
        // Prevent leading zeros
        if amount == "0" && digit == "0" {
            return
        }
        if amount == "0" && digit != "0" {
            amount = digit
        } else {
            amount += digit
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func deleteLastDigit() {
        guard !amount.isEmpty else { return }
        amount.removeLast()
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func confirmAmount() {
        guard !amount.isEmpty else { return }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        onConfirm()
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var amount = "1000"
    
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        VStack {
            Text(amount.isEmpty ? "Enter amount" : "\(amount) sats")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding()
            
            Spacer()
            
            CustomNumericKeypad(amount: $amount) {
                print("Confirmed amount: \(amount)")
            }
            .frame(height: 300)
        }
    }
}
