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
        NotificationCenter.default
            .publisher(for: NSNotification.Name.NSPersistentStoreRemoteChange)
            .sink { [weak self] notification in
                self?.handleRemoteChange(notification)
            }
            .store(in: &cancellables)
        
        print("🌥️ [CloudKit] Started observing remote changes (iOS & macOS)")
        print("📡 [CloudKit] Listening for: \(NSNotification.Name.NSPersistentStoreRemoteChange.rawValue)")
    }
    
    /// Handle incoming CloudKit remote change notifications
    private func handleRemoteChange(_ notification: Notification) {
        print("🌥️ [CloudKit] Remote change detected - refreshing data")
        print("📦 [CloudKit] Notification object: \(String(describing: notification.object))")
        
        // SwiftData automatically merges remote changes from CloudKit
        // We just need to notify observers that data has changed
        Task { @MainActor in
            // SwiftData's ModelContext automatically receives updates from the persistent store
            // when CloudKit pushes changes. @Query properties will update automatically.
            // We just post a notification for any services that maintain their own caches.
            
            print("✅ [CloudKit] Data refreshed from remote changes")
            
            // Post notification for services to refresh their cached data
            NotificationCenter.default.post(name: .cloudKitDataDidChange, object: nil)
            print("📢 [CloudKit] Posted cloudKitDataDidChange notification")
        }
    }
    
    deinit {
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
