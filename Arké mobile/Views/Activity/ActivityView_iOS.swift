//
//  OnboardingFlow_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct ActivityView: View {
    @Environment(WalletManager.self) private var walletManager
    let onWalletReady: () -> Void
    
    var body: some View {
        ZStack {
            Text("Activity view")
        }
        .background(Color.arkeDark)
        .clipped() // Prevents views from showing outside bounds during transition
    }
}

#Preview {
    ActivityView(
        onWalletReady: {
            // Preview completion action
        }
    )
    .environment(WalletManager(useMock: true))
}

