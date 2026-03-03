//
//  OnboardingView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import ArkeUI

struct FirstUseView: View {
    let walletState: WalletState
    let onCreateWallet: () -> Void
    let onImportWallet: () -> Void
    let onLinkWallet: () -> Void
    let onDeleteWallet: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            VStack {
                // Left column - Big video
                 LoopingVideoPlayer(videoName: "cover-animation", videoExtension: "mp4")
                     .frame(maxWidth: .infinity)
                     .clipped()
            }
            .frame(maxWidth: .infinity)
            
            // Right column - Existing content
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text("firstuse_welcome_to", bundle: .module)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("app_name")
                        .font(.system(size: 80, design: .serif))
                        .fontWeight(.regular)
                        .foregroundStyle(Color.Arke.gold)
                    
                    Text("firstuse_welcome_description", bundle: .module)
                        .fontWeight(.light)
                        .font(.system(size: 21))
                        .lineSpacing(6)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                    
                    Text("firstuse_more_about", bundle: .module)
                        .font(.system(size: 17))
                        .padding(.top, 16)
                        .foregroundStyle(Color.Arke.gold)
                        .onTapGesture {
                            if let url = URL(string: "https://second.tech") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    if walletState == .walletWithoutSeed {
                        // Show link wallet option when wallet exists on another device
                        Button("button_link_existing_wallet", bundle: .module) {
                            onLinkWallet()
                        }
                        .buttonStyle(ArkeButtonStyle(size: .large))
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                        Button("button_delete_wallet_data", bundle: .module) {
                            onDeleteWallet()
                        }
                        .buttonStyle(ArkeButtonStyle(size: .large, variant: .outline, color: .Arke.red))
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                    } else {
                        // Standard onboarding options
                        Button("button_create_new_wallet", bundle: .module) {
                            onCreateWallet()
                        }
                        .buttonStyle(ArkeButtonStyle(size: .large))
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                        Button("action_import_wallet") {
                            onImportWallet()
                        }
                        .buttonStyle(ArkeButtonStyle(size: .large, variant: .outline))
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.smooth(duration: 0.5), value: walletState)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
            .frame(maxWidth: .infinity)
        }
        .background(Color.Arke.gold3)
    }
}

#Preview {
    FirstUseView(
        walletState: .noWallet,
        onCreateWallet: {},
        onImportWallet: {},
        onLinkWallet: {},
        onDeleteWallet: {}
    )
    .frame(width: 600, height: 700)
}
