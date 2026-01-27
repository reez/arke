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
    @State private var hasAppeared = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen background image
                Image("bitcoin-wallet")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                
                // Bottom-aligned content
                VStack {
                    Spacer()
                    
                    if showGetStartedButton {
                        // State 2: Get Started button
                        VStack(spacing: 30) {
                            Text("It's ready.")
                                .font(.system(size: 30, design: .serif))
                                .foregroundStyle(Color.arkeDark)
                            
                            Button {
                                onWalletCreated()
                            } label: {
                                Text("Let's go")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle(Color.arkeDark)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                            .tint(Color.arkeGold)
                            .accessibilityLabel("Get Started")
                            .accessibilityHint("Continue to your new wallet")
                        }
                        .padding(.horizontal, 20)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    } else {
                        // State 1: Creating wallet spinner
                        VStack(spacing: 35) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.arkeDark))
                                .scaleEffect(3)
                            
                            Text("Creating wallet")
                                .font(.system(size: 30, design: .serif))
                                .foregroundStyle(Color.arkeDark)
                        }
                        .padding(.bottom, 30)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .accessibilityLabel("Creating wallet, please wait")
                    }
                }
                .padding(.bottom, geometry.safeAreaInsets.bottom + 80)
                .frame(width: geometry.size.width)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .task {
            // Wait a bit for the transition to complete before starting wallet creation
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            hasAppeared = true
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
        
        // ✅ NEW: Track retry attempts
        var retryCount = 0
        let maxRetries = 2
        
        // Run wallet creation and minimum delay concurrently
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Create the wallet (with retry logic)
            group.addTask { @MainActor in
                while retryCount <= maxRetries {
                    do {
                        print("🔧 Wallet creation attempt \(retryCount + 1)/\(maxRetries + 1)")
                        
                        // ✅ NEW: Add small delay before retry (not on first attempt)
                        if retryCount > 0 {
                            print("   ⏳ Waiting before retry...")
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        }
                        
                        let result = try await walletManager.createWallet()
                        print("✅ Wallet created: \(result)")
                        walletCreationComplete = true
                        break // Success - exit retry loop
                        
                    } catch {
                        print("❌ Attempt \(retryCount + 1) failed: \(error)")
                        
                        // Check if it's a database error
                        let errorString = error.localizedDescription
                        let isDatabaseError = errorString.contains("bark_properties") ||
                                             errorString.contains("database") ||
                                             errorString.contains("SQL")
                        
                        if isDatabaseError && retryCount < maxRetries {
                            print("💡 Database error detected, will retry after cleanup")
                            retryCount += 1
                            continue // Retry
                        } else {
                            // Non-database error or max retries reached
                            print("❌ Failed to create wallet: \(error)")
                            errorMessage = error.localizedDescription
                            showingError = true
                            break // Exit retry loop
                        }
                    }
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
            withAnimation(.easeInOut(duration: 0.35)) {
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
