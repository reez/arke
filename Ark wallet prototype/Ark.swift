//
//  Ark_wallet_prototypeApp.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import SwiftData

@main
struct Ark: App {
    @State private var walletManager = WalletManager()
    
    /// Shared service container for tag and contact management
    let serviceContainer = ServiceContainer.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(walletManager)
                .withServiceContainer(serviceContainer)
                .withServiceConfiguration()
                .onDisappear {
                    serviceContainer.cleanup()
                }
        }
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentMinSize)
        .modelContainer(for: [
            TransactionModel.self, 
            ArkBalanceModel.self, 
            OnchainBalanceModel.self,
            PersistentTag.self,
            TransactionTagAssignment.self,
            PersistentContact.self,
            TransactionContactAssignment.self
        ])
    }
}
