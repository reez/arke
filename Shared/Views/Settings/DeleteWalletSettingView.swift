//
//  DeleteWalletSettingView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/13/25.
//

import SwiftUI
import ArkeUI

enum DeletionType: Identifiable {
    case local
    case permanent
    
    var id: String {
        switch self {
        case .local: return "local"
        case .permanent: return "permanent"
        }
    }
}

struct DeleteWalletSettingView: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.walletDataCleanupService) private var cleanupService
    @State private var showingDeletionView: DeletionType?
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var deletionStrategy: DeletionStrategy?
    @State private var isCheckingDevices = true
    @State private var deletionSummary: DeletionSummary?
    
    let onWalletDeleted: (() -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                /*
                Image("delete-wallet")
                    .resizable()
                    .aspectRatio(800/500, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                 */
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("action_delete_wallet")
                        .font(.system(.title, design: .serif))
                    
                    Text("You have two options. Delete with the option to recover? Or delete forever? Choose wisely.")
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
                                        showingDeletionView = .local
                                    } label: {
                                        HStack {
                                            Text("button_delete_from_device")
                                                .font(.system(size: 17, weight: .semibold))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                        }
                                        .foregroundStyle(Color.white)
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.glassProminent)
                                    .controlSize(.regular)
                                    .tint(Color.Arke.orange)
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
                                        showingDeletionView = .permanent
                                    } label: {
                                        HStack {
                                            Text("button_delete_permanently")
                                                .font(.system(size: 17, weight: .semibold))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                        }
                                        .foregroundStyle(Color.white)
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.glassProminent)
                                    .controlSize(.regular)
                                    .tint(Color.Arke.red)
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
                            .padding(.top, 15)
                            
                            /*
                            if case .promptForCloudData = strategy {
                                Label {
                                    Text("This wallet is synced with iCloud")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                } icon: {
                                    Image(systemName: "icloud")
                                        .foregroundColor(.Arke.blue)
                                }
                                .padding(.vertical, 8)
                            }
                            */
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
        .fullScreenCover(item: $showingDeletionView) { deletionType in
            switch deletionType {
            case .local:
                if let strategy = deletionStrategy {
                    DeleteLocallyConfirmationView(
                        deletionStrategy: strategy,
                        onConfirm: {
                            await deleteWallet(includeCloudData: false)
                        },
                        onBack: {
                            showingDeletionView = nil
                        }
                    )
                }
            case .permanent:
                if let strategy = deletionStrategy {
                    DeletePermanentlyConfirmationView(
                        deletionStrategy: strategy,
                        onConfirm: {
                            await deleteWallet(includeCloudData: true)
                        },
                        onBack: {
                            showingDeletionView = nil
                        }
                    )
                }
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
