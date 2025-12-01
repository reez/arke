//
//  SwiftDataHelper.swift
//  Ark wallet prototype
//
//  Created on 10/29/25.
//

import Foundation
import SwiftData

/// Helper for managing SwiftData ModelContainer with automatic store deletion on migration errors
struct SwiftDataHelper {
    
    /// Manually deletes all SwiftData stores (useful for debugging)
    /// - Returns: True if successful, false otherwise
    @discardableResult
    static func resetAllStores() -> Bool {
        deleteExistingStore()
        return true
    }
    
    /// Creates a ModelContainer with automatic fallback to delete and recreate on migration errors
    /// - Parameters:
    ///   - types: The model types to include in the schema
    ///   - inMemory: Whether to use in-memory storage (default: false)
    ///   - cloudKitEnabled: Whether to enable CloudKit syncing (default: false)
    ///   - cloudKitContainerIdentifier: Optional custom CloudKit container identifier
    /// - Returns: A configured ModelContainer
    static func createModelContainer(
        for types: any PersistentModel.Type..., 
        inMemory: Bool = false,
        cloudKitEnabled: Bool = false,
        cloudKitContainerIdentifier: String? = nil
    ) -> ModelContainer {
        let schema = Schema(types)
        
        // Create configuration with CloudKit support if enabled
        let configuration: ModelConfiguration
        if cloudKitEnabled {
            // Use custom container identifier if provided, otherwise use automatic
            if let containerIdentifier = cloudKitContainerIdentifier {
                configuration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: inMemory,
                    cloudKitDatabase: .private(containerIdentifier)
                )
                print("🌥️ CloudKit enabled with container: \(containerIdentifier)")
            } else {
                configuration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: inMemory,
                    cloudKitDatabase: .automatic
                )
                print("🌥️ CloudKit enabled with automatic container")
            }
        } else {
            // Local storage only
            configuration = ModelConfiguration(
                schema: schema, 
                isStoredInMemoryOnly: inMemory
            )
            print("💾 Local storage only (CloudKit disabled)")
        }
        
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            print("✅ ModelContainer created successfully")
            return container
        } catch {
            // Check if this is a SwiftData error or migration error
            let shouldDeleteStore: Bool
            
            // Check for SwiftDataError.loadIssueModelContainer
            if let swiftDataError = error as? SwiftDataError {
                print("⚠️ SwiftData error detected: \(swiftDataError)")
                shouldDeleteStore = true
            }
            // Check for NSCocoaError migration issues (common error codes: 134110, 134100, 134060)
            else if let nsError = error as NSError?,
                    nsError.domain == NSCocoaErrorDomain,
                    [134110, 134100, 134060].contains(nsError.code) {
                print("⚠️ Migration error detected: \(nsError.localizedDescription)")
                shouldDeleteStore = true
            } else {
                print("❌ Failed to create ModelContainer: \(error)")
                shouldDeleteStore = false
            }
            
            if shouldDeleteStore {
                print("🗑️ Deleting existing store and creating new one...")
                
                // Delete existing store files
                deleteExistingStore()
                
                // Try creating container again
                do {
                    let container = try ModelContainer(for: schema, configurations: configuration)
                    print("✅ ModelContainer created successfully after store deletion")
                    return container
                } catch {
                    print("❌ Failed to create ModelContainer even after deleting store: \(error)")
                    fatalError("Could not create ModelContainer: \(error)")
                }
            } else {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
    
    /// Deletes existing SwiftData store files from the app support directory
    private static func deleteExistingStore() {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                          in: .userDomainMask).first else {
            print("❌ Could not find application support directory")
            return
        }
        
        print("📂 Searching for stores in: \(appSupportURL.path)")
        
        // Try to find and delete all .store files and related files
        do {
            let fileManager = FileManager.default
            
            // Create app support directory if it doesn't exist
            if !fileManager.fileExists(atPath: appSupportURL.path) {
                try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
                print("📁 Created app support directory")
                return // No stores to delete if directory didn't exist
            }
            
            // Get all files in the directory
            let contents = try fileManager.contentsOfDirectory(at: appSupportURL, 
                                                               includingPropertiesForKeys: nil)
            
            // Delete all .store files and their associated files
            for fileURL in contents {
                let fileName = fileURL.lastPathComponent
                if fileName.hasSuffix(".store") || 
                   fileName.hasSuffix(".store-shm") || 
                   fileName.hasSuffix(".store-wal") {
                    do {
                        try fileManager.removeItem(at: fileURL)
                        print("🗑️ Deleted: \(fileName)")
                    } catch {
                        print("⚠️ Failed to delete \(fileName): \(error)")
                    }
                }
            }
            
            print("✅ Store cleanup complete")
            
        } catch {
            print("⚠️ Error during store cleanup: \(error)")
        }
    }
}