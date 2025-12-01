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
                 WalletConfiguration.self,
            cloudKitEnabled: true  // 🌥️ CloudKit sync enabled for alpha
        )
    }()
    
    // MARK: - Early Wallet Detection
    
    /// Performs lightweight wallet check before app initialization
    /// This determines whether to activate services and sync
    init() {
        /*
        let diagnostics = NetworkDiagnostics()
        diagnostics.runAllTests()
        
        
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        let walletDir = appSupport
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.yourapp.arkwallet")
            .appendingPathComponent("bark-data-ffi")
        
        let result = testWalletOpen(
            mnemonic: "rib worth member shift decade police foster panic number burden slice cage pair planet gate fault scrub emotion hero cargo ranch intact club ocean",
            serverAddress: "https://ark.signet.2nd.dev",
            esploraAddress: "https://esplora.signet.2nd.dev",
            datadir: walletDir.path
        )

        print("Wallet Open Test Result:")
        print(result)
        
        let createConfig = Config(
            serverAddress: "https://ark.signet.2nd.dev",
            esploraAddress: "https://esplora.signet.2nd.dev",
            network: .signet,
            vtxoRefreshExpiryThreshold: nil,
            vtxoExitMargin: nil,
            htlcRecvClaimDelta: nil
        )
        
        do {
            let createTest = try Wallet.create(
                mnemonic: "rib worth member shift decade police foster panic number burden slice cage pair planet gate fault scrub emotion hero cargo ranch intact club ocean",
                config: createConfig,
                datadir: walletDir.path,
                forceRescan: false
            )
            
            print("Wallet Create Test Result:")
            print(createTest)
        } catch {
            print("⚠️ Wallet Create Test Failed:")
            print(error)
        }
        */
        
        
        /*
        URLSession.shared.dataTask(with: URL(string:"https://ark.signet.2nd.dev")!) { data, response, error in
            print("---")
            print("Baseline iOS TLS test")
            print(error?.localizedDescription ?? "No error")
            print("---")
        }.resume()
        
        URLSession(configuration: .ephemeral).downloadTask(
            with: URL(string:"https://ark.signet.2nd.dev")!
        ) { _, _, error in
            print("---")
            print("TLS-only:")
            print(error?.localizedDescription ?? "No error")
            print("---")
        }.resume()
        
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Connection": "close"]
        config.httpMaximumConnectionsPerHost = 1

        let session = URLSession(configuration: config)
        session.dataTask(with: URL(string:"https://ark.signet.2nd.dev")!) { _, _, error in
            print("---")
            print("Force HTTP/1.1:")
            print(error?.localizedDescription ?? "No error")
            print("---")
        }.resume()
        */
        //let result = testGrpcConnection()
        //print("Connection test:", result)
        
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
