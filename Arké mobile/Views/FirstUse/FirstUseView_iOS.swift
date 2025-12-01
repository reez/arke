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
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background video covering entire view
            LoopingVideoPlayer_iOS(videoName: "cover-animation", videoExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
             
            // Content overlaid at bottom
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text("Arké")
                        .font(.system(size: 80, design: .serif))
                        .fontWeight(.regular)
                        .foregroundStyle(Color.arkeGold)
                }
                
                VStack(spacing: 16) {
                    if walletState == .walletWithoutSeed {
                        // Show link wallet option when wallet exists on another device
                        Button("Link existing wallet") {
                            onLinkWallet()
                        }
                        .buttonStyle(ArkeButtonStyle(size: .large))
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    } else {
                        // Standard onboarding options
                        Button("Create new wallet") {
                            onCreateWallet()
                        }
                        .buttonStyle(ArkeButtonStyle(size: .large))
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                        Button("Import existing wallet") {
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
        .background(Color.arkeDark)
        .safeAreaPadding([.top, .bottom])
    }
}

#Preview {
    FirstUseView_iOS(
        walletState: .noWallet,
        onCreateWallet: {},
        onImportWallet: {},
        onLinkWallet: {}
    )
    .frame(width: 600, height: 700)
}
