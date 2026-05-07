import SwiftUI

struct BackupStatusSectionView: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var backupInfo: BackupInfo?
    @State private var isBackingUp = false
    @State private var lastBackupResult: Bool?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("iCloud Backup")
                .font(.headline)
            
            if let info = backupInfo {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Last Backup:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(info.formattedDate)
                    }
                    
                    HStack {
                        Text("Size:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(info.formattedSize)
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
                    }
                    Text(isBackingUp ? "Backing up..." : "Backup Now")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(isBackingUp)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
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
}
