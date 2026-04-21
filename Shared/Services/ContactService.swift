//
//  ContactService.swift
//  Arké
//
//  Service responsible for managing all contact-related operations
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import ArkeUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Service responsible for managing all contact-related operations
/// 
/// This service is split into multiple extension files for better organization:
/// - ContactService+CRUD: Create, read, update, delete operations
/// - ContactService+Queries: Search and query operations
/// - ContactService+Addresses: Address management helpers
/// - ContactService+Assignments: Transaction-contact assignment operations
/// - ContactService+BulkOperations: Batch operations
/// - ContactService+DefaultContacts: Default contact creation
/// - ContactService+NativeIntegration: iOS/macOS Contacts app integration
/// - ContactService+StateManagement: State and error management
@MainActor
@Observable
class ContactService {
    
    // MARK: - Published Properties
    
    /// All available contacts
    var contacts: [ContactModel] = []
    
    /// Error message for contact operations
    var error: String?
    
    /// Loading state for contact operations
    var isLoading: Bool = false
    
    // MARK: - Dependencies
    
    // Only for internal use by extensions.
    let taskManager: TaskDeduplicationManager
    var modelContext: ModelContext?
    
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties for UI
    
    /// Count of contacts
    var contactCount: Int {
        contacts.count
    }
    
    /// True if any contacts exist
    var hasContacts: Bool {
        !contacts.isEmpty
    }
    
    /// Contacts sorted by most recent activity
    var recentContacts: [ContactModel] {
        contacts.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    /// Contacts sorted alphabetically by name
    var alphabeticalContacts: [ContactModel] {
        contacts.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    
    // MARK: - Initialization
    
    init(taskManager: TaskDeduplicationManager) {
        self.taskManager = taskManager
        // Don't start observing CloudKit changes yet - wait until setModelContext() is called
        // This ensures we only observe when a wallet exists
    }
    
    // MARK: - CloudKit Change Observation
    
    /// Start observing CloudKit remote change notifications
    /// Called automatically when setModelContext() is invoked (only when wallet exists)
    private func startObservingCloudKitChanges() {
        // Prevent duplicate subscriptions
        guard cancellables.isEmpty else {
            print("⏭️ [ContactService] Already observing CloudKit changes")
            return
        }
        
        NotificationCenter.default
            .publisher(for: .cloudKitDataDidChange)
            .debounce(for: .seconds(1), scheduler: RunLoop.main) // Debounce rapid notifications
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleCloudKitChange()
                }
            }
            .store(in: &cancellables)
        
        print("👥 [ContactService] Started observing CloudKit changes (debounced)")
    }
    
    /// Handle CloudKit remote changes by reloading contacts
    private func handleCloudKitChange() async {
        print("👥 [ContactService] CloudKit change detected - reloading contacts")
        await loadContacts()
    }
    
    deinit {
        cancellables.removeAll()
        print("👥 [ContactService] Stopped observing CloudKit changes")
    }
    
    // MARK: - SwiftData Integration
    
    /// Set the model context for persistence operations
    /// This is only called when a wallet exists (ServiceContainer.isActive == true)
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        
        // Start observing CloudKit changes now that we have a context (and wallet)
        startObservingCloudKitChanges()
        
        // Load existing contacts on startup
        Task {
            await loadContacts()
        }
    }
}
