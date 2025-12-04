//
//  DeleteWalletSettingView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/13/25.
//

import SwiftUI

struct DeleteWalletSettingView: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.securityService) private var securityService
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var deletionStrategy: DeletionStrategy?
    @State private var isCheckingDevices = false
    
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
            
            Button(isDeleting ? "Deleting..." : (isCheckingDevices ? "Checking..." : "Delete Wallet")) {
                Task {
                    await checkDevicesAndPromptDeletion()
                }
            }
            .buttonStyle(ArkeButtonStyle(size: .small))
            .disabled(isDeleting || isCheckingDevices)
            .padding(.top, 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog(
            deletionStrategy?.title ?? "Delete Wallet",
            isPresented: $showDeleteConfirmation,
            presenting: deletionStrategy
        ) { strategy in
            switch strategy {
            case .localOnly:
                Button("Delete from This Device", role: .destructive) {
                    Task {
                        await deleteWallet(deleteCloudData: false)
                    }
                }
                Button("Cancel", role: .cancel) { }
                
            case .promptForCloudData:
                Button("Delete Everything", role: .destructive) {
                    Task {
                        await deleteWallet(deleteCloudData: true)
                    }
                }
                Button("Delete Wallet, Keep iCloud Data", role: .destructive) {
                    Task {
                        await deleteWallet(deleteCloudData: false)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        } message: { strategy in
            Text(strategy.message)
        }
    }
    
    private func checkDevicesAndPromptDeletion() async {
        isCheckingDevices = true
        deleteError = nil
        
        do {
            // Get deletion strategy based on other devices
            let strategy = await securityService.getDeletionStrategy()
            
            await MainActor.run {
                deletionStrategy = strategy
                showDeleteConfirmation = true
                isCheckingDevices = false
            }
        } catch {
            await MainActor.run {
                deleteError = "Failed to check devices: \(error.localizedDescription)"
                isCheckingDevices = false
            }
        }
    }
    
    private func deleteWallet(deleteCloudData: Bool) async {
        isDeleting = true
        deleteError = nil
        
        do {
            // Delete from SecurityService with the chosen strategy
            try await securityService.deleteMnemonic(deleteCloudData: deleteCloudData)
            
            // Delete from WalletManager (this clears local wallet data)
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
