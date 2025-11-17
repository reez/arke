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
    
    /// Service for managing tags
    let tagService: TagService
    
    /// Service for managing contacts
    let contactService: ContactService
    
    /// Service for managing contact addresses  
    let contactAddressService: ContactAddressService
    
    // MARK: - Initialization
    
    /// Shared instance of the service container
    static let shared = ServiceContainer()
    
    private init() {
        // Initialize services with the task manager
        self.tagService = TagService(taskManager: taskManager)
        self.contactService = ContactService(taskManager: taskManager)
        self.contactAddressService = ContactAddressService(taskManager: taskManager)
        
        print("🔧 ServiceContainer initialized")
    }
    
    // MARK: - SwiftData Integration
    
    /// Configure all services with the SwiftData model context
    func configureServices(with modelContext: ModelContext) {
        print("🔧 Configuring services with ModelContext")
        
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