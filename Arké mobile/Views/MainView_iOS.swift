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
    
    // MARK: - Device Registration Coordination
    
    /// Registers the current device after wallet detection or creation
    /// Should be called AFTER ServiceContainer has been configured with ModelContext
    private func registerDeviceIfNeeded() async {
        // Get hash from SecurityService (no side effects)
        guard let hash = securityService.getWalletHashForRegistration() else {
            #if DEBUG
            print("⏭️ [MainView] No wallet hash available for device registration")
            #endif
            return
        }
        
        // Determine if this device has the seed
        let hasSeed = securityService.hasMnemonic()
        
        // Register device (SwiftData operation)
        do {
            try await serviceContainer.deviceRegistrationService.registerCurrentDevice(
                walletHash: hash,
                hasSeed: hasSeed
            )
            
            #if DEBUG
            print("✅ [MainView] Device registered with hasSeed=\(hasSeed)")
            #endif
        } catch {
            // Log but don't fail - device registration is not critical
            #if DEBUG
            print("⚠️ [MainView] Device registration failed: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - View Body
    
    var body: some View {
        ZStack {
            if isCheckingWallet {
                // Show loading state while checking for wallet
                LoadingView_iOS()
                    .transition(.opacity)
            } else if hasWallet {
                // Main application UI when wallet exists
                WalletView_iOS(onWalletDeleted: {
                    // Stop CloudKit sync when wallet is deleted
                    serviceContainer.stopCloudKitSync()
                    
                    // Deactivate services
                    serviceContainer.setActive(false)
                    
                    // Reset state to show onboarding flow with animation
                    withAnimation(.smooth(duration: 0.6)) {
                        hasWallet = false
                    }
                })
                .environment(walletManager)
                .transition(.move(edge: .bottom))
            } else {
                // Onboarding sequence when no wallet found
                OnboardingFlow_iOS(
                    walletState: walletState,
                    onWalletReady: {
                        Task {
                            // 1. Activate services now that wallet exists
                            serviceContainer.setActive(true)
                            
                            // 2. Configure services with model context (CRITICAL: must happen before registration)
                            print("🔧 [MainView_iOS] 📞 Calling serviceContainer.configureServices()...")
                            serviceContainer.configureServices(with: modelContext)
                            
                            // 3. Start CloudKit sync now that wallet exists
                            serviceContainer.startCloudKitSync(modelContainer: modelContext.container)
                            
                            // 4. Register for remote notifications
                            await MainActor.run {
                                #if os(iOS)
                                UIApplication.shared.registerForRemoteNotifications()
                                print("🔔 [MainView] Registered for remote notifications")
                                #endif
                            }
                            
                            // 5. Register device (NOW ModelContext is available)
                            await registerDeviceIfNeeded()
                            
                            // 6. Initialize the wallet after creation
                            print("🔧 [MainView_iOS] 📍 CALL #3: Initializing newly created wallet...")
                            print("   └─ Location: MainView_iOS onWalletReady callback (OnboardingFlow_iOS)")
                            await walletManager.initialize()
                            print("✅ [MainView_iOS] 📍 CALL #3: New wallet initialization complete")
                            
                            // 7. Update UI with animation
                            withAnimation(.smooth(duration: 0.6)) {
                                hasWallet = true
                            }
                        }
                    }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.smooth(duration: 0.4), value: hasWallet)
        .task {
            print("🔍 [MainView_iOS] .task started at \(Date())")
            
            // Subscribe to NSUbiquitousKeyValueStore changes
            subscribeToUbiquitousStoreChanges()
            
            // Subscribe to foreground notifications for heartbeat updates
            subscribeToForegroundNotifications()
            
            // Set model context first - fast operation
            print("🔍 [MainView_iOS] 📞 Calling walletManager.setModelContext()...")
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
            
            // Set UI state FIRST so view transitions immediately (without animation)
            walletState = .walletWithSeed
            hasWallet = true
            
            // Disable animation for initial loading -> wallet transition
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isCheckingWallet = false
            }
            
            print("🔍 [MainView_iOS] UI transition complete - wallet will initialize in true background")
            
            // Register device (services are already configured at this point)
            await registerDeviceIfNeeded()
            
            // Initialize wallet in a detached task so it doesn't block UI
            Task.detached { [weak walletManager] in
                guard let walletManager = walletManager else { return }
                print("🔧 [MainView_iOS] 📍 CALL #1: Initializing wallet in detached background task... at \(Date())")
                print("   └─ Location: MainView_iOS cached detection path")
                await walletManager.initialize()
                print("✅ [MainView_iOS] 📍 CALL #1: Wallet initialization complete at \(Date())")
            }
        } else {
            // Perform deeper check only for edge cases (wallet on other device, etc.)
            print("⚠️ No wallet detected in early check, performing deeper detection...")
            let state = await securityService.detectWalletState()
            walletState = state
            print("🔍 [MainView_iOS] detectWalletState returned: \(state) at \(Date())")
            
            // Register device after detection (if not .noWallet)
            if state != .noWallet && state != .unknown {
                await registerDeviceIfNeeded()
            }
            
            switch state {
            case .walletWithSeed:
                // Wallet exists with mnemonic in local keychain
                print("✅ Wallet found with seed in keychain")
                
                // Set UI state FIRST for immediate transition (without animation)
                hasWallet = true
                
                // Disable animation for initial loading -> wallet transition
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isCheckingWallet = false
                }
                
                // Initialize wallet in detached task
                Task.detached { [weak walletManager] in
                    guard let walletManager = walletManager else { return }
                    print("🔧 [MainView_iOS] 📍 CALL #2: Initializing wallet in detached background task... at \(Date())")
                    print("   └─ Location: MainView_iOS deep detection path (walletWithSeed)")
                    await walletManager.initialize()
                    print("✅ [MainView_iOS] 📍 CALL #2: Wallet initialization complete")
                }
                
            case .walletWithoutSeed:
                // Wallet found on another device (via iCloud), but no local seed
                print("⚠️ Wallet found on another device, but no seed locally")
                // User needs to recover by entering their mnemonic
                hasWallet = false
                
                // Disable animation for initial loading -> onboarding transition
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isCheckingWallet = false
                }
                
            case .noWallet:
                // No wallet found anywhere
                print("ℹ️ No wallet found")
                hasWallet = false
                
                // Disable animation for initial loading -> onboarding transition
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isCheckingWallet = false
                }
                
            case .unknown:
                // Unable to determine state
                print("❓ Unable to determine wallet state")
                hasWallet = false
                
                // Disable animation for initial loading -> onboarding transition
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isCheckingWallet = false
                }
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
                .tint(.primary)
            
            Text("You look great today!")
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(.primary)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
