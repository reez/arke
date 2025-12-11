//
//  CloudKitObserver.swift
//  Arké mobile
//
//  Created by Assistant on 12/3/25.
//

import SwiftUI
import SwiftData
import CoreData
import Combine

/// Observes CloudKit remote change notifications and triggers SwiftData refreshes
/// This enables real-time sync across devices when changes are made
/// Works on both iOS and macOS
@Observable
final class CloudKitObserver {
    private var cancellables = Set<AnyCancellable>()
    private let modelContainer: ModelContainer
    
    // Debouncing and deduplication state
    private var lastChangeTimestamp: Date?
    private let minimumChangeInterval: TimeInterval = 2.0 // Ignore rapid-fire changes within 2 seconds
    private var pendingChangeTask: Task<Void, Never>?
    
    /// Initialize and start observing CloudKit remote changes
    /// - Parameter modelContainer: The ModelContainer to refresh when changes arrive
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        startObserving()
    }
    
    /// Start listening for CloudKit remote change notifications
    private func startObserving() {
        // Observe NSPersistentStoreRemoteChange notifications from Core Data
        // These are posted when CloudKit pushes changes from other devices
        // Using the actual Core Data system notification instead of a custom string
        // Apply debouncing at the publisher level to batch rapid changes
        NotificationCenter.default
            .publisher(for: NSNotification.Name.NSPersistentStoreRemoteChange)
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main) // Batch changes within 1.5s window
            .sink { [weak self] notification in
                self?.handleRemoteChange(notification)
            }
            .store(in: &cancellables)
        
        print("🌥️ [CloudKit] Started observing remote changes (debounced: 1.5s)")
        print("📡 [CloudKit] Listening for: \(NSNotification.Name.NSPersistentStoreRemoteChange.rawValue)")
    }
    
    /// Handle incoming CloudKit remote change notifications
    private func handleRemoteChange(_ notification: Notification) {
        // Additional layer of protection: ignore changes that arrive too close together
        // This catches cases where multiple batches arrive in rapid succession
        let now = Date()
        if let lastChange = lastChangeTimestamp,
           now.timeIntervalSince(lastChange) < minimumChangeInterval {
            print("⏭️ [CloudKit] Ignoring rapid-fire notification (within \(minimumChangeInterval)s of last change)")
            return
        }
        
        lastChangeTimestamp = now
        
        print("🌥️ [CloudKit] Remote change detected - refreshing data")
        print("📦 [CloudKit] Notification object: \(String(describing: notification.object))")
        
        // Cancel any pending change task to avoid duplicate notifications
        pendingChangeTask?.cancel()
        
        // SwiftData automatically merges remote changes from CloudKit
        // We just need to notify observers that data has changed
        pendingChangeTask = Task { @MainActor in
            // Small delay to let SwiftData finish merging changes
            try? await Task.sleep(for: .milliseconds(100))
            
            guard !Task.isCancelled else {
                print("⏭️ [CloudKit] Change notification cancelled (superseded by newer change)")
                return
            }
            
            // SwiftData's ModelContext automatically receives updates from the persistent store
            // when CloudKit pushes changes. @Query properties will update automatically.
            // We just post a notification for any services that maintain their own caches.
            
            print("✅ [CloudKit] Data refreshed from remote changes")
            
            // Post notification for services to refresh their cached data
            NotificationCenter.default.post(name: .cloudKitDataDidChange, object: nil)
            print("📢 [CloudKit] Posted cloudKitDataDidChange notification")
            
            self.pendingChangeTask = nil
        }
    }
    
    deinit {
        pendingChangeTask?.cancel()
        cancellables.removeAll()
        print("🌥️ [CloudKit] Stopped observing remote changes")
    }
}

// MARK: - Notification.Name Extension

extension Notification.Name {
    /// Custom notification posted after CloudKit remote changes have been processed
    /// Services can observe this to refresh their cached data
    static let cloudKitDataDidChange = Notification.Name("cloudKitDataDidChange")
}
