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
        // Note: Using Notification.Name directly since NSPersistentStoreRemoteChange
        // is part of Core Data's CloudKit integration
        NotificationCenter.default
            .publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] notification in
                self?.handleRemoteChange(notification)
            }
            .store(in: &cancellables)
        
        print("🌥️ [CloudKit] Started observing remote changes (iOS & macOS)")
    }
    
    /// Handle incoming CloudKit remote change notifications
    private func handleRemoteChange(_ notification: Notification) {
        print("🌥️ [CloudKit] Remote change detected - refreshing data")
        
        // SwiftData automatically handles the merge of remote changes
        // We trigger a save to ensure the context picks up the changes
        Task { @MainActor in
            do {
                // Access the main context
                let context = modelContainer.mainContext
                
                // Save to trigger a refresh of the persistent store
                // This ensures @Query properties in SwiftUI views will update
                try context.save()
                
                print("✅ [CloudKit] Data refreshed from remote changes")
                
                // Post notification for services to refresh their cached data
                NotificationCenter.default.post(name: .cloudKitDataDidChange, object: nil)
                print("📢 [CloudKit] Posted cloudKitDataDidChange notification")
                
            } catch {
                print("⚠️ [CloudKit] Failed to save context after remote change: \(error)")
            }
        }
    }
    
    deinit {
        cancellables.removeAll()
        print("🌥️ [CloudKit] Stopped observing remote changes")
    }
}

// MARK: - Notification.Name Extension

extension Notification.Name {
    /// Notification posted when the persistent store coordinator receives remote changes from CloudKit
    /// This is the Core Data notification that SwiftData uses under the hood
    static let NSPersistentStoreRemoteChange = Notification.Name("NSPersistentStoreRemoteChangeNotification")
    
    /// Custom notification posted after CloudKit remote changes have been processed
    /// Services can observe this to refresh their cached data
    static let cloudKitDataDidChange = Notification.Name("cloudKitDataDidChange")
}
