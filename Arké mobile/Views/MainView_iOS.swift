//
//  ContentView.swift
//  Arké mobile
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
import SwiftData
import Combine

struct MainView_iOS: View {
    @State private var hasWallet: Bool = false
    @State private var isCheckingWallet: Bool = true
    @State private var walletState: WalletState = .unknown
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.securityService) private var securityService
    @Environment(\.serviceContainer) private var serviceContainer
    @Environment(\.initialWalletDetected) private var initialWalletDetected
    
    var body: some View {
        Group {
            if isCheckingWallet {
                // Show loading state while checking for wallet
                LoadingView_iOS()
            } else if hasWallet {
                // Main application UI when wallet exists
                WalletView_iOS(onWalletDeleted: {
                    // Reset state to show onboarding flow
                    hasWallet = false
                })
                .environment(walletManager)
            } else {
                // Onboarding sequence when no wallet found
                OnboardingFlow_iOS(
                    walletState: walletState,
                    onWalletReady: {
                        Task {
                            // Activate services now that wallet exists
                            serviceContainer.setActive(true)
                            
                            // Configure services with model context to begin loading data
                            serviceContainer.configureServices(with: modelContext)
                            
                            // Initialize the wallet after creation
                            await walletManager.initialize()
                            hasWallet = true
                        }
                    }
                )
            }
        }
        .task {
            print("🔍 [MainView_iOS] .task started at \(Date())")
            
            // Subscribe to NSUbiquitousKeyValueStore changes
            subscribeToUbiquitousStoreChanges()
            
            // Subscribe to foreground notifications for heartbeat updates
            subscribeToForegroundNotifications()
            
            // Set model context first - fast operation
            print("🔍 [MainView_iOS] Setting model context...")
            walletManager.setModelContext(modelContext)
            print("🔍 [MainView_iOS] Model context set at \(Date())")
            
            // Check for wallet and update UI immediately (fast path uses cached detection)
            await checkForExistingWallet()
            print("🔍 [MainView_iOS] checkForExistingWallet completed at \(Date())")
            
            // Update device heartbeat if needed (only if wallet exists)
            if hasWallet {
                await serviceContainer.deviceRegistrationService.updateHeartbeatIfNeeded()
            }
        }
        .onDisappear {
            unsubscribeFromUbiquitousStoreChanges()
            unsubscribeFromForegroundNotifications()
        }
    }
    
    // MARK: - Foreground Notification Handling
    
    private func subscribeToForegroundNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                // Update heartbeat when app enters foreground
                await serviceContainer.deviceRegistrationService.updateHeartbeatIfNeeded()
            }
        }
        
        #if DEBUG
        print("🔔 [MainView_iOS] Subscribed to foreground notifications")
        #endif
    }
    
    private func unsubscribeFromForegroundNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        #if DEBUG
        print("🔕 [MainView_iOS] Unsubscribed from foreground notifications")
        #endif
    }
    
    // MARK: - NSUbiquitousKeyValueStore Observation
    
    private func subscribeToUbiquitousStoreChanges() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { notification in
            Task { @MainActor in
                await self.handleUbiquitousStoreChange(notification)
            }
        }
        
        #if DEBUG
        print("🔔 [MainView_iOS] Subscribed to NSUbiquitousKeyValueStore changes")
        #endif
    }
    
    private func unsubscribeFromUbiquitousStoreChanges() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        
        #if DEBUG
        print("🔕 [MainView_iOS] Unsubscribed from NSUbiquitousKeyValueStore changes")
        #endif
    }
    
    private func handleUbiquitousStoreChange(_ notification: Notification) async {
        guard let userInfo = notification.userInfo else { return }
        
        #if DEBUG
        print("🔕 [MainView_iOS] handleUbiquitousStoreChange")
        #endif
        
        // Check if the change reason indicates an external change
        if let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int {
            let reason: String
            switch changeReason {
            case NSUbiquitousKeyValueStoreServerChange:
                reason = "Server change"
            case NSUbiquitousKeyValueStoreInitialSyncChange:
                reason = "Initial sync"
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                reason = "Quota violation"
            case NSUbiquitousKeyValueStoreAccountChange:
                reason = "Account change"
            default:
                reason = "Unknown change (\(changeReason))"
            }
            
            #if DEBUG
            print("📦 [MainView_iOS] NSUbiquitousKeyValueStore change detected: \(reason)")
            #endif
        }
        
        // Check if the ubiquitousHashKey was changed
        if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            let ubiquitousHashKey = "com.arke.wallet.mnemonicHash"
            
            if changedKeys.contains(ubiquitousHashKey) {
                // Check if the hash value exists or was deleted
                let store = NSUbiquitousKeyValueStore.default
                let hashValue = store.string(forKey: ubiquitousHashKey)
                
                if let _ = hashValue {
                    #if DEBUG
                    print("✅ [MainView_iOS] ubiquitousHashKey added - wallet created on another device")
                    print("   → Re-detecting wallet state to show 'Link existing wallet' option")
                    #endif
                } else {
                    #if DEBUG
                    print("🗑️ [MainView_iOS] ubiquitousHashKey removed - wallet deleted on another device")
                    print("   → Re-detecting wallet state to hide 'Link existing wallet' option")
                    #endif
                }
                
                // Re-detect wallet state when hash changes
                // This will update walletState and trigger appropriate UI changes
                let newState = await securityService.detectWalletState()
                walletState = newState
                
                #if DEBUG
                print("🔄 [MainView_iOS] Wallet state updated to: \(newState)")
                #endif
                
                // If we're currently in onboarding and a wallet was created on another device,
                // the UI will automatically show the "Link existing wallet" option
                // If the hash was deleted, it will show the standard create/import options
            }
        }
    }
    
    private func checkForExistingWallet() async {
        print("🔍 [MainView_iOS] checkForExistingWallet started at \(Date())")
        
        // Use the early detection result from app initialization
        // This avoids redundant keychain checks and SwiftData queries
        if initialWalletDetected {
            print("✅ Using cached wallet detection result: wallet exists")
            
            // Set UI state FIRST so view transitions immediately
            walletState = .walletWithSeed
            hasWallet = true
            isCheckingWallet = false
            
            print("🔍 [MainView_iOS] UI transition complete - wallet will initialize in true background")
            
            // Initialize wallet in a detached task so it doesn't block UI
            Task.detached { [weak walletManager] in
                guard let walletManager = walletManager else { return }
                print("🔧 [MainView_iOS] Initializing wallet in detached background task... at \(Date())")
                await walletManager.initialize()
                print("✅ [MainView_iOS] Wallet initialization complete at \(Date())")
            }
        } else {
            // Perform deeper check only for edge cases (wallet on other device, etc.)
            print("⚠️ No wallet detected in early check, performing deeper detection...")
            let state = await securityService.detectWalletState()
            walletState = state
            print("🔍 [MainView_iOS] detectWalletState returned: \(state) at \(Date())")
            
            switch state {
            case .walletWithSeed:
                // Wallet exists with mnemonic in local keychain
                print("✅ Wallet found with seed in keychain")
                
                // Set UI state FIRST for immediate transition
                hasWallet = true
                isCheckingWallet = false
                
                // Initialize wallet in detached task
                Task.detached { [weak walletManager] in
                    guard let walletManager = walletManager else { return }
                    print("🔧 [MainView_iOS] Initializing wallet in detached background task... at \(Date())")
                    await walletManager.initialize()
                    print("✅ [MainView_iOS] Wallet initialization complete")
                }
                
            case .walletWithoutSeed:
                // Wallet found on another device (via iCloud), but no local seed
                print("⚠️ Wallet found on another device, but no seed locally")
                // User needs to recover by entering their mnemonic
                hasWallet = false
                isCheckingWallet = false
                
            case .noWallet:
                // No wallet found anywhere
                print("ℹ️ No wallet found")
                hasWallet = false
                isCheckingWallet = false
                
            case .unknown:
                // Unable to determine state
                print("❓ Unable to determine wallet state")
                hasWallet = false
                isCheckingWallet = false
            }
        }
        
        print("🔍 [MainView_iOS] Wallet check complete at \(Date())")
    }
}

#Preview {
    MainView_iOS()
}

struct LoadingView_iOS: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.white)
            
            Text("Getting pumped up...")
                .foregroundStyle(.white)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arkeDark)
    }
}
