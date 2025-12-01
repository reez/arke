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
    
    /// Shared service container for all app services including security, tags, and contacts
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
                 WalletConfiguration.self,
            cloudKitEnabled: true
        )
    }()
    
    // MARK: - Early Wallet Detection
    
    /// Performs lightweight wallet check before app initialization
    /// This determines whether to activate services and sync
    init() {
        let hasWallet = SecurityService.hasMnemonicInKeychain()
        
        if hasWallet {
            print("✅ [App Init] Wallet detected - services will be activated")
            serviceContainer.setActive(true)
        } else {
            print("⏭️ [App Init] No wallet detected - services will remain passive")
            serviceContainer.setActive(false)
        }
    }

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
