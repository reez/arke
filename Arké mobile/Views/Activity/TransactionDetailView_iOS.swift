//
//  TransactionDetailView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct TransactionDetailView_iOS: View {
    let transaction: TransactionModel
    let onNavigateToContact: (ContactModel) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Transaction Detail")
                    .font(.largeTitle)
                
                Text("Transaction ID: \(transaction.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Implement your transaction detail UI here
            }
            .padding()
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }
}
