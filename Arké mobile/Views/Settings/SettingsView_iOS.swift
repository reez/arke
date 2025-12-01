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
        VStack(spacing: 10) {
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
    }
}
