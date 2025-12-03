//
//  AmountAndNoteInputView.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/21/25.
//

import SwiftUI

struct AmountAndNoteInputView: View {
    @Binding var amount: String
    @Binding var note: String
    @Binding var showingAmountAndNote: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            amountAndNoteInputView
            /*
            if !showingAmountAndNote {
                amountAndNoteToggleButton
            } else {
                amountAndNoteInputView
            }
             */
        }
        .padding(.bottom, 10)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    @ViewBuilder
    private var amountAndNoteToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingAmountAndNote = true
            }
        } label: {
            HStack(spacing: 6) {
                Text("Add amount and note")
                    .font(.body)
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var amountAndNoteInputView: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                amountInputField
                Divider()
                    .padding(.leading, 25)
                    .padding(.trailing, 25)
                noteInputField
            }
        }
    }
    
    @ViewBuilder
    private var amountInputField: some View {
        HStack(spacing: 8) {
            TextField("Add amount (optional)", text: $amount)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.leading, 25)
                .padding(.vertical, 12)
            Spacer()
            Text("₿")
                .font(.system(.body, design: .monospaced))
                .padding(.trailing, 25)
        }
    }
    
    @ViewBuilder
    private var noteInputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Add note (optional)", text: $note)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 25)
                .padding(.vertical, 12)
        }
    }
}

#Preview {
    @Previewable @State var amount = ""
    @Previewable @State var note = ""
    @Previewable @State var showingAmountAndNote = false
    
    AmountAndNoteInputView(
        amount: $amount,
        note: $note,
        showingAmountAndNote: $showingAmountAndNote
    )
    .padding()
    .frame(width: 400, height: 200)
}
