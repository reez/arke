//
//  FirstUseView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
import ArkeUI

struct FirstUseView_iOS: View {
    let walletState: WalletState
    @Binding var isMainnet: Bool
    let onCreateWallet: () -> Void
    let onImportWallet: () -> Void
    let onLinkWallet: () -> Void
    let onDeleteWallet: () -> Void
    
    @Environment(\.openURL) private var openURL
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background video covering entire view
            LoopingVideoPlayer_iOS(videoName: isMainnet ? "coffee-shop-chat-2": "experimenter-small", videoExtension: "mp4")
                .id(isMainnet)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    // Mainnet toggle in top-left corner
                    Button {
                        withAnimation {
                            isMainnet.toggle()
                        }
                    } label: {
                        Image(systemName: "testtube.2")
                            .frame(width: 24, height: 24)
                    }
                    .accessibilityLabel("Switch nets")
                    .buttonStyle(.glass)
                    .controlSize(.regular)
                    .tint(.Arke.gold)
                    .padding(.top, 60)
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                    // Delete button in top-right corner
                    if walletState == .walletWithoutSeed {
                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 24, height: 24)
                        }
                        .accessibilityLabel("action_delete_existing_wallet")
                        .buttonStyle(.glass)
                        .controlSize(.regular)
                        .tint(.Arke.red)
                        .padding(.top, 60)
                        .padding(.trailing, 20)
                    }
                }
                
                Spacer()
            }
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
             
            // Content overlaid at bottom
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    /*
                    Button {
                        withAnimation {
                            isMainnet.toggle()
                        }
                    } label: {
                        Text("app_name")
                            .font(.system(size: 100, design: .serif))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Arke.gold)
                    }
                    .buttonStyle(.plain)
                    */
                    
                    if !isMainnet {
                        Text("You will create a test wallet.")
                            .font(.system(.title2, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black, radius: 4, x: 0, y: 2)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.smooth(duration: 0.5), value: isMainnet)
                
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
                            Text("action_import_wallet")
                                .font(.system(size: 21, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        //.tint(Color.Arke.gold)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    } else {
                        // Standard onboarding options
                        Button {
                            onCreateWallet()
                        } label: {
                            Text("button_create_wallet")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(Color.Arke.gold3)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .tint(Color.Arke.gold)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                        Button {
                            onImportWallet()
                        } label: {
                            Text("button_import_wallet")
                                .font(.system(size: 21, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        //.tint(Color.Arke.gold)
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
        .colorScheme(.dark)
        .background(Color.Arke.gold3)
        .safeAreaPadding([.top, .bottom])
        .confirmationDialog("button_delete_wallet",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("button_delete_wallet", role: .destructive) {
                onDeleteWallet()
            }
            Button("button_cancel", role: .cancel) {}
        } message: {
            Text("alert_delete_wallet_permanently")
        }
    }
}

#Preview {
    @Previewable @State var isMainnet = false
    
    FirstUseView_iOS(
        walletState: .noWallet,
        isMainnet: $isMainnet,
        onCreateWallet: {},
        onImportWallet: {},
        onLinkWallet: {},
        onDeleteWallet: {}
    )
    .frame(width: 600, height: 700)
}
