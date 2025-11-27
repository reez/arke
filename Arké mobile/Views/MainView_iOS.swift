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
    @State private var walletManager = WalletManager()
    @Environment(\.modelContext) private var modelContext
    
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
                        // Initialize the wallet after creation
                        await walletManager.initialize()
                        hasWallet = true
                    }
                })
            }
        }
        .task {
            // Set model context first, then check for existing wallet
            walletManager.setModelContext(modelContext)
            await checkForExistingWallet()
        }
    }
    
    private func checkForExistingWallet() async {
        do {
            // Try to get the mnemonic from the wallet
            // If this succeeds, a wallet already exists
            _ = try await walletManager.getMnemonic()
            print("✅ Existing wallet found")
            hasWallet = true
        } catch {
            // If getMnemonic fails, no wallet exists yet
            print("ℹ️ No existing wallet found: \(error)")
            hasWallet = false
        }
        
        isCheckingWallet = false
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
            
            Text("Checking for wallet...")
                .foregroundStyle(.secondary)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
