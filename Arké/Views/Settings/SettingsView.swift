//
//  SettingsView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI

struct SettingsView: View {
    let onWalletDeleted: (() -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // Recovery Phrase Section
                RecoveryPhraseSettingView()
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            Divider()
            
            // Bitcoin Format Setting
            BitcoinFormatSettingView()
                .padding()
            
            Divider()
            
            // Delete Wallet Section
            DeleteWalletSettingView(onWalletDeleted: onWalletDeleted)
                .padding()
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView(onWalletDeleted: nil)
        .environment(WalletManager(useMock: true))
}
