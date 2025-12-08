//
//  ContactTransactionSummaryView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/13/25.
//

import SwiftUI

struct ContactTransactionSummaryView: View {
    let contact: ContactModel
    let onViewActivity: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sent")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(contact.formattedSentAmount ?? "0 ₿")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Received")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(contact.formattedReceivedAmount ?? "0 ₿")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
            
            if let transactionCount = contact.formattedTransactionCount {
                Button(action: onViewActivity) {
                    Text(transactionCount)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ContactTransactionSummaryView(
        contact: ContactModel(
            cachedName: "John Doe",
            transactionCount: 5,
            sentAmount: 25000,
            receivedAmount: 75000
        ),
        onViewActivity: { print("View activity tapped") }
    )
    .padding()
}
