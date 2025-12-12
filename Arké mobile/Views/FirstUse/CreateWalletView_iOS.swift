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
        ZStack {
            VStack(spacing: 0) {
                // Top navigation area
                HStack {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .tint(Color.arkeGold)
                    .accessibilityLabel("Back")
                    
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.horizontal, 10)
                
                ScrollView {
                    VStack(spacing: 30) {
                        VStack(spacing: 15) {
                            Text("Create New Wallet")
                                .font(.system(size: 36, design: .serif))
                                .foregroundStyle(Color.arkeGold)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("We'll now generate a new wallet and recovery phrase for you.")
                                .fontWeight(.semibold)
                                .font(.system(size: 21))
                                .lineSpacing(4)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Information section
                        VStack(spacing: 16) {
                            Text("It's going to be on signet. Not real bitcoin!")
                                .font(.system(size: 19))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("It will connect to the Ark server by Second.")
                                .font(.system(size: 19))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("This is all alpha and experimental. Play and have fun.")
                                .font(.system(size: 19))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    //.padding(.top, 24)
                    
                    if isCreatingWallet {
                        ProgressView("Creating wallet...")
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.arkeGold))
                            .foregroundStyle(Color.arkeGold)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 0)
                
                Button {
                    Task {
                        await createWallet()
                    }
                } label: {
                    Text(isCreatingWallet ? "Creating..." : "Create Wallet")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.arkeDark)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(Color.arkeGold)
                .disabled(isCreatingWallet)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .padding(.top, safeAreaInsets.top)
            .padding(.bottom, safeAreaInsets.bottom)
        }
        .background(Color.arkeDark)
        .ignoresSafeArea()
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
private struct CreateWalletInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(text)
                .fontWeight(.light)
                .font(.system(size: 19))
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
