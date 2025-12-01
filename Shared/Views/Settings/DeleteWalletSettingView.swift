//
//  DeleteWalletSettingView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/13/25.
//

import SwiftUI

struct DeleteWalletSettingView: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    let onWalletDeleted: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Delete wallet")
                .font(.system(size: 24, design: .serif))
            
            Text("This will permanently delete your wallet. Make sure you have your recovery phrase saved.")
                .font(.body)
                .foregroundColor(.secondary)
            
            if let deleteError = deleteError {
                ErrorView(errorMessage: deleteError)
                    .padding(.top, 8)
            }
            
            Button(isDeleting ? "Deleting..." : "Delete Wallet") {
                showDeleteConfirmation = true
            }
            .buttonStyle(ArkeButtonStyle(size: .small))
            .disabled(isDeleting)
            .padding(.top, 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("Delete Wallet", isPresented: $showDeleteConfirmation) {
            Button("Delete Wallet", role: .destructive) {
                Task {
                    await deleteWallet()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete your wallet? This action cannot be undone. Make sure you have your recovery phrase saved.")
        }
    }
    
    private func deleteWallet() async {
        isDeleting = true
        deleteError = nil
        
        do {
            _ = try await walletManager.deleteWallet()
            
            // Call the completion handler to navigate back to onboarding
            await MainActor.run {
                onWalletDeleted?()
            }
        } catch {
            await MainActor.run {
                deleteError = error.localizedDescription
                isDeleting = false
            }
        }
    }
}

#Preview {
    DeleteWalletSettingView(onWalletDeleted: nil)
        .environment(WalletManager(useMock: true))
        .padding()
}
