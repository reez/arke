//
//  TransactionTestingView_iOS.swift
//  Arké
//
//  Created by Assistant on 12/15/25.
//

import SwiftUI
import ArkeUI

/// Developer tool for testing transaction functionality at scale
struct TransactionTestingView_iOS: View {
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        List {
            Section {
                Text("Transaction testing tools for developers")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                
                NavigationLink(destination: IncrementalPaymentTestView_iOS()) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spam Payments")
                            .font(.system(size: 16))
                        Text("Send multiple payments with increasing amounts")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                NavigationLink(destination: InvoiceGenerationTestView_iOS()) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Generate Invoices")
                            .font(.system(size: 16))
                        Text("Create multiple Lightning invoices and copy to clipboard")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Transaction Testing")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        TransactionTestingView_iOS()
            .environment(WalletManager(useMock: true))
    }
}
