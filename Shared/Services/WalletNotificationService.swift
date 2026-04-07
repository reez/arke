//
//  WalletNotificationService.swift
//  Ark wallet prototype
//
//  Created by Assistant on 4/7/26.
//

import Foundation
import SwiftUI
import Bark

/// Service responsible for listening to real-time wallet notifications from the Bark SDK
///
/// This service provides instant transaction updates by listening to movement events from
/// the Bark wallet's notification stream. It complements the existing polling-based services
/// by providing real-time responsiveness while the app is in the foreground.
///
/// Architecture:
/// - Listens to `wallet.notifications()` stream in a continuous Task
/// - Converts Movement events to JSON and delegates to TransactionService
/// - Handles three notification types: movementCreated, movementUpdated, channelLagging
/// - Provides fallback to full refresh if notification stream lags
///
/// Lifecycle:
/// - Started when wallet initializes (foreground only)
/// - Stopped when wallet closes or app backgrounds
/// - Auto-reconnects on stream failure (max 5 consecutive errors)
@MainActor
@Observable
class WalletNotificationService {

    // MARK: - Configuration

    /// Delay before attempting to reconnect after stream failure
    private let reconnectDelay: TimeInterval = 5.0

    /// Maximum number of consecutive errors before stopping the service
    private let maxConsecutiveErrors: Int = 5

    // MARK: - State

    /// Whether the notification listener is currently running
    private(set) var isRunning: Bool = false

    /// Timestamp of the last notification received
    private(set) var lastNotificationTime: Date?

    /// Last error encountered (for debugging)
    private(set) var lastError: String?

    /// Counter for consecutive errors (resets on successful notification)
    private var consecutiveErrors: Int = 0

    // MARK: - Dependencies

    private let wallet: BarkWalletProtocol
    private weak var walletManager: WalletManager?
    private weak var transactionService: TransactionService?

    // MARK: - Streaming

    /// Notification stream holder from Bark SDK
    private var notificationHolder: NotificationHolder?

    /// Background task running the notification listener loop
    private var notificationTask: Task<Void, Never>?

    // MARK: - Initialization

    init(wallet: BarkWalletProtocol) {
        self.wallet = wallet
    }

    /// Set the wallet manager reference (needed for triggering refreshes)
    func setWalletManager(_ manager: WalletManager) {
        self.walletManager = manager
    }

    /// Set the transaction service reference (needed for processing movements)
    func setTransactionService(_ service: TransactionService) {
        self.transactionService = service
    }

    // MARK: - Lifecycle

    /// Start the notification listener
    func start() {
        guard !isRunning else {
            print("⚠️ [WalletNotifications] Service already running")
            return
        }

        print("▶️ [WalletNotifications] Starting notification listener")
        isRunning = true
        consecutiveErrors = 0
        lastError = nil

        // Get notification holder from wallet
        notificationHolder = wallet.notifications()

        // Start listening task
        notificationTask = Task {
            await listenForNotifications()
        }
    }

    /// Stop the notification listener
    func stop() {
        guard isRunning else { return }

        print("⏹️ [WalletNotifications] Stopping notification listener")
        isRunning = false

        // Cancel the listening task
        notificationTask?.cancel()
        notificationTask = nil

        // Signal the holder to stop waiting (unblocks pending nextNotification call)
        notificationHolder?.cancelNextNotificationWait()
        notificationHolder = nil
    }

    // MARK: - Core Listening Loop

    /// Main loop that listens for notifications from the Bark SDK
    private func listenForNotifications() async {
        while isRunning {
            // Check for task cancellation
            if Task.isCancelled {
                print("🔚 [WalletNotifications] Task cancelled")
                break
            }

            do {
                guard let holder = notificationHolder else {
                    print("⚠️ [WalletNotifications] No notification holder available")
                    break
                }

                // Block until next notification arrives (or cancellation)
                if let notification = try await holder.nextNotification() {
                    await handleNotification(notification)

                    // Reset error count on success
                    consecutiveErrors = 0
                    lastNotificationTime = Date()
                    lastError = nil
                } else {
                    // Stream ended gracefully (nil return)
                    print("ℹ️ [WalletNotifications] Notification stream ended")
                    break
                }

            } catch {
                consecutiveErrors += 1
                let errorMessage = error.localizedDescription
                lastError = errorMessage

                print("❌ [WalletNotifications] Error (\(consecutiveErrors)/\(maxConsecutiveErrors)): \(errorMessage)")

                // Stop service if too many consecutive errors
                if consecutiveErrors >= maxConsecutiveErrors {
                    print("🛑 [WalletNotifications] Too many consecutive errors, stopping service")
                    break
                }

                // Wait before retrying
                print("⏳ [WalletNotifications] Waiting \(Int(reconnectDelay))s before reconnecting...")
                try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))
            }
        }

        print("🔚 [WalletNotifications] Listener loop exited")
        isRunning = false
    }

    // MARK: - Notification Handling

    /// Handle an incoming wallet notification
    private func handleNotification(_ notification: WalletNotification) async {
        switch notification {
        case .movementCreated(let movement):
            print("📩 [WalletNotifications] Movement created: ID \(movement.id)")
            await handleMovementCreated(movement)

        case .movementUpdated(let movement):
            print("🔄 [WalletNotifications] Movement updated: ID \(movement.id)")
            await handleMovementUpdated(movement)

        case .channelLagging:
            print("⚠️ [WalletNotifications] Channel lagging - triggering full refresh")
            await handleChannelLagging()
        }
    }

    /// Handle a new movement creation notification
    private func handleMovementCreated(_ movement: Movement) async {
        // Convert Movement to JSON string
        let jsonString = convertMovementToJson(movement)

        // Delegate to TransactionService for processing
        await transactionService?.processSingleMovement(json: jsonString)

        // Invalidate balance cache to trigger UI update
        walletManager?.invalidateBalanceCache()
    }

    /// Handle a movement update notification
    private func handleMovementUpdated(_ movement: Movement) async {
        // Same as created - upsert logic in TransactionService handles updates automatically
        let jsonString = convertMovementToJson(movement)
        await transactionService?.processSingleMovement(json: jsonString)

        // Invalidate balance cache to trigger UI update
        walletManager?.invalidateBalanceCache()
    }

    /// Handle channel lagging notification (fallback to full refresh)
    private func handleChannelLagging() async {
        // Trigger full refresh of transactions and balances as fallback
        await transactionService?.refreshTransactions()
        await walletManager?.refreshBalances()
    }

    // MARK: - Movement Conversion

    /// Convert a Movement struct from Bark SDK to JSON string
    /// Uses the same conversion approach as getMovements() in BarkWalletFFI
    private func convertMovementToJson(_ movement: Movement) -> String {
        // Build dictionary matching the format expected by TransactionService
        var dict: [String: Any] = [
            "id": movement.id,
            "status": movement.status,
            "subsystem_name": movement.subsystemName,
            "subsystem_kind": movement.subsystemKind,
            "metadata_json": movement.metadataJson,
            "intended_balance_sats": movement.intendedBalanceSats,
            "effective_balance_sats": movement.effectiveBalanceSats,
            "offchain_fee_sats": movement.offchainFeeSats,
            "sent_to_addresses": movement.sentToAddresses,
            "received_on_addresses": movement.receivedOnAddresses,
            "input_vtxo_ids": movement.inputVtxoIds,
            "output_vtxo_ids": movement.outputVtxoIds,
            "exited_vtxo_ids": movement.exitedVtxoIds,
            "created_at": movement.createdAt,
            "updated_at": movement.updatedAt
        ]

        // Only include completed_at if it's not nil
        if let completedAt = movement.completedAt {
            dict["completed_at"] = completedAt
        }

        // Convert to JSON data
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])

            // Convert to string
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else {
                print("❌ [WalletNotifications] Failed to encode movement as UTF-8 string")
                return "{}"
            }

        } catch {
            print("❌ [WalletNotifications] Failed to serialize movement to JSON: \(error)")
            return "{}"
        }
    }
}
