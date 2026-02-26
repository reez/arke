//
//  AutoAssignSummaryRow.swift
//  Arké
//
//  Created by Christoph on 11/11/25.
//

import SwiftUI
import ArkeUI

struct AutoAssignSummaryRow: View {
    let transaction: TransactionModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Transaction type icon
            Image(systemName: transaction.transactionType == .received ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundColor(transaction.transactionType == .received ? .Arke.green : .Arke.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.formattedAmount)
                    .font(.headline)
                
                Text(transaction.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status badge
            Text(transaction.status.displayName.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var statusColor: Color {
        switch transaction.transactionStatus {
        case .confirmed:
            return .Arke.green
        case .pending:
            return .Arke.orange
        case .failed:
            return .Arke.red
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Confirmed received transaction
        AutoAssignSummaryRow(
            transaction: TransactionModel(
                txid: "preview1",
                movementId: 1,
                type: .received,
                amount: 50000,
                date: Date().addingTimeInterval(-3600),
                status: .confirmed,
                address: nil
            )
        )
        
        // Pending sent transaction
        AutoAssignSummaryRow(
            transaction: TransactionModel(
                txid: "preview2",
                movementId: 2,
                type: .sent,
                amount: 25000,
                date: Date().addingTimeInterval(-7200),
                status: .pending,
                address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
            )
        )
        
        // Failed sent transaction
        AutoAssignSummaryRow(
            transaction: TransactionModel(
                txid: "preview3",
                movementId: 3,
                type: .sent,
                amount: 100000,
                date: Date().addingTimeInterval(-86400),
                status: .failed,
                address: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"
            )
        )
    }
    .padding()
}
