//
//  DangerZoneSettingsView.swift
//  Arké
//
//  Created by Christoph on 12/4/25.
//

import SwiftUI

struct DangerZoneSettingsView: View {
    let onWalletDeleted: (() -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Danger Zone")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                DeleteWalletSettingView(onWalletDeleted: onWalletDeleted)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
    }
}
