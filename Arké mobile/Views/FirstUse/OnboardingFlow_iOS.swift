//
//  OnboardingFlow_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

/*
 
Create wallet sequence
1. firstUse
2. introVideos
3. createWallet
4. walletCreated
 
Import wallet sequence
1. firstUse
2. importWallet
3. walletImported

Link wallet sequence
1. firstUse
2. linkWallet
3. walletLinked
 
 */

import SwiftUI
import Combine

enum OnboardingState {
    case firstUse
    case introVideos
    case importWallet
    case linkWallet
    case walletImported
    case usagePattern
    case selectServer
    case createWallet
    case walletCreated
    case walletLinked
}

enum NavigationDirection {
    case forward
    case backward
}

struct OnboardingFlow_iOS: View {
    @State private var currentState: OnboardingState = .firstUse
    @State private var navigationDirection: NavigationDirection = .forward
    @Environment(WalletManager.self) private var walletManager
    let walletState: WalletState
    let onWalletReady: () -> Void
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                VStack {
                    switch currentState {
                    case .firstUse:
                        FirstUseView_iOS(
                            walletState: walletState,
                            onCreateWallet: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .introVideos
                                }
                            },
                            onImportWallet: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .importWallet
                                }
                            },
                            onLinkWallet: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .linkWallet
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
                        
                    case .introVideos:
                        IntroVideoView_iOS(
                            onBack: {
                                // No previous state to go back to from intro videos
                            },
                            onContinue: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .createWallet
                                }
                            },
                            onSkip: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .firstUse
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
                        .tag("introVideos")
                        
                    case .importWallet:
                        ImportWalletView_iOS(
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
                        
                    case .linkWallet:
                        LinkWalletView_iOS(
                            onBack: {
                                navigationDirection = .backward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .firstUse
                                }
                            },
                            onWalletLinked: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .walletLinked
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
                        .tag("linkWallet")
                        
                    case .walletImported:
                        WalletImportedView_iOS(
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
                        
                    case .usagePattern:
                        Text("Usage pattern")
                        /*
                        UsagePatternView(
                            onBack: {
                                navigationDirection = .backward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .firstUse
                                }
                            },
                            onContinue: { profile in
                                usagePattern = profile
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .selectServer
                                }
                            },
                            usagePattern: usagePattern
                        )
                        .transition(.asymmetric(
                            insertion: navigationDirection == .forward ?
                                .move(edge: .trailing).combined(with: .opacity) :
                                    .move(edge: .leading).combined(with: .opacity),
                            removal: navigationDirection == .forward ?
                                .move(edge: .leading).combined(with: .opacity) :
                                    .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .tag("usagePattern")
                        */
                    case .selectServer:
                        Text("Usage pattern")
                        /*
                        ServerSelectionView(
                            onBack: { profile in
                                usagePattern = profile
                                navigationDirection = .backward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .usagePattern
                                }
                            },
                            onServerSelected: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .createWallet
                                }
                            },
                            usagePattern: usagePattern
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
                        */
                    case .createWallet:
                        CreateWalletView_iOS(
                            onBack: {
                                navigationDirection = .backward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .firstUse
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
                        WalletCreatedView_iOS(
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
                        
                    case .walletLinked:
                        WalletLinkedView_iOS(
                            onContinue: {
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
                        .tag("walletLinked")
                    }
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }
        }
        .background(Color.arkeDark)
        .clipped() // Prevents views from showing outside bounds during transition
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingFlow_iOS(
        walletState: .noWallet,
        onWalletReady: {
            // Preview completion action
        }
    )
    .environment(WalletManager(useMock: true))
}

