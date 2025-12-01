//
//  ServiceContainer.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/04/25.
//

import Foundation
import SwiftData
import SwiftUI

/// Container that manages all app services and their dependencies
@MainActor
@Observable
class ServiceContainer {
    
    // MARK: - Core Dependencies
    
    /// Task deduplication manager shared across all services
    let taskManager = TaskDeduplicationManager()
    
    // MARK: - Services
    
    /// Service for managing wallet security and authentication
    let securityService: SecurityService
    
    /// Service for managing tags
    let tagService: TagService
    
    /// Service for managing contacts
    let contactService: ContactService
    
    /// Service for managing contact addresses  
    let contactAddressService: ContactAddressService
    
    // MARK: - State
    
    /// Controls whether services should load and sync data
    /// Set to `false` during onboarding, `true` when wallet exists
    private(set) var isActive: Bool = false
    
    // MARK: - Initialization
    
    /// Shared instance of the service container
    static let shared = ServiceContainer()
    
    private init() {
        // Initialize services with the task manager
        self.securityService = SecurityService(taskManager: taskManager)
        self.tagService = TagService(taskManager: taskManager)
        self.contactService = ContactService(taskManager: taskManager)
        self.contactAddressService = ContactAddressService(taskManager: taskManager)
        
        print("🔧 ServiceContainer initialized at \(Date())")
    }
    
    // MARK: - Activation
    
    /// Activates or deactivates the service container
    /// - Parameter active: `true` to enable data loading/syncing, `false` to keep passive
    func setActive(_ active: Bool) {
        self.isActive = active
        
        if active {
            print("✅ ServiceContainer activated - services will load and sync data")
        } else {
            print("⏸️ ServiceContainer passive - services will not load data yet")
        }
    }
    
    // MARK: - SwiftData Integration
    
    /// Configure all services with the SwiftData model context
    /// Only loads data if the container is active (wallet exists)
    func configureServices(with modelContext: ModelContext) {
        guard isActive else {
            print("⏭️ Skipping service configuration - container is passive")
            return
        }
        
        print("🔧 Configuring services with ModelContext")
        
        securityService.setModelContext(modelContext)
        tagService.setModelContext(modelContext)
        contactService.setModelContext(modelContext)
        contactAddressService.setModelContext(modelContext)
    }
    
    // MARK: - Lifecycle Management
    
    /// Clean up resources when the app terminates
    func cleanup() {
        print("🧹 Cleaning up ServiceContainer")
        taskManager.cancelAll()
    }
}

// MARK: - SwiftUI Environment Integration

/// Environment key for accessing the service container
private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue = ServiceContainer.shared
}

extension EnvironmentValues {
    var serviceContainer: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - View Extensions for Service Access

extension View {
    /// Inject the service container into the environment
    func withServiceContainer(_ container: ServiceContainer) -> some View {
        environment(\.serviceContainer, container)
    }
    
    /// Inject the shared service container into the environment
    @MainActor
    func withSharedServiceContainer() -> some View {
        environment(\.serviceContainer, ServiceContainer.shared)
    }
}

// MARK: - Convenience Extensions for Service Access

extension EnvironmentValues {
    /// Convenience accessor for the security service
    var securityService: SecurityService {
        serviceContainer.securityService
    }
    
    /// Convenience accessor for the tag service
    var tagService: TagService {
        serviceContainer.tagService
    }
    
    /// Convenience accessor for the contact service
    var contactService: ContactService {
        serviceContainer.contactService
    }
    
    /// Convenience accessor for the contact address service
    var contactAddressService: ContactAddressService {
        serviceContainer.contactAddressService
    }
}
