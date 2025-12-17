//
//  RefreshModalFormView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/24/25.
//

import SwiftUI

struct RefreshModalFormView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            Image("board") // Using same image as boarding for now
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(15)
                .clipped()
            
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Refresh spending balance")
                        .font(.system(size: 24, design: .serif))
                    
                    Text("Keep your wallet fresh to send and receive payments.")
                        .font(.default)
                        .foregroundColor(.secondary)
                }
            }
            
            Button {
                onConfirm()
            } label: {
                Text("Refresh")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.arkeDark)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Color.arkeGold)
            
            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Cancel")
            }
        }
    }
}

#Preview {
    RefreshModalFormView(
        onConfirm: {
            print("Refreshing wallet")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
