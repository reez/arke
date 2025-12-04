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
    /// Lazily initialized wallet manager - created when first accessed
    /// This prevents heavy initialization during app launch
    @State private var walletManager: WalletManager?
    
    /// Shared service container for tag and contact management
    let serviceContainer = ServiceContainer.shared
    
    /// Observer for CloudKit remote change notifications
    @State private var cloudKitObserver: CloudKitObserver?
    
    /// Early detection result - whether a wallet exists (based on keychain check)
    /// This is set during init() and can be used by views to avoid redundant checks
    /// Note: Using a let constant since we can't mutate @State in init()
    let initialWalletDetected: Bool
    
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
                 DeviceRegistration.self,  // 📱 Device registry for cross-device management
            cloudKitEnabled: true,  // 🌥️ CloudKit sync enabled for alpha
            cloudKitContainerIdentifier: "iCloud.gbks.sigma"  // Explicit container ID
        )
    }()
    
    // MARK: - Early Wallet Detection
    
    /// Performs lightweight wallet check before app initialization
    /// This determines whether to activate services and sync
    init() {
        let hasWallet = SecurityService.hasMnemonicInKeychain()
        
        // Store the detection result (must be done before calling serviceContainer.setActive)
        self.initialWalletDetected = hasWallet
        
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
                .environment(walletManager ?? createWalletManager())
                .environment(\.initialWalletDetected, initialWalletDetected)
                .withServiceContainer(serviceContainer)
                .onAppear {
                    // Start observing CloudKit changes when the app appears
                    if cloudKitObserver == nil {
                        cloudKitObserver = CloudKitObserver(modelContainer: modelContainer)
                    }
                }
                .task {
                    // Register for remote notifications to receive CloudKit updates
                    await registerForCloudKitNotifications()
                }
                .onDisappear {
                    serviceContainer.cleanup()
                }
        }
        .modelContainer(modelContainer)
    }
    
    // MARK: - Lazy Initialization Helper
    
    /// Creates the wallet manager on first access
    /// This defers expensive initialization until the view hierarchy is ready
    private func createWalletManager() -> WalletManager {
        print("🔧 [App] Creating WalletManager (lazy)")
        let manager = WalletManager()
        walletManager = manager
        return manager
    }
    
    // MARK: - CloudKit Notification Registration
    
    /// Register for remote notifications to receive CloudKit push updates
    /// This allows the app to be notified immediately when changes occur on other devices
    private func registerForCloudKitNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
            print("🔔 [CloudKit] Registered for remote notifications (iOS)")
        }
    }
}

// MARK: - Environment Key for Initial Wallet Detection

/// Environment key for passing the initial wallet detection result to child views
private struct InitialWalletDetectedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var initialWalletDetected: Bool {
        get { self[InitialWalletDetectedKey.self] }
        set { self[InitialWalletDetectedKey.self] = newValue }
    }
}
