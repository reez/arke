//
//  MainView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @State private var hasWallet: Bool = false
    @State private var isCheckingWallet: Bool = true
    @State private var walletManager = WalletManager()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.securityService) private var securityService
    
    var body: some View {
        Group {
            if isCheckingWallet {
                // Show loading state while checking for wallet
                LoadingView()
            } else if hasWallet {
                // Main application UI when wallet exists
                WalletView(onWalletDeleted: {
                    // Reset state to show onboarding flow
                    hasWallet = false
                })
                .environment(walletManager)
            } else {
                // Onboarding sequence when no wallet found
                OnboardingFlow(onWalletReady: {
                    Task {
                        // Initialize the wallet after creation
                        await walletManager.initialize()
                        hasWallet = true
                    }
                })
            }
        }
        .task {
            // Set model context for both managers
            walletManager.setModelContext(modelContext)
            securityService.setModelContext(modelContext)
            await checkForExistingWallet()
        }
    }
    
    private func checkForExistingWallet() async {
        // Use SecurityService to detect wallet state
        let state = await securityService.detectWalletState()
        
        switch state {
        case .walletWithSeed:
            // Wallet exists with mnemonic in local keychain
            print("✅ Wallet found with seed in keychain")
            
            // DEBUG: Print the actual mnemonic
            do {
                if let mnemonic = try securityService.loadMnemonic() {
                    print("🔐 DEBUG - Mnemonic: \(mnemonic)")
                } else {
                    print("⚠️ DEBUG - Mnemonic was nil")
                }
            } catch {
                print("❌ DEBUG - Failed to load mnemonic: \(error)")
            }
            
            hasWallet = true
            
        case .walletWithoutSeed:
            // Wallet found on another device (via iCloud), but no local seed
            print("⚠️ Wallet found on another device, but no seed locally")
            // User needs to recover by entering their mnemonic
            hasWallet = false
            
        case .noWallet:
            // No wallet found anywhere
            print("ℹ️ No wallet found")
            hasWallet = false
            
        case .unknown:
            // Unable to determine state
            print("❓ Unable to determine wallet state")
            hasWallet = false
        }
        
        isCheckingWallet = false
    }
}

#Preview {
    MainView()
}
