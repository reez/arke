//
//  ContactsView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI

struct ContactsView: View {
    @Environment(WalletManager.self) private var walletManager
    
    var body: some View {
        ScrollView {
            Text("Contacts")
        }
    }
}

// MARK: - Preview

#Preview {
    ContactsView()
        .environment(WalletManager(useMock: true))
        .frame(width: 800, height: 600)
}


