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
        HStack(alignment: .top, spacing: 25) {
            Image("board") // Using same image as boarding for now
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: 150, maxHeight: .infinity)
                .cornerRadius(15)
                .clipped()
            
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Refresh spending balance")
                        .font(.system(size: 24, design: .serif))
                    
                    Text("Keep your wallet fresh to send and receive payments.")
                        .font(.default)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Refresh") {
                    onConfirm()
                }
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
