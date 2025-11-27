//
//  Arke__mobileApp.swift
//  Arké mobile
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
import SwiftData

@main
struct Arke_mobile: App {
    /// Shared service container for tag and contact management
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
            MainView_iOS()
                .environment(walletManager)
                .withServiceContainer(serviceContainer)
                .withServiceConfiguration()
                .onDisappear {
                    serviceContainer.cleanup()
                }
        }
        .modelContainer(modelContainer)
    }
}
