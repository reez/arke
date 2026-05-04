//
//  WalletManager+Notifications.swift
//  Arké
//
//  Push notification registration and handling (iOS only)
//  Registers device with relay server for mailbox update notifications via APNs
//

import Foundation

#if os(iOS)
extension WalletManager {
    
    // MARK: - Push Notification Registration
    
    /// Register device for push notifications with the relay server
    /// Called automatically after wallet initialization and when APNs token is received
    /// Requires valid APNs token and wallet to be initialized
    func registerForPushNotifications() async {
        guard let wallet = wallet,
              let relayService = relayRegistrationService else {
            print("⚠️ [WalletManager] Cannot register for push - wallet or relay service not available")
            return
        }
        
        // Ensure wallet is initialized before attempting registration
        guard isInitialized else {
            print("⚠️ [WalletManager] Cannot register for push - wallet not yet initialized")
            print("   This is normal during app startup. Registration will be retried after initialization.")
            return
        }
        
        // Check if user has enabled notifications in settings
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
        guard notificationsEnabled else {
            print("⚠️ [WalletManager] Notifications disabled in settings")
            return
        }
        
        // Get APNs token from UserDefaults (set by AppDelegate)
        guard let deviceToken = UserDefaults.standard.string(forKey: "apns_device_token"),
              !deviceToken.isEmpty else {
            print("⚠️ [WalletManager] No APNs device token available")
            return
        }
        
        do {
            // Get mailbox credentials from wallet
            let mailboxId = try wallet.mailboxIdentifier()
            let authorizationHex = try wallet.mailboxAuthorization()
            
            // Get Ark server URL from config
            let config = try await wallet.getConfig()
            let arkAddr = config.ark
            guard !arkAddr.isEmpty else {
                print("❌ [WalletManager] No Ark server URL in config")
                return
            }
            
            // Get bundle identifier for APNs topic
            let apnsTopic = Bundle.main.bundleIdentifier ?? "com.arke.wallet"
            
            // Debug: Log registration parameters (redact sensitive auth)
            print("📋 [WalletManager] Registration params:")
            print("  - mailboxId: \(mailboxId.prefix(8))... (len: \(mailboxId.count))")
            print("  - authorizationHex: \(authorizationHex.prefix(8))... (len: \(authorizationHex.count))")
            print("  - arkAddr: \(arkAddr)")
            print("  - deviceToken: \(deviceToken.prefix(8))... (len: \(deviceToken.count))")
            print("  - apnsTopic: \(apnsTopic)")
            
            // Register with relay
            try await relayService.registerDevice(
                mailboxId: mailboxId,
                authorizationHex: authorizationHex,
                arkAddr: arkAddr,
                deviceToken: deviceToken,
                apnsTopic: apnsTopic
            )
            
            print("✅ [WalletManager] Successfully registered for push notifications")
        } catch {
            print("❌ [WalletManager] Failed to register for push: \(error.localizedDescription)")
        }
    }
    
    /// Unregister device from push notifications with the relay server
    /// Should be called when user logs out or deletes wallet
    func unregisterFromPushNotifications() async {
        guard let wallet = wallet,
              let relayService = relayRegistrationService else {
            return
        }
        
        guard let deviceToken = UserDefaults.standard.string(forKey: "apns_device_token"),
              !deviceToken.isEmpty else {
            return
        }
        
        do {
            let mailboxId = try wallet.mailboxIdentifier()
            
            try await relayService.unregisterDevice(
                mailboxId: mailboxId,
                deviceToken: deviceToken
            )
            
            print("✅ [WalletManager] Successfully unregistered from push notifications")
        } catch {
            print("❌ [WalletManager] Failed to unregister from push: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notification Observers
    
    /// Set up observer for mailbox update notifications from APNs
    /// Called automatically during WalletManager initialization
    /// Triggers wallet refresh when mailbox updates are received
    func setupMailboxNotificationObserver() {
        print("📮 [WalletManager] Setting up mailbox update observer...")
        NotificationCenter.default.addObserver(
            forName: .mailboxUpdateReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                print("📮 [WalletManager] Mailbox update notification received, refreshing...")
                print("📮 [WalletManager] Current dataVersion: \(self.dataVersion)")
                await self.refresh()
                print("📮 [WalletManager] Refresh complete. New dataVersion: \(self.dataVersion)")
            }
        }
    }
}
#endif
