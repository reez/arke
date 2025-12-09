//
//  CreateWalletView_iOS.swift
//  Arké
//
//  Created by Assistant on 12/09/25.
//

import SwiftUI

struct CreateWalletView_iOS: View {
    let onBack: () -> Void
    let onWalletCreated: () -> Void
    let walletManager: WalletManager
    
    @State private var isCreatingWallet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    // Top navigation area
                    HStack {
                        Button {
                            onBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.arkeGold)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        Text("Create New Wallet")
                            .font(.system(size: 36, design: .serif))
                            .foregroundStyle(Color.arkeGold)
                            .multilineTextAlignment(.center)
                        
                        Text("We'll now generate a new wallet and recovery phrase for you.")
                            .fontWeight(.light)
                            .font(.system(size: 19))
                            .lineSpacing(4)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 8)
                    
                    // Information section
                    VStack(spacing: 16) {
                        InfoRow(
                            icon: "network",
                            text: "It's going to be on signet. Not real bitcoin!"
                        )
                        
                        InfoRow(
                            icon: "server.rack",
                            text: "It will connect to the Ark Service Provider by second.tech."
                        )
                        
                        InfoRow(
                            icon: "flask",
                            text: "This is all alpha and experimental. Play and have fun."
                        )
                    }
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        Button(isCreatingWallet ? "Creating..." : "Create Wallet") {
                            Task {
                                await createWallet()
                            }
                        }
                        .buttonStyle(ArkeButtonStyle(size: .large, isLoading: isCreatingWallet))
                        .disabled(isCreatingWallet)
                        
                        if isCreatingWallet {
                            ProgressView("Creating wallet...")
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.arkeGold))
                                .foregroundStyle(Color.arkeGold)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.arkeDark)
        .safeAreaPadding([.top, .bottom])
        .padding(.top, 20)
        .alert("Creation Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    private func createWallet() async {
        isCreatingWallet = true
        
        do {
            let result = try await walletManager.createWallet()
            print("✅ Wallet created: \(result)")
            
            // Success - call the completion handler
            onWalletCreated()
            
        } catch {
            print("❌ Failed to create wallet: \(error)")
            showError("Failed to create wallet: \(error.localizedDescription)")
        }
        
        isCreatingWallet = false
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - Supporting Views

/// iOS-specific info row component
private struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.arkeGold.opacity(0.8))
                .frame(width: 24, alignment: .center)
            
            Text(text)
                .fontWeight(.light)
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Preview

#Preview {
    CreateWalletView_iOS(
        onBack: {
            print("Back tapped")
        },
        onWalletCreated: {
            print("Wallet created")
        },
        walletManager: WalletManager(useMock: true)
    )
}

#Preview("Dark Mode") {
    CreateWalletView_iOS(
        onBack: {},
        onWalletCreated: {},
        walletManager: WalletManager(useMock: true)
    )
    .environment(\.colorScheme, .dark)
}
