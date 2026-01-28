//
//  DeleteLocallyConfirmationView.swift
//  Ark wallet prototype
//
//  Created by Assistant on 1/26/26.
//

import SwiftUI

struct DeleteLocallyConfirmationView: View {
    let deletionStrategy: DeletionStrategy
    let onConfirm: () async throws -> Void
    let onBack: () -> Void
    
    @Environment(\.walletDataCleanupService) private var cleanupService
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    var body: some View {
        ZStack {
            // Background image
            Image("wipe-wallet-from-device")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .ignoresSafeArea()
                .overlay {
                    // Gradient overlay for readability
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            
            VStack {
                // Top bar with back button
                HStack {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Cancel")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(.white)
                    }
                    .disabled(isDeleting)
                    
                    Spacer()
                }
                .padding(.horizontal, 25)
                .padding(.top, 20)
                
                Spacer()
                
                // Content area
                VStack(spacing: 25) {
                    VStack(spacing: 15) {
                        Text("Delete from This Device?")
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("This will remove the wallet from this device only. You can restore it later with your recovery phrase.")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                        
                        /*
                        if case .promptForCloudData = deletionStrategy {
                            VStack(spacing: 12) {
                                Label {
                                    Text("iCloud data remains available")
                                        .font(.callout)
                                        .foregroundColor(.white.opacity(0.85))
                                } icon: {
                                    Image(systemName: "icloud")
                                        .foregroundColor(.blue)
                                }
                                
                                Text("Your wallet can be restored on other devices using your recovery phrase or by signing in with this iCloud account.")
                                    .font(.callout)
                                    .foregroundColor(.white.opacity(0.75))
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 15)
                            .padding(.horizontal, 20)
                            .background {
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.blue.opacity(0.2))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                                    }
                            }
                            .padding(.top, 10)
                        }
                         */
                    }
                    
                    // Error display
                    if let deleteError = deleteError {
                        ErrorView(errorMessage: deleteError)
                    }
                    
                    // Show deletion progress
                    if let progress = cleanupService.deletionProgress {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(progress.message)
                                .font(.callout)
                                .foregroundColor(.white.opacity(0.85))
                            
                            ProgressView(value: progress.progressPercentage)
                                .progressViewStyle(.linear)
                                .tint(.orange)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 25)
                
                // Confirm button at bottom
                VStack(spacing: 15) {
                    Button {
                        Task {
                            await performDeletion()
                        }
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }
                            Text(isDeleting ? "Deleting..." : "Delete from This Device")
                                .font(.system(size: 19, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(Color.orange)
                    .disabled(isDeleting)
                    
                    /*
                    Text("You can restore this wallet later with your recovery phrase")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    */
                }
                .padding(.horizontal, 25)
                .padding(.top, 25)
                .padding(.bottom, 30)
            }
        }
    }
    
    private func performDeletion() async {
        isDeleting = true
        deleteError = nil
        
        do {
            try await onConfirm()
            await MainActor.run {
                isDeleting = false
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
    DeleteLocallyConfirmationView(
        deletionStrategy: .promptForCloudData,
        onConfirm: {
            try await Task.sleep(nanoseconds: 2_000_000_000)
        },
        onBack: {}
    )
}
