//
//  VTXODeveloperActionsView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/14/25.
//

import SwiftUI

struct VTXODeveloperActionsView: View {
    let vtxo: VTXOModel
    
    @Environment(WalletManager.self) private var walletManager
    
    @State private var isRefreshing = false
    @State private var isExiting = false
    @State private var refreshResult: String?
    @State private var refreshError: String?
    @State private var exitResult: String?
    @State private var exitError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 15) {
                // Refresh Button
                Button {
                    Task {
                        await handleRefresh()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshing || isExiting)
                
                // Exit Button
                Button {
                    Task {
                        await handleExit()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isExiting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Exit")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshing || isExiting)
            }
            
            // Refresh Error
            if let refreshError = refreshError {
                ErrorView(
                    errorMessage: refreshError,
                    onRetry: {
                        Task {
                            await handleRefresh()
                        }
                    },
                    onDismiss: {
                        self.refreshError = nil
                    }
                )
            }
            
            // Refresh Result
            if let refreshResult = refreshResult {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Refresh Successful")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text(refreshResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                        
                        Text("Note: This VTXO may no longer exist. Make sure to manually refresh the VTXO list on the left.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        self.refreshResult = nil
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.05))
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Exit Error
            if let exitError = exitError {
                ErrorView(
                    errorMessage: exitError,
                    onRetry: {
                        Task {
                            await handleExit()
                        }
                    },
                    onDismiss: {
                        self.exitError = nil
                    }
                )
            }
            
            // Exit Result
            if let exitResult = exitResult {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exit Successful")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text(exitResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                        
                        Text("Note: This VTXO may no longer exist. Make sure to manually refresh the VTXO list on the left.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        self.exitResult = nil
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.05))
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleRefresh() async {
        isRefreshing = true
        // Clear previous results
        refreshResult = nil
        refreshError = nil
        
        defer { isRefreshing = false }
        
        do {
            let result = try await walletManager.refreshVTXO(vtxo_id: vtxo.id)
            print("✅ Successfully refreshed VTXO: \(vtxo.id)")
            print("   Result: \(result)")
            refreshResult = "\(result)"
        } catch {
            print("❌ Failed to refresh VTXO: \(error)")
            refreshError = "Failed to refresh VTXO: \(error.localizedDescription)"
        }
    }
    
    private func handleExit() async {
        isExiting = true
        // Clear previous results
        exitResult = nil
        exitError = nil
        
        defer { isExiting = false }
        
        do {
            let result = try await walletManager.exitVTXO(vtxoId: vtxo.id, to: walletManager.onchainAddress)
            print("✅ Successfully exited VTXO: \(vtxo.id)")
            print("   Result: \(result)")
            exitResult = "\(result)"
        } catch {
            print("❌ Failed to exit VTXO: \(error)")
            exitError = "Failed to exit VTXO: \(error.localizedDescription)"
        }
    }
}

#Preview {
    HStack {
        VTXODeveloperActionsView(vtxo: VTXOModel.mockVTXOs()[0])
    }
    .padding()
    .environment(WalletManager(useMock: true))
}
