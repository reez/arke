//
//  DataView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum VTXOError: Error, LocalizedError {
    case walletNotAvailable
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .walletNotAvailable:
            return "Wallet not available"
        case .parsingFailed:
            return "Failed to parse VTXO data"
        }
    }
}

struct DataView: View {
    @Binding var selectedDataItem: DataDetailItem?
    @Environment(WalletManager.self) private var walletManager
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showingExportSuccess = false
    @State private var isSyncing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                ArkBalanceView()
                
                OnchainBalanceView()
                
                VTXOListView(selectedDataItem: $selectedDataItem)
                
                UTXOListView(selectedDataItem: $selectedDataItem)
                
                ConfigurationSectionView()
                
                ArkInfoSectionView()
                
                BlockHeightSectionView()
            }
            .padding(.vertical, 20)
            .navigationTitle("nav_title_wallet_indepth", bundle: .module)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await syncWallet()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("button_sync", bundle: .module)
                        }
                    }
                    .disabled(isSyncing)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await exportWalletData()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Text("button_download", bundle: .module)
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .alert("alert_export_error", bundle: .module, isPresented: .constant(exportError != nil)) {
                Button("button_ok") {
                    exportError = nil
                }
            } message: {
                Text(exportError ?? "")
            }
            .alert("alert_export_successful", bundle: .module, isPresented: $showingExportSuccess) {
                Button("button_ok") { }
            } message: {
                Text("alert_wallet_data_saved", bundle: .module)
            }
        }
    }
    
    @MainActor
    private func syncWallet() async {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            try await walletManager.sync()
        } catch {
            // Sync errors are handled silently or could be displayed
            print("Sync error: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func exportWalletData() async {
        isExporting = true
        defer { isExporting = false }
        
        do {
            let jsonData = try await walletManager.exportWalletData()
            
            let savePanel = NSSavePanel()
            savePanel.title = "Export Wallet Data"
            savePanel.nameFieldStringValue = "wallet-data-\(DateFormatter.filenameDateFormatter.string(from: Date())).json"
            savePanel.allowedContentTypes = [.json]
            savePanel.canCreateDirectories = true
            
            let response = savePanel.runModal()
            
            if response == .OK, let url = savePanel.url {
                try jsonData.write(to: url)
                showingExportSuccess = true
            }
        } catch {
            exportError = "Failed to export wallet data: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        DataView(selectedDataItem: .constant(nil))
            .environment(WalletManager(useMock: true))
    }
    .frame(width: 400, height: 800)
}

// MARK: - Extensions
extension DateFormatter {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}
