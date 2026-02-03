//
//  TransactionTechnicalDetailsView.swift
//  Arké
//
//  Created by Assistant on 2/3/26.
//

import SwiftUI

/// Expandable technical details section for transactions.
/// Useful during testing and development. Can be easily removed later.
struct TransactionTechnicalDetailsView: View {
    let transaction: TransactionModel
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header button
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Text("Technical Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Image(systemName: "chevron.down")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Category
                    TechnicalDetailRow(
                        label: "Category",
                        value: transaction.category?.rawValue ?? "nil"
                    )
                    
                    Divider()
                    
                    // Type
                    TechnicalDetailRow(
                        label: "Type",
                        value: transaction.type.displayName
                    )
                    
                    Divider()
                    
                    // Status
                    TechnicalDetailRow(
                        label: "Status",
                        value: transaction.status.displayName
                    )
                    
                    Divider()
                    
                    // Raw Amount
                    TechnicalDetailRow(
                        label: "Raw Amount (sats)",
                        value: "\(transaction.amount)"
                    )
                    
                    // Fees (only show if present)
                    if let fees = transaction.fees {
                        Divider()
                        
                        TechnicalDetailRow(
                            label: "Offchain Fee (sats)",
                            value: "\(fees)"
                        )
                    }
                    
                    // Onchain Fee (only show if present)
                    if let onchainFee = transaction.onchainFeeSat {
                        Divider()
                        
                        TechnicalDetailRow(
                            label: "Onchain Fee (sats)",
                            value: "\(onchainFee)"
                        )
                    }
                    
                    // Address (only show if present)
                    if let address = transaction.address {
                        Divider()
                        
                        TechnicalDetailRow(
                            label: "Raw Address",
                            value: address
                        )
                    }
                    
                    Divider()
                    
                    // Timestamp
                    TechnicalDetailRow(
                        label: "Timestamp",
                        value: ISO8601DateFormatter().string(from: transaction.date)
                    )
                    
                    Divider()
                    
                    // Recipient Index
                    TechnicalDetailRow(
                        label: "Recipient Index",
                        value: transaction.recipientIndex?.description ?? "nil"
                    )
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(25)
                .padding(.top, 8)
            }
        }
        .padding(.top, 30)
    }
}

// MARK: - Supporting Views

private struct TechnicalDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    TransactionTechnicalDetailsView(
        transaction: TransactionModel(
            txid: "1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z",
            movementId: 12345,
            recipientIndex: 0,
            type: .sent,
            amount: -125000,
            date: Date(),
            status: .confirmed,
            address: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq",
            fees: 500,
            onchainFeeSat: 300,
            category: .lightningSend
        )
    )
    .padding()
}

#Preview("Expanded") {
    struct ExpandedPreview: View {
        @State private var transaction = TransactionModel(
            txid: "movement_1",
            movementId: 1,
            recipientIndex: nil,
            type: .transfer,
            amount: 50000,
            date: Date(),
            status: .confirmed,
            address: nil,
            onchainFeeSat: 155,
            category: .boarding
        )
        
        var body: some View {
            TransactionTechnicalDetailsView(transaction: transaction)
                .padding()
                .onAppear {
                    // Auto-expand for preview
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // This won't work in preview but shows intent
                    }
                }
        }
    }
    
    return ExpandedPreview()
}
