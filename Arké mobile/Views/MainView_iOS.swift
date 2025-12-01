//
//  ContentView.swift
//  Arké mobile
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
import SwiftData

struct MainView_iOS: View {
    @State private var hasWallet: Bool = false
    @State private var isCheckingWallet: Bool = true
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
                OnboardingFlow_iOS(onWalletReady: {
                    Task {
                        // Activate services now that wallet exists
                        serviceContainer.setActive(true)
                        
                        // Configure services with model context to begin loading data
                        serviceContainer.configureServices(with: modelContext)
                        
                        // Initialize the wallet after creation
                        await walletManager.initialize()
                        hasWallet = true
                    }
                })
            }
        }
        .task {
            print("🔍 [MainView_iOS] .task started at \(Date())")
            
            // Set model context first - fast operation
            print("🔍 [MainView_iOS] Setting model context...")
            walletManager.setModelContext(modelContext)
            print("🔍 [MainView_iOS] Model context set at \(Date())")
            
            // Check for wallet and update UI immediately (fast path uses cached detection)
            await checkForExistingWallet()
            print("🔍 [MainView_iOS] checkForExistingWallet completed at \(Date())")
        }
    }
    
    private func checkForExistingWallet() async {
        print("🔍 [MainView_iOS] checkForExistingWallet started at \(Date())")
        
        // Use the early detection result from app initialization
        // This avoids redundant keychain checks and SwiftData queries
        if initialWalletDetected {
            print("✅ Using cached wallet detection result: wallet exists")
            
            // Set UI state FIRST so view transitions immediately
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
