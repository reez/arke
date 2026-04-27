//
//  AppDelegate_iOS.swift
//  Arké mobile
//
//  Handles APNs token registration and notification handling
//

import UIKit
import UserNotifications
import OSLog

class AppDelegate_iOS: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Logger for AppDelegate operations
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.arke", category: "AppDelegate")
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Set this class as the notification center delegate
        UNUserNotificationCenter.current().delegate = self
        Self.logger.info("UNUserNotificationCenter delegate set")
    }
    
    // MARK: - APNs Token Management
    
    /// Called when APNs successfully registers and returns a device token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert device token to hex string
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        
        Self.logger.info("APNs device token received: \(tokenString)")
        
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
        Self.logger.error("APNs failed to register: \(error.localizedDescription)")
        
        // Clear any stale token
        UserDefaults.standard.removeObject(forKey: "apns_device_token")
    }
    
    /// Called when a notification is received while app is in foreground or background
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Self.logger.info("APNs received remote notification at \(Date())")
        Self.logger.debug("APNs notification payload: \(String(describing: userInfo))")
        Self.logger.debug("APNs app state: \(application.applicationState.description)")
        
        // Check if this is a CloudKit notification
        if userInfo["ck"] != nil {
            Self.logger.info("CloudKit notification received")
            completionHandler(.newData)
            return
        }
        
        // Check if this is a mailbox notification from relay
        // The relay sends notifications with type="mailbox_arkoor" and includes vtxo_count
        Self.logger.debug("Checking for mailbox notification...")
        if let notificationType = userInfo["type"] as? String,
           notificationType.contains("mailbox") {
            Self.logger.info("Mailbox notification confirmed (type: \(notificationType)) - posting NotificationCenter event")
            
            // Post notification to trigger wallet sync
            NotificationCenter.default.post(
                name: .mailboxUpdateReceived,
                object: nil
            )
            Self.logger.debug("NotificationCenter.post completed")
            
            completionHandler(.newData)
            return
        } else {
            Self.logger.debug("Not a mailbox notification")
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
        
        Self.logger.info("Received notification while app is active (foreground)")
        Self.logger.debug("Foreground notification payload: \(String(describing: userInfo))")
        
        // Check if this is a CloudKit notification
        if userInfo["ck"] != nil {
            Self.logger.info("CloudKit notification in foreground")
            // Don't show CloudKit notifications to user
            completionHandler([])
            return
        }
        
        // Check if this is a mailbox notification from relay
        // The relay sends notifications with type="mailbox_arkoor" and includes vtxo_count
        Self.logger.debug("Checking for mailbox notification...")
        if let notificationType = userInfo["type"] as? String,
           notificationType.contains("mailbox") {
            Self.logger.info("Mailbox notification confirmed (type: \(notificationType)) - posting NotificationCenter event")
            
            // Post notification to trigger wallet sync
            NotificationCenter.default.post(
                name: .mailboxUpdateReceived,
                object: nil
            )
            Self.logger.debug("NotificationCenter.post completed")
            
            // Show the notification banner (it has the amount and message)
            completionHandler([.banner, .sound])
            return
        } else {
            Self.logger.debug("Not a mailbox notification")
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
        
        Self.logger.info("User tapped notification")
        Self.logger.debug("Notification tap payload: \(String(describing: userInfo))")
        
        // Check if this is a mailbox notification
        if let notificationType = userInfo["type"] as? String,
           notificationType.contains("mailbox") {
            Self.logger.info("User tapped mailbox notification - posting NotificationCenter event")
            
            // Post notification to trigger wallet sync when app becomes active
            NotificationCenter.default.post(
                name: .mailboxUpdateReceived,
                object: nil
            )
            Self.logger.debug("NotificationCenter.post completed")
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

