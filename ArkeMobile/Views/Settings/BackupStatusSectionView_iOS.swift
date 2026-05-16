import SwiftUI
import ArkeUI

struct BackupStatusSectionView_iOS: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var backupInfo: BackupInfo?
    @State private var isBackingUp = false
    @State private var lastBackupResult: Bool?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Your payments balance and history. This data exists only on your device and in iCloud. Without it, these funds cannot be recovered, even with your recovery phrase. Download a copy if you back up outside Arké or don't use iCloud.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let info = backupInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Last synced to iCloud")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(info.formattedDate)
                                .font(.body)
                        }
                        
                        HStack {
                            Text("Size")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(info.formattedSize)
                                .font(.body)
                        }
                        
                        if let result = lastBackupResult {
                            HStack {
                                Image(systemName: result ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(result ? .green : .red)
                                Text(result ? "Backup successful" : "Backup failed")
                                    .foregroundColor(result ? .green : .red)
                            }
                            .font(.caption)
                        }
                    }
                    .font(.subheadline)
                } else {
                    Text("No backup available")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                
                VStack(spacing: 20) {
                    Button(action: {
                        exportBackupFile()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.Arke.gold3)
                            Text("Download")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(Color.Arke.gold3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                    .disabled(backupInfo == nil)
                    
                    Button(action: {
                        Task {
                            await performManualBackup()
                        }
                    }) {
                        HStack {
                            if isBackingUp {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise.icloud")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.Arke.gold3)
                            }
                            Text(isBackingUp ? "Syncing..." : "Sync to iCloud now")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(Color.Arke.gold3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                    .disabled(isBackingUp)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Payments State File")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadBackupInfo()
        }
    }
    
    private func loadBackupInfo() async {
        guard let barkWallet = walletManager.wallet as? BarkWalletFFI else { return }
        backupInfo = await barkWallet.getBackupInfo()
    }
    
    private func performManualBackup() async {
        guard let barkWallet = walletManager.wallet as? BarkWalletFFI else { return }
        
        isBackingUp = true
        lastBackupResult = nil
        
        let success = await barkWallet.backupWallet()
        
        lastBackupResult = success
        isBackingUp = false
        
        // Refresh backup info after backup
        await loadBackupInfo()
        
        // Clear the success/failure message after 3 seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            lastBackupResult = nil
        }
    }
    
    private func exportBackupFile() {
        guard let barkWallet = walletManager.wallet as? BarkWalletFFI else { return }
        
        if let url = barkWallet.getShareableBackupFileURL() {
            ShareHelper.share(items: [url])
        }
    }
}
