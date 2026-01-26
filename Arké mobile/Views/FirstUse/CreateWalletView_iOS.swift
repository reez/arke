//
//  CreateWalletView_iOS.swift
//  Arké
//
//  Created by Assistant on 12/09/25.
//

import SwiftUI

struct CreateWalletView_iOS: View {
    let onWalletCreated: () -> Void
    let walletManager: WalletManager
    
    @State private var walletCreationComplete = false
    @State private var minimumDelayComplete = false
    @State private var showGetStartedButton = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Full-screen background image
            Image("bitcoin-wallet")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            // Bottom-aligned content
            VStack {
                Spacer()
                
                if showGetStartedButton {
                    // State 2: Get Started button
                    Button {
                        onWalletCreated()
                    } label: {
                        Text("Get Started")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Color.arkeDark)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(Color.arkeGold)
                    .padding(.horizontal, 20)
                    .transition(.opacity)
                    .accessibilityLabel("Get Started")
                    .accessibilityHint("Continue to your new wallet")
                } else {
                    // State 1: Creating wallet spinner
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.arkeGold))
                            .scaleEffect(1.2)
                        
                        Text("Creating wallet")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Color.arkeGold)
                    }
                    .transition(.opacity)
                    .accessibilityLabel("Creating wallet, please wait")
                }
            }
            .padding(.bottom, safeAreaInsets.bottom + 80)
        }
        .ignoresSafeArea()
        .task {
            await startWalletCreation()
        }
        .alert("Creation Error", isPresented: $showingError) {
            Button("Retry") {
                Task {
                    await startWalletCreation()
                }
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    @MainActor
    private func startWalletCreation() async {
        // Reset states
        walletCreationComplete = false
        minimumDelayComplete = false
        showGetStartedButton = false
        
        // Run wallet creation and minimum delay concurrently
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Create the wallet
            group.addTask { @MainActor in
                do {
                    let result = try await walletManager.createWallet()
                    print("✅ Wallet created: \(result)")
                    walletCreationComplete = true
                } catch {
                    print("❌ Failed to create wallet: \(error)")
                    errorMessage = "Failed to create wallet: \(error.localizedDescription)"
                    showingError = true
                }
            }
            
            // Task 2: Minimum 3-second delay
            group.addTask { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                minimumDelayComplete = true
            }
            
            // Wait for both tasks to complete
            await group.waitForAll()
        }
        
        // Only show button if wallet creation succeeded
        if walletCreationComplete {
            withAnimation(.easeInOut(duration: 0.5)) {
                showGetStartedButton = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CreateWalletView_iOS(
        onWalletCreated: {
            print("Wallet created")
        },
        walletManager: WalletManager(useMock: true)
    )
}

#Preview("Dark Mode") {
    CreateWalletView_iOS(
        onWalletCreated: {},
        walletManager: WalletManager(useMock: true)
    )
    .environment(\.colorScheme, .dark)
}
