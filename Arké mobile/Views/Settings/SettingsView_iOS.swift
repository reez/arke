//
//  SettingsView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct SettingsView_iOS: View {
    let onWalletDeleted: (() -> Void)?
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        Form {
            Section("Wallet") {
                Text("Wallet settings coming soon")
                    .foregroundStyle(.secondary)
            }
            
            Section {
                Button("Delete Wallet", role: .destructive) {
                    onWalletDeleted?()
                }
            }
        }
    }
}
