//
//  RecoveryPhraseSettingView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/13/25.
//

import SwiftUI

struct RecoveryPhraseSettingView: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var mnemonic: String = ""
    @State private var isLoadingMnemonic = false
    @State private var showMnemonic = false
    @State private var errorMessage: String?
    @State private var showCopiedFeedback = false
    @State private var showingQRCode = false
    @State private var revealAllWords = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recovery Phrase")
                .font(.system(.title, design: .serif))
            
            Text("Your recovery phrase is used to restore your wallet. Keep it safe and never share it.")
                .font(.title3)
                .foregroundColor(.secondary)
                .lineSpacing(6)
            
            if showMnemonic {
                if isLoadingMnemonic {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if !mnemonic.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        #if os(iOS)
                        Text("Scratch to reveal.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        ScratchableMnemonicGrid_iOS(
                            mnemonic: mnemonic,
                            revealAll: $revealAllWords
                        )
                        #else
                        MnemonicGrid(mnemonic: mnemonic)
                        #endif
                        
                        #if os(iOS)
                        if !revealAllWords {
                            Button {
                                revealAllWords = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "eye")
                                        .foregroundStyle(Color.arkeDarker)
                                    Text("Reveal All Words")
                                        .foregroundStyle(Color.arkeDarker)
                                }
                            }
                            .buttonStyle(.glass)
                            .controlSize(.regular)
                            .tint(Color.arkeGold)
                        }
                        #endif
                        
                        Button(action: {
                            copyToClipboard(mnemonic)
                            showCopiedFeedback = true
                            
                            // Hide feedback after 2 seconds
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                await MainActor.run {
                                    showCopiedFeedback = false
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                if showCopiedFeedback {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Image(systemName: "doc.on.clipboard")
                                        .foregroundStyle(Color.arkeDarker)
                                }
                                
                                Text(showCopiedFeedback ? "Copied!" : "Copy to Clipboard")
                                    .foregroundColor(showCopiedFeedback ? .green : .arkeDarker)
                            }
                        }
                        .buttonStyle(.glass)
                        .controlSize(.regular)
                        .tint(Color.arkeGold)
                        .animation(.easeInOut(duration: 0.3), value: showCopiedFeedback)
                        
                        Button(action: {
                            showingQRCode = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "qrcode")
                                    .foregroundStyle(Color.arkeDarker)
                                Text("Show as QR Code")
                                    .foregroundStyle(Color.arkeDarker)
                            }
                        }
                        .buttonStyle(.glass)
                        .controlSize(.regular)
                        .tint(Color.arkeGold)
                    }
                    .padding(.top, 15)
                } else if let error = errorMessage {
                    ErrorView(errorMessage: error)
                }
            } else {
                #if os(iOS)
                // On iOS, show scratchable mnemonic immediately
                #else
                Button {
                    Task {
                        await loadMnemonic()
                    }
                } label: {
                    Text("Show Recovery Phrase")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.arkeDark)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
                .tint(Color.arkeGold)
                .padding(.top, 15)
                #endif
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(iOS)
        .task {
            // On iOS, load mnemonic automatically for scratchable view
            if mnemonic.isEmpty {
                await loadMnemonic()
            }
        }
        #endif
        .onDisappear {
            // Reset scratch state when navigating away
            revealAllWords = false
        }
        .sheet(isPresented: $showingQRCode) {
            qrCodeSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    @ViewBuilder
    private var qrCodeSheet: some View {
        if !mnemonic.isEmpty {
            QRCodeView(
                content: mnemonic,
                title: "Recovery Phrase",
                onClose: { showingQRCode = false }
            )
            #if os(macOS)
            .frame(minWidth: 300, minHeight: 300)
            #endif
        }
    }
    
    private func loadMnemonic() async {
        isLoadingMnemonic = true
        errorMessage = nil
        
        do {
            let recoveryPhrase = try await walletManager.getMnemonic()
            await MainActor.run {
                mnemonic = recoveryPhrase
                showMnemonic = true
                isLoadingMnemonic = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoadingMnemonic = false
            }
        }
    }
}

// MARK: - Mnemonic Grid (Shared)

struct MnemonicGrid: View {
    let mnemonic: String
    let cornerRadius: CGFloat = 12.0
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
            ForEach(Array(mnemonic.components(separatedBy: " ").enumerated()), id: \.offset) { index, word in
                HStack(spacing: 4) {
                    Text("\(index + 1)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    
                    Text(word)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(.background)
                .cornerRadius(100)
            }
        }
        .padding()
        .background(Color(white: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    RecoveryPhraseSettingView()
        .environment(WalletManager(useMock: true))
        .padding()
}
