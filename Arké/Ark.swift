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
    
    /// CloudKit-enabled model container for syncing data across devices
    let modelContainer: ModelContainer = {
        SwiftDataHelper.createModelContainer(
            for: PersistentTransaction.self, 
                 ArkBalanceModel.self, 
                 OnchainBalanceModel.self,
                 PersistentTag.self,
                 TransactionTagAssignment.self,
                 PersistentContact.self,
                 TransactionContactAssignment.self,
                 PersistentContactAddress.self,
            cloudKitEnabled: true  // 🌥️ CloudKit sync enabled for alpha
        )
    }()

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
        .modelContainer(modelContainer)
    }
}
