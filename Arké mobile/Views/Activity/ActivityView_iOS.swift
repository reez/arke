//
//  OnboardingFlow_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct ActivityView_iOS: View {
    @Environment(WalletManager.self) private var walletManager
    let onWalletReady: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let totalBalance = walletManager.totalBalance {
                    Button {
                        // TODO: Navigate to balance details view
                    } label: {
                        BalanceCard(totalBalance: totalBalance)
                    }
                    .buttonStyle(.plain)
                    .padding()
                } else {
                    SkeletonLoader(
                        itemCount: 1,
                        itemHeight: 150,
                        spacing: 10,
                        cornerRadius: 15
                    )
                    .padding()
                }
            }
        }
        .padding(20)
        .clipped() // Prevents views from showing outside bounds during transition
    }
}

#Preview {
    ActivityView_iOS(
        onWalletReady: {
            // Preview completion action
        }
    )
    .environment(WalletManager(useMock: true))
}

