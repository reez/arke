//
//  LinkWalletView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 12/02/25.
//

import SwiftUI
import Combine
import Foundation
import ArkeUI

struct LinkWalletView: View {
    let onBack: () -> Void
    let onWalletLinked: () -> Void
    
    @Environment(WalletManager.self) private var walletManager
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLinking = false
    
    var body: some View {
        HStack(spacing: 0) {
            VStack {
                // Left column - Big video
                 LoopingVideoPlayer(videoName: "cover-animation", videoExtension: "mp4")
                     .frame(maxWidth: .infinity)
                     .clipped()
            }
            .frame(maxWidth: .infinity)
            
            // Right column - Content
            VStack(spacing: 30) {
                HStack {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.Arke.gold)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    Text("button_link_wallet")
                        .font(.system(size: 40, design: .serif))
                        .foregroundStyle(Color.Arke.gold)
                    
                    Text("A wallet was detected on another device. Enter your recovery phrase to link it to this Mac.")
                        .fontWeight(.light)
                        .font(.system(size: 21))
                        .lineSpacing(6)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(isLinking ? "Linking..." : "Continue") {
                        Task {
                            await linkWallet()
                        }
                    }
                    .buttonStyle(ArkeButtonStyle(size: .large))
                    .disabled(isLinking)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
            .frame(maxWidth: .infinity)
        }
        .background(Color.Arke.gold3)
        .alert("error_link", isPresented: $showingError) {
            Button("button_ok") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func linkWallet() async {
        isLinking = true
        defer { isLinking = false }
        
        // Placeholder implementation
        do {
            // TODO: Implement wallet linking logic
            // This should navigate to ImportWalletView or similar to enter recovery phrase
            print("🔗 Linking wallet...")
            
            // For now, just navigate to wallet linked screen
            // In real implementation, this would:
            // 1. Prompt user for recovery phrase
            // 2. Validate it matches the iCloud wallet hash
            // 3. Store it in keychain
            // 4. Initialize wallet
            
            // Simulate async work
            try await Task.sleep(nanoseconds: 500_000_000)
            
            // Success - call the completion handler
            onWalletLinked()
            
        } catch {
            showError("Failed to link wallet: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

#Preview {
    LinkWalletView(
        onBack: {},
        onWalletLinked: {}
    )
    .environment(WalletManager(useMock: true))
    .frame(width: 600, height: 700)
}
