//
//  ImportWalletView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/24/25.
//

import SwiftUI
import ArkeUI
import Combine
import Foundation

struct ImportWalletView_iOS: View {
    let onBack: () -> Void
    let onWalletImported: () -> Void
    
    @Environment(WalletManager.self) private var walletManager
    @State private var mnemonicPhrase: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isImporting = false
    
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
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .tint(Color.Arke.gold)
                        .accessibilityLabel("Back")
                        
                        Spacer()
                    }
                    .padding(.top, 10)
                    
                    VStack(spacing: 8) {
                        Text("Import Wallet")
                            .font(.system(size: 36, design: .serif))
                            .foregroundStyle(Color.Arke.gold)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Restore your existing wallet with your 12-word recovery phrase.")
                            .font(.system(size: 21))
                            .lineSpacing(4)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    TextField("Enter your 12-words here...", text: $mnemonicPhrase, axis: .vertical)
                        .padding(15)
                        .background(Color.primary.opacity(0.05))
                        .foregroundStyle(.white)
                        .font(.system(size: 21, design: .monospaced))
                        .lineSpacing(4)
                        .lineLimit(3...5)
                        .cornerRadius(8)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .onChange(of: mnemonicPhrase) { oldValue, newValue in
                            // If user presses return/enter, dismiss keyboard
                            if newValue.contains("\n") || newValue.contains("\r") {
                                hideKeyboard()
                            }
                            // Remove any newlines or line breaks
                            let cleaned = newValue.replacingOccurrences(of: "\n", with: " ")
                                                   .replacingOccurrences(of: "\r", with: " ")
                            if cleaned != newValue {
                                mnemonicPhrase = cleaned
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.Arke.gold.opacity(0.2), lineWidth: 1)
                        )
                        .frame(maxWidth: 400)
                    
                    Spacer(minLength: 10)
                    
                    Button {
                        Task {
                            await importWallet()
                        }
                    } label: {
                        Text(isImporting ? "Importing..." : "Import Wallet")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Color.Arke.gold3)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(Color.Arke.gold)
                    .disabled(mnemonicPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, safeAreaInsets.top)
                .padding(.bottom, safeAreaInsets.bottom)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .colorScheme(.dark)
        .background(Color.Arke.gold3)
        .ignoresSafeArea()
        .alert("Import Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func importWallet() async {
        let trimmedMnemonic = mnemonicPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic validation
        guard !trimmedMnemonic.isEmpty else {
            showError("Please enter a recovery phrase")
            return
        }
        
        isImporting = true
        defer { isImporting = false }
        
        do {
            // Use WalletManager to import the wallet
            let result = try await walletManager.importWallet(mnemonic: trimmedMnemonic)
            print("✅ Wallet imported successfully: \(result)")
            
            // Success - call the completion handler
            onWalletImported()
            
        } catch {
            showError("Failed to import wallet: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    ImportWalletView_iOS(
        onBack: {},
        onWalletImported: {}
    )
    .environment(WalletManager(useMock: true))
    .frame(width: 600, height: 700)
}
