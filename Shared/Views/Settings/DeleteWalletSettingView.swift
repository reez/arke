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
    @State private var showLocalDeleteConfirmation = false
    @State private var showCompleteDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var deletionStrategy: DeletionStrategy?
    @State private var isCheckingDevices = true
    @State private var deletionSummary: DeletionSummary?
    
    let onWalletDeleted: (() -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Image("delete-wallet")
                    .resizable()
                    .aspectRatio(800/500, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Delete wallet")
                        .font(.system(.title, design: .serif))
                    
                    Text("You have two options here. If you remove the wallet from this device, it can be restored with your recovery phrase. If you delete permanently, then it's gone forever. Choose wisely.")
                        .font(.title3)
                        .lineSpacing(6)
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
                    
                    // Show device status
                    if isCheckingDevices {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Checking for other devices...")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    } else if let strategy = deletionStrategy {
                        // Device status info
                        VStack(alignment: .leading, spacing: 30) {
                            // Deletion options
                            VStack(alignment: .leading, spacing: 30) {
                                // Delete from This Device button
                                VStack(alignment: .leading, spacing: 15) {
                                    Button {
                                        showLocalDeleteConfirmation = true
                                    } label: {
                                        Text(isDeleting ? "Deleting..." : "Delete from This Device")
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundStyle(Color.white)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.glassProminent)
                                    .controlSize(.large)
                                    .tint(Color.orange)
                                    .disabled(isDeleting)
                                    
                                    if case .promptForCloudData = strategy {
                                        Text("Removes wallet from this device only. iCloud data remains available for other devices.")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                
                                // Delete Everything button
                                VStack(alignment: .leading, spacing: 15) {
                                    Button {
                                        showCompleteDeleteConfirmation = true
                                    } label: {
                                        Text(isDeleting ? "Deleting..." : "Delete Permanently")
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundStyle(Color.white)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.glassProminent)
                                    .controlSize(.large)
                                    .tint(Color.red)
                                    .disabled(isDeleting)
                                    
                                    if case .promptForCloudData = strategy {
                                        Text("Permanently deletes all wallet data from this device AND iCloud. This affects all devices using this wallet.")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        Text("Permanently deletes all wallet data from this device.")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(.top, 8)
                            
                            if case .promptForCloudData = strategy {
                                Label {
                                    Text("This wallet is synced with iCloud")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                } icon: {
                                    Image(systemName: "icloud")
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .task {
            await checkDevices()
        }
        .confirmationDialog(
            "Delete from This Device?",
            isPresented: $showLocalDeleteConfirmation
        ) {
            Button("Delete from This Device", role: .destructive) {
                Task {
                    await deleteWallet(includeCloudData: false)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if case .promptForCloudData = deletionStrategy {
                Text("This will remove the wallet from this device only. Your iCloud data will remain available for other devices.")
            } else {
                Text("This will remove the wallet from this device.")
            }
        }
        .confirmationDialog(
            "Delete Everything?",
            isPresented: $showCompleteDeleteConfirmation
        ) {
            Button("Delete Everything", role: .destructive) {
                Task {
                    await deleteWallet(includeCloudData: true)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if case .promptForCloudData = deletionStrategy {
                Text("This will permanently delete ALL wallet data from this device AND iCloud. All devices using this wallet will lose access. This cannot be undone.")
            } else {
                Text("This will permanently delete all wallet data from this device. This cannot be undone.")
            }
        }
    }
    
    private func checkDevices() async {
        isCheckingDevices = true
        deleteError = nil
        
        // Get deletion strategy based on other devices
        let strategy = await cleanupService.getDeletionStrategy()
        
        await MainActor.run {
            deletionStrategy = strategy
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
