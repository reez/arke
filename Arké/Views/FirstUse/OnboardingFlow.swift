//
//  OnboardingFlow.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/24/25.
//

import SwiftUI

enum OnboardingState {
    case firstUse
    case importWallet
    case walletImported
    case selectServer
    case createWallet
    case walletCreated
}

enum NavigationDirection {
    case forward
    case backward
}

struct OnboardingFlow: View {
    @State private var currentState: OnboardingState = .firstUse
    @State private var navigationDirection: NavigationDirection = .forward
    @Environment(WalletManager.self) private var walletManager
    let onWalletReady: () -> Void
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                VStack {
                    // Left column - Big video
                     LoopingVideoPlayer(videoName: "cover-animation", videoExtension: "mp4")
                         .frame(maxWidth: .infinity)
                         .clipped()
                }
                .frame(maxWidth: .infinity)
                VStack {
                    switch currentState {
                    case .firstUse:
                        FirstUseView(
                            onCreateWallet: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .selectServer
                                }
                            },
                            onImportWallet: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .importWallet
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: navigationDirection == .forward ?
                                .move(edge: .trailing).combined(with: .opacity) :
                                    .move(edge: .leading).combined(with: .opacity),
                            removal: navigationDirection == .forward ?
                                .move(edge: .leading).combined(with: .opacity) :
                                    .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .tag("firstUse")
                        
                    case .importWallet:
                        ImportWalletView(
                            onBack: {
                                navigationDirection = .backward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .firstUse
                                }
                            },
                            onWalletImported: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .walletImported
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: navigationDirection == .forward ?
                                .move(edge: .trailing).combined(with: .opacity) :
                                    .move(edge: .leading).combined(with: .opacity),
                            removal: navigationDirection == .forward ?
                                .move(edge: .leading).combined(with: .opacity) :
                                    .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .tag("importWallet")
                        
                    case .walletImported:
                        WalletImportedView(
                            onContinue: {
                                onWalletReady()
                            },
                            onBackupReminder: {
                                // TODO: Navigate to backup reminder view
                                // For now, we'll just continue to the main wallet
                                onWalletReady()
                            }
                        )
                        .transition(.asymmetric(
                            insertion: navigationDirection == .forward ?
                                .move(edge: .trailing).combined(with: .opacity) :
                                    .move(edge: .leading).combined(with: .opacity),
                            removal: navigationDirection == .forward ?
                                .move(edge: .leading).combined(with: .opacity) :
                                    .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .tag("walletImported")
                        
                    case .selectServer:
                        ServerSelectionView(
                            onBack: {
                                navigationDirection = .backward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .firstUse
                                }
                            },
                            onServerSelected: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .createWallet
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: navigationDirection == .forward ?
                                .move(edge: .trailing).combined(with: .opacity) :
                                    .move(edge: .leading).combined(with: .opacity),
                            removal: navigationDirection == .forward ?
                                .move(edge: .leading).combined(with: .opacity) :
                                    .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .tag("selectServer")
                        
                    case .createWallet:
                        CreateWalletView(
                            onBack: {
                                navigationDirection = .backward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .selectServer
                                }
                            },
                            onWalletCreated: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .walletCreated
                                }
                            },
                            walletManager: walletManager
                        )
                        .transition(.asymmetric(
                            insertion: navigationDirection == .forward ?
                                .move(edge: .trailing).combined(with: .opacity) :
                                    .move(edge: .leading).combined(with: .opacity),
                            removal: navigationDirection == .forward ?
                                .move(edge: .leading).combined(with: .opacity) :
                                    .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .tag("createWallet")
                        
                    case .walletCreated:
                        WalletCreatedView(
                            onContinue: {
                                onWalletReady()
                            },
                            onShowRecoveryPhrase: {
                                // TODO: Navigate to recovery phrase view
                                // For now, we'll just continue to the main wallet
                                onWalletReady()
                            }
                        )
                        .transition(.asymmetric(
                            insertion: navigationDirection == .forward ?
                                .move(edge: .trailing).combined(with: .opacity) :
                                    .move(edge: .leading).combined(with: .opacity),
                            removal: navigationDirection == .forward ?
                                .move(edge: .leading).combined(with: .opacity) :
                                    .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .tag("walletCreated")
                    }
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }
        }
        .background(Color.arkeDark)
        .clipped() // Prevents views from showing outside bounds during transition
    }
}

#Preview {
    OnboardingFlow(
        onWalletReady: {
            // Preview completion action
        }
    )
    .environment(WalletManager(useMock: true))
    .frame(width: 600, height: 700)
}
