//
//  FirstUseView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct FirstUseView_iOS: View {
    let walletState: WalletState
    let onCreateWallet: () -> Void
    let onImportWallet: () -> Void
    let onLinkWallet: () -> Void
    let onDeleteWallet: () -> Void
    
    @Environment(\.openURL) private var openURL
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background video covering entire view
            LoopingVideoPlayer_iOS(videoName: "cover-animation", videoExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
            
            // Delete button in top-right corner
            if walletState == .walletWithoutSeed {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 24, height: 24)
                        }
                        .accessibilityLabel("Delete existing wallet")
                        .buttonStyle(.glass)
                        .controlSize(.regular)
                        .tint(.red)
                        .padding(.top, 45)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
             
            // Content overlaid at bottom
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text("Arké")
                        .font(.system(size: 100, design: .serif))
                        .fontWeight(.regular)
                        .foregroundStyle(Color.arkeGold)
                }
                
                VStack(spacing: 16) {
                    if walletState == .walletWithoutSeed {
                        /*
                        // Show link wallet option when wallet exists on another device
                        Button("Link existing wallet") {
                            onLinkWallet()
                        }
                        .buttonStyle(ArkeButtonStyle(size: .large))
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        */
                        
                        Button {
                            onImportWallet()
                        } label: {
                            Text("Import existing wallet")
                                .font(.system(size: 21, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        //.tint(Color.arkeGold)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    } else {
                        // Standard onboarding options
                        Button {
                            onCreateWallet()
                        } label: {
                            Text("Create wallet")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(Color.arkeDark)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .tint(Color.arkeGold)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                        Button {
                            onImportWallet()
                        } label: {
                            Text("Import wallet")
                                .font(.system(size: 21, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        //.tint(Color.arkeGold)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                    
                }
                .animation(.smooth(duration: 0.5), value: walletState)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 50)
            .frame(maxWidth: .infinity)
        }
        .background(Color.arkeDark)
        .safeAreaPadding([.top, .bottom])
        .confirmationDialog(
            "Delete Wallet",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Wallet", role: .destructive) {
                onDeleteWallet()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the wallet on iCloud. You will not be able to recover it anymore.")
        }
    }
}

#Preview {
    FirstUseView_iOS(
        walletState: .noWallet,
        onCreateWallet: {},
        onImportWallet: {},
        onLinkWallet: {},
        onDeleteWallet: {}
    )
    .frame(width: 600, height: 700)
}
