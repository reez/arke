//
//  AppDelegate_iOS.swift
//  Arké mobile
//
//  Handles APNs token registration and notification handling
//

import UIKit
import UserNotifications

class AppDelegate_iOS: NSObject, UIApplicationDelegate {
    // MARK: - APNs Token Management
    
    /// Called when APNs successfully registers and returns a device token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert device token to hex string
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        
        print("✅ [APNs] Device token received: \(tokenString)")
        
        // Store token for relay registration
        UserDefaults.standard.set(tokenString, forKey: "apns_device_token")
        
        // Post notification that token is available
        NotificationCenter.default.post(
            name: .apnsTokenReceived,
            object: nil,
            userInfo: ["token": tokenString]
        )
    }
    
    /// Called when APNs registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ [APNs] Failed to register: \(error.localizedDescription)")
        
        // Clear any stale token
        UserDefaults.standard.removeObject(forKey: "apns_device_token")
    }
    
    /// Called when a notification is received while app is in foreground
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📬 [APNs] Received remote notification: \(userInfo)")
        
        // Check if this is a CloudKit notification
        if userInfo["ck"] != nil {
            print("🌥️ [CloudKit] CloudKit notification received")
            completionHandler(.newData)
            return
        }
        
        // Check if this is a mailbox notification from relay
        if let mailboxUpdate = userInfo["mailbox_update"] as? Bool, mailboxUpdate {
            print("📮 [Mailbox] Mailbox update notification received")
            
            // Post notification to trigger wallet sync
            NotificationCenter.default.post(
                name: .mailboxUpdateReceived,
                object: nil
            )
            
            completionHandler(.newData)
            return
        }
        
        completionHandler(.noData)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when APNs token is received
    static let apnsTokenReceived = Notification.Name("apnsTokenReceived")
    
    /// Posted when mailbox update notification is received
    static let mailboxUpdateReceived = Notification.Name("mailboxUpdateReceived")
}
