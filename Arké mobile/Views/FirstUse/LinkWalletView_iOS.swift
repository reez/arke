//
//  LinkWalletView_iOS.swift
//  Ark wallet prototype
//
//  Created by Christoph on 12/01/25.
//

import SwiftUI
import Combine
import Foundation

struct LinkWalletView_iOS: View {
    let onBack: () -> Void
    let onWalletLinked: () -> Void
    
    @Environment(WalletManager.self) private var walletManager
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLinking = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 30) {
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
                        Text("Link Wallet")
                            .font(.system(size: 40, design: .serif))
                            .foregroundStyle(Color.arkeGold)
                        
                        Text("Connect your existing wallet to this app.")
                            .fontWeight(.light)
                            .font(.system(size: 21))
                            .lineSpacing(6)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.arkeDark)
        .safeAreaPadding([.top, .bottom])
        .alert("Link Error", isPresented: $showingError) {
            Button("OK") { }
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
            print("🔗 Linking wallet...")
            
            // Simulate async work
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
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
    LinkWalletView_iOS(
        onBack: {},
        onWalletLinked: {}
    )
    .environment(WalletManager(useMock: true))
    .frame(width: 600, height: 700)
}
