//
//  FaucetModalView_iOS.swift
//  Arké
//
//  Created by Christoph on 01/21/26.
//

import SwiftUI

struct FaucetModalView_iOS: View {
    @Environment(WalletManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    @State private var showCopiedConfirmation = false
    
    private let faucetURL = "https://signet257.bublina.eu.org/"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero Section
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "drop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.arkeGold)
                        
                        Text("Get free bitcoin for testing")
                            .font(.system(size: 28, design: .serif))
                        
                        Text("Arké runs on a test network called signet, where bitcoins don't have any value and you can get some for free.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Follow these steps")
                            .font(.headline)
                        
                        FaucetInstructionRow(
                            number: 1,
                            text: "Copy your address below"
                        )
                        
                        FaucetInstructionRow(
                            number: 2,
                            text: "Visit the signet faucet website"
                        )
                        
                        FaucetInstructionRow(
                            number: 3,
                            text: "Paste your address and request coins"
                        )
                        
                        FaucetInstructionRow(
                            number: 4,
                            text: "Wait a few minutes for confirmation"
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Address Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Address")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        if !manager.onchainAddress.isEmpty {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(manager.onchainAddress)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                }
                                
                                Spacer()
                                
                                Button {
                                    copyAddress()
                                } label: {
                                    Image(systemName: showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(showCopiedConfirmation ? .green : .arkeGold)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading address...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Faucet Button
                    Button {
                        if let url = URL(string: faucetURL) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "safari")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.arkeDark)
                            Text("Open Faucet Website")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(Color.arkeDark)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(Color.arkeGold)
                    
                    // Note
                    Text("Note that faucets have rate limits. You may need to wait between requests. Don't drain them. Return coins when you're done testing.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 24))
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private func copyAddress() {
        UIPasteboard.general.string = manager.onchainAddress
        
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Show confirmation
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopiedConfirmation = true
        }
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedConfirmation = false
            }
        }
    }
}

// MARK: - Instruction Row Component
private struct FaucetInstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.arkeDark)
                .frame(width: 24, height: 24)
                .background(Color.arkeGold)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    FaucetModalView_iOS()
        .environment(walletManager)
        .task {
            await walletManager.initialize()
        }
}

#Preview("No Address") {
    @Previewable @State var walletManager = WalletManager(useMock: false)
    
    FaucetModalView_iOS()
        .environment(walletManager)
}
