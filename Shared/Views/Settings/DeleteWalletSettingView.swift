//
//  DeleteWalletSettingView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/13/25.
//

import SwiftUI

struct DeleteWalletSettingView: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.walletDataCleanupService) private var cleanupService
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var deletionStrategy: DeletionStrategy?
    @State private var isCheckingDevices = false
    @State private var deletionSummary: DeletionSummary?
    
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
            
            // Show deletion progress
            if let progress = cleanupService.deletionProgress {
                VStack(alignment: .leading, spacing: 8) {
                    Text(progress.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: progress.progressPercentage)
                        .progressViewStyle(.linear)
                }
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
                        await deleteWallet(includeCloudData: false)
                    }
                }
                Button("Cancel", role: .cancel) { }
                
            case .promptForCloudData:
                Button("Delete Everything", role: .destructive) {
                    Task {
                        await deleteWallet(includeCloudData: true)
                    }
                }
                Button("Delete Wallet, Keep iCloud Data", role: .destructive) {
                    Task {
                        await deleteWallet(includeCloudData: false)
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
        
        // Get deletion strategy based on other devices
        let strategy = await cleanupService.getDeletionStrategy()
        
        await MainActor.run {
            deletionStrategy = strategy
            showDeleteConfirmation = true
            isCheckingDevices = false
        }
    }
    
    private func deleteWallet(includeCloudData: Bool) async {
        isDeleting = true
        deleteError = nil
        deletionSummary = nil
        
        do {
            // Delete all wallet data using the cleanup service
            let summary = try await cleanupService.deleteWalletData(includeCloudData: includeCloudData)
            
            // Delete from WalletManager (this clears local wallet state from bark)
            _ = try await walletManager.deleteWallet()
            
            // Store summary
            deletionSummary = summary
            
            #if DEBUG
            print("✅ [DeleteWalletSettingView] Deletion complete: \(summary.summaryDescription)")
            #endif
            
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
