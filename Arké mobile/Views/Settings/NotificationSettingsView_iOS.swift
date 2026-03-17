//
//  NotificationSettingsView_iOS.swift
//  Arké mobile
//
//  Manages push notification settings
//

import SwiftUI

struct NotificationSettingsView_iOS: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("notifications_enabled")
    private var notificationsEnabled: Bool = false
    
    @State private var isRegistering = false
    @State private var errorMessage: String?
    @State private var apnsTokenStatus: String = "Checking..."
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Notifications")
                            .font(.system(size: 16))
                        Text("Receive alerts when funds arrive in your wallet")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: notificationsEnabled) { oldValue, newValue in
                    if newValue {
                        Task {
                            await registerForNotifications()
                        }
                    } else {
                        Task {
                            await unregisterFromNotifications()
                        }
                    }
                }
            } header: {
                Text("Push Notifications")
            } footer: {
                Text("Notifications are delivered through Apple's Push Notification service and a privacy-preserving relay server.")
            }
            
            // Status Section
            Section {
                HStack {
                    Text("APNs Token Status")
                        .font(.system(size: 14))
                    Spacer()
                    Text(apnsTokenStatus)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
            } header: {
                Text("Status")
            }
            
            // How It Works Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(
                        icon: "shield.fill",
                        color: .blue,
                        title: "Privacy First",
                        description: "The relay server only knows your mailbox ID, not your wallet balance or transactions."
                    )
                    
                    InfoRow(
                        icon: "bolt.fill",
                        color: .orange,
                        title: "Instant Updates",
                        description: "Get notified immediately when someone sends you funds, even when the app is closed."
                    )
                    
                    InfoRow(
                        icon: "network",
                        color: .green,
                        title: "Decentralized",
                        description: "The relay polls the Ark server on your behalf and delivers notifications via APNs."
                    )
                }
                .padding(.vertical, 4)
            } header: {
                Text("How It Works")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            checkAPNsTokenStatus()
        }
    }
    
    // MARK: - Actions
    
    private func registerForNotifications() async {
        isRegistering = true
        errorMessage = nil
        
        do {
            // Request notification permission
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                // Wait a moment for token to be received
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Register with relay
                await walletManager.registerForPushNotifications()
                
                print("✅ Successfully registered for notifications")
            } else {
                errorMessage = "Notification permission denied. Please enable in Settings."
                notificationsEnabled = false
            }
        } catch {
            errorMessage = "Failed to register: \(error.localizedDescription)"
            notificationsEnabled = false
        }
        
        isRegistering = false
        checkAPNsTokenStatus()
    }
    
    private func unregisterFromNotifications() async {
        isRegistering = true
        errorMessage = nil
        
        await walletManager.unregisterFromPushNotifications()
        
        isRegistering = false
        checkAPNsTokenStatus()
    }
    
    private func checkAPNsTokenStatus() {
        if let token = UserDefaults.standard.string(forKey: "apns_device_token"), !token.isEmpty {
            apnsTokenStatus = "✓ Active"
        } else {
            apnsTokenStatus = "Not registered"
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView_iOS()
            .environment(WalletManager(useMock: true))
    }
}
