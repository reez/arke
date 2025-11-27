//
//  SendView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct SendView_iOS: View {
    let prefilledRecipient: String?
    let prefilledContact: ContactModel?
    let onNavigateToContact: (ContactModel) -> Void
    
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Send View")
                    .font(.largeTitle)
                
                if let recipient = prefilledRecipient {
                    Text("Recipient: \(recipient)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text("Implement your send form here")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
