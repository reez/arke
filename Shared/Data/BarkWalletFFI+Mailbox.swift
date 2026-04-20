//
//  BarkWalletFFI+Mailbox.swift
//  Arke
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension BarkWalletFFI {
    
    func mailboxIdentifier() async throws -> String {
        // Get mailbox identifier (hex-encoded public key)
        
        if isPreview {
            return "mock_mailbox_identifier_hex"
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.mailboxIdentifier()
        } catch let error as BarkError {
            print("❌ FFI Error getting mailbox identifier: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get mailbox identifier: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting mailbox identifier: \(error)")
            throw error
        }
    }
    
    func mailboxAuthorization() async throws -> String {
        // Get mailbox authorization token
        
        if isPreview {
            return "mock_authorization_token"
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.mailboxAuthorization()
        } catch let error as BarkError {
            print("❌ FFI Error getting mailbox authorization: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get mailbox authorization: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting mailbox authorization: \(error)")
            throw error
        }
    }
    
    /**
     * Get a pull-based notification holder for this wallet.
     *
     * Call `next_notification()` in a loop to receive events.
     * Call `cancel_next_notification_wait()` to unblock a pending wait without
     * destroying the stream.
     */
    func notifications() -> NotificationHolder {
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            fatalError("Wallet has not been created or opened")
        }
        
        print("🔔 Creating notification holder...")
        
        // Call FFI method to get notification holder
        let notificationHolder = wallet.notifications()
        
        print("✅ Notification holder created successfully")
        
        return notificationHolder
    }
}
