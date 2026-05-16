//
//  CreateWalletView_iOS.swift
//  Arké
//
//  Created by Assistant on 12/09/25.
//

import SwiftUI
import ArkeUI
import AVFoundation
import OSLog

struct CreateWalletView_iOS: View {
    // MARK: - Logging
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.arke", category: "CreateWalletView")
    
    // MARK: - Properties
    
    let isMainnet: Bool
    let onWalletCreated: () -> Void
    let onBack: () -> Void
    let walletManager: WalletManager
    
    @State private var walletCreationComplete = false
    @State private var walletCreationInProgress = false
    @State private var showGetStartedButton = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var videoComplete = false
    @State private var showImage = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen background video (plays once)
                LoopingVideoPlayer_iOS(
                    videoName: "magic-wallet-creation",
                    videoExtension: "mp4",
                    videoGravity: .resizeAspectFill,
                    autoPlay: true,
                    showErrorIndicator: true,
                    loops: false,
                    onCompletion: {
                        videoComplete = true
                        // Fade in the image after video completes
                        withAnimation(.easeIn(duration: 0.2)) {
                            showImage = true
                        }
                    }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .ignoresSafeArea()
                .accessibilityHidden(true)
                
                // Full-screen background image (fades in after video)
                if showImage {
                    Image("bitcoin-wallet")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
                
                // Bottom-aligned content
                VStack {
                    Spacer()
                    
                    if showGetStartedButton {
                        // Get Started button
                        VStack(spacing: 30) {
                            Text("onboarding_wallet_awaits")
                                .font(.system(size: 30, design: .serif))
                                .foregroundStyle(Color.Arke.gold3)
                            
                            Button {
                                onWalletCreated()
                            } label: {
                                Text("onboarding_step_in")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle(Color.Arke.gold3)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                            .tint(Color.Arke.gold)
                            .accessibilityLabel("button_get_started")
                            .accessibilityHint("Continue to your new wallet")
                        }
                        .padding(.horizontal, 20)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    } else if walletCreationInProgress && videoComplete {
                        // Show loading indicator if video finished but wallet creation still in progress
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.Arke.gold3)
                                .scaleEffect(1.5)
                            
                            Text("Creating your wallet...")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Color.Arke.gold3)
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, geometry.safeAreaInsets.bottom + 80)
                .frame(width: geometry.size.width)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .task {
            // Start wallet creation immediately in parallel with video playback
            Task {
                await startWalletCreation()
            }
        }
        .onChange(of: walletCreationComplete) { _, isComplete in
            // Show button when both video AND wallet creation are complete
            if isComplete && videoComplete {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showGetStartedButton = true
                }
            }
        }
        .onChange(of: videoComplete) { _, isComplete in
            // Show button when both video AND wallet creation are complete
            if isComplete && walletCreationComplete {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showGetStartedButton = true
                }
            }
        }
        .alert("Wallet Creation Failed", isPresented: $showingError) {
            Button("Retry") {
                Task {
                    await startWalletCreation()
                }
            }
            Button("Go Back", role: .cancel) {
                onBack()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    @MainActor
    private func startWalletCreation() async {
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        Self.logger.info("⏱️ [PROFILE] CreateWalletView: Starting wallet creation flow (parallel with video)")
        
        // Reset states
        walletCreationComplete = false
        walletCreationInProgress = true
        showGetStartedButton = false
        showingError = false
        
        // Ensure cancel button and loading indicator can appear
        defer {
            walletCreationInProgress = false
        }
        
        // Track retry attempts
        var retryCount = 0
        let maxRetries = 2
        
        while retryCount <= maxRetries {
            do {
                print("🔧 Wallet creation attempt \(retryCount + 1)/\(maxRetries + 1)")
                print("   Network: \(isMainnet ? "mainnet" : "signet")")
                
                // Add small delay before retry (not on first attempt)
                if retryCount > 0 {
                    print("   ⏳ Waiting before retry...")
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                }
                
                let attemptStartTime = CFAbsoluteTimeGetCurrent()
                
                // Select network configuration based on isMainnet flag
                let networkConfig = isMainnet ? NetworkConfig.mainnet : NetworkConfig.signet
                let result = try await walletManager.createWallet(
                    networkConfig: networkConfig
                )
                
                let attemptTime = CFAbsoluteTimeGetCurrent() - attemptStartTime
                Self.logger.info("⏱️ [PROFILE] Wallet creation attempt took \(String(format: "%.3f", attemptTime))s")
                Self.logger.info("✅ Wallet created on \(networkConfig.name): \(result)")
                
                let totalTime = CFAbsoluteTimeGetCurrent() - overallStartTime
                Self.logger.info("⏱️ [PROFILE] CreateWalletView: Total wallet creation took \(String(format: "%.3f", totalTime))s")
                
                walletCreationComplete = true
                break // Success - exit retry loop
                
            } catch {
                Self.logger.error("❌ Attempt \(retryCount + 1) failed: \(error.localizedDescription)")
                
                let errorString = error.localizedDescription
                
                // Categorize errors for better retry logic
                let isDatabaseError = errorString.contains("bark_properties") ||
                                     errorString.contains("database") ||
                                     errorString.contains("SQL")
                
                let isNetworkError = errorString.contains("network") ||
                                    errorString.contains("connection") ||
                                    errorString.contains("timeout") ||
                                    errorString.contains("timed out") ||
                                    errorString.contains("unreachable") ||
                                    errorString.contains("URLError")
                
                let isServerError = errorString.contains("server") ||
                                   errorString.contains("401") ||
                                   errorString.contains("403") ||
                                   errorString.contains("unauthorized") ||
                                   errorString.contains("forbidden") ||
                                   errorString.contains("access token") ||
                                   errorString.contains("authentication")
                
                // Retry on database or network errors, but not server auth errors
                let shouldRetry = (isDatabaseError || isNetworkError) && retryCount < maxRetries
                
                if shouldRetry {
                    if isDatabaseError {
                        print("💡 Database error detected, will retry after cleanup")
                    } else if isNetworkError {
                        print("💡 Network error detected, will retry")
                    }
                    retryCount += 1
                    continue // Retry
                } else {
                    // Non-retryable error or max retries reached
                    print("❌ Failed to create wallet: \(error)")
                    
                    // Provide more helpful error messages
                    if isServerError {
                        errorMessage = "Unable to connect to the Ark server. This server may require authentication or have restricted access. Please contact the server administrator or try a different server."
                    } else if isNetworkError && retryCount >= maxRetries {
                        errorMessage = "Network connection failed after multiple attempts. Please check your internet connection and try again."
                    } else {
                        errorMessage = errorString
                    }
                    
                    showingError = true
                    break // Exit retry loop
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CreateWalletView_iOS(
        isMainnet: false,
        onWalletCreated: {
            print("Wallet created")
        },
        onBack: {
            print("Back pressed")
        },
        walletManager: WalletManager(useMock: true)
    )
}

#Preview("Dark Mode") {
    CreateWalletView_iOS(
        isMainnet: false,
        onWalletCreated: {},
        onBack: {},
        walletManager: WalletManager(useMock: true)
    )
    .environment(\.colorScheme, .dark)
}
