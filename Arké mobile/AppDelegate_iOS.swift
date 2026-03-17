//
//  AppDelegate_iOS.swift
//  Arké mobile
//
//  Handles APNs token registration and notification handling
//

import UIKit
import UserNotifications

class AppDelegate_iOS: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Set this class as the notification center delegate
        UNUserNotificationCenter.current().delegate = self
        print("📱 [AppDelegate] UNUserNotificationCenter delegate set")
    }
    
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
    
    /// Called when a notification is received while app is in foreground or background
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📬 [APNs] Received remote notification at \(Date())")
        print("📬 [APNs] Notification payload: \(userInfo)")
        print("📬 [APNs] App state: \(application.applicationState.description)")
        
        // Check if this is a CloudKit notification
        if userInfo["ck"] != nil {
            print("🌥️ [CloudKit] CloudKit notification received")
            completionHandler(.newData)
            return
        }
        
        // Check if this is a mailbox notification from relay
        // The relay sends notifications with type="mailbox_arkoor" and includes vtxo_count
        print("📮 [Mailbox] Checking for mailbox notification...")
        if let notificationType = userInfo["type"] as? String,
           notificationType.contains("mailbox") {
            print("📮 [Mailbox] ✅ Mailbox notification confirmed (type: \(notificationType)) - posting NotificationCenter event")
            
            // Post notification to trigger wallet sync
            NotificationCenter.default.post(
                name: .mailboxUpdateReceived,
                object: nil
            )
            print("📮 [Mailbox] NotificationCenter.post completed")
            
            completionHandler(.newData)
            return
        } else {
            print("📮 [Mailbox] Not a mailbox notification")
        }
        
        completionHandler(.noData)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Called when a notification is received while app is in the FOREGROUND
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        print("📬 [Foreground Notification] Received notification while app is active")
        print("📬 [Foreground Notification] Payload: \(userInfo)")
        
        // Check if this is a CloudKit notification
        if userInfo["ck"] != nil {
            print("🌥️ [CloudKit] CloudKit notification in foreground")
            // Don't show CloudKit notifications to user
            completionHandler([])
            return
        }
        
        // Check if this is a mailbox notification from relay
        // The relay sends notifications with type="mailbox_arkoor" and includes vtxo_count
        print("📮 [Mailbox] Checking for mailbox notification...")
        if let notificationType = userInfo["type"] as? String,
           notificationType.contains("mailbox") {
            print("📮 [Mailbox] ✅ Mailbox notification confirmed (type: \(notificationType)) - posting NotificationCenter event")
            
            // Post notification to trigger wallet sync
            NotificationCenter.default.post(
                name: .mailboxUpdateReceived,
                object: nil
            )
            print("📮 [Mailbox] NotificationCenter.post completed")
            
            // Show the notification banner (it has the amount and message)
            completionHandler([.banner, .sound])
            return
        } else {
            print("📮 [Mailbox] Not a mailbox notification")
        }
        
        // For other notifications, show banner and sound
        completionHandler([.banner, .sound])
    }
    
    /// Called when user taps on a notification (app closed, background, or foreground)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        print("📬 [Notification Tap] User tapped notification")
        print("📬 [Notification Tap] Payload: \(userInfo)")
        
        // Check if this is a mailbox notification
        if let notificationType = userInfo["type"] as? String,
           notificationType.contains("mailbox") {
            print("📮 [Mailbox] User tapped mailbox notification - posting NotificationCenter event")
            
            // Post notification to trigger wallet sync when app becomes active
            NotificationCenter.default.post(
                name: .mailboxUpdateReceived,
                object: nil
            )
            print("📮 [Mailbox] NotificationCenter.post completed")
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when APNs token is received
    static let apnsTokenReceived = Notification.Name("apnsTokenReceived")
    
    /// Posted when mailbox update notification is received
    static let mailboxUpdateReceived = Notification.Name("mailboxUpdateReceived")
}
// MARK: - UIApplication.State Extension

extension UIApplication.State {
    var description: String {
        switch self {
        case .active: return "active (foreground)"
        case .inactive: return "inactive (transitioning)"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }
}

