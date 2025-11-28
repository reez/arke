//
//  OnboardingFlow_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

enum OnboardingState {
    case firstUse
    case importWallet
    case walletImported
    case usagePattern
    case selectServer
    case createWallet
    case walletCreated
}

enum NavigationDirection {
    case forward
    case backward
}

struct OnboardingFlow_iOS: View {
    @State private var currentState: OnboardingState = .firstUse
    @State private var navigationDirection: NavigationDirection = .forward
    @Environment(WalletManager.self) private var walletManager
    let onWalletReady: () -> Void
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                VStack {
                    switch currentState {
                    case .firstUse:
                        FirstUseView_iOS(
                            onCreateWallet: {
                                navigationDirection = .forward
                                withAnimation(.smooth(duration: 0.4)) {
                                    currentState = .usagePattern
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
                        Text("Usage pattern")
                        /*
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
                        */
                    case .walletCreated:
                        Text("Usage pattern")
                        /*
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
                         */
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
        onWalletReady: {
            // Preview completion action
        }
    )
    .environment(WalletManager(useMock: true))
}

