//
//  ContactService+BulkOperations.swift
//  Arké
//
//  Bulk operations for managing multiple contacts
//

import Foundation
import SwiftData

extension ContactService {
    
    /// Delete all contacts, their addresses, and their assignments from SwiftData
    /// This is used during wallet deletion when user chooses to delete all cloud data
    func deleteAllContacts() async throws {
        return try await taskManager.execute(key: "deleteAllContacts") {
            try await self.performDeleteAllContacts()
        }
    }
    
    private func performDeleteAllContacts() async throws {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch all contacts
            let descriptor = FetchDescriptor<PersistentContact>()
            let allContacts = try modelContext.fetch(descriptor)
            
            guard !allContacts.isEmpty else {
                print("ℹ️ [ContactService] No contacts to delete")
                return
            }
            
            let contactCount = allContacts.count
            
            // Count addresses and assignments before deletion
            var totalAddresses = 0
            var totalAssignments = 0
            for contact in allContacts {
                totalAddresses += contact.addresses?.count ?? 0
                totalAssignments += contact.contactAssignments?.count ?? 0
            }
            
            // Delete all contacts (cascade will handle addresses and assignments)
            for contact in allContacts {
                modelContext.delete(contact)
            }
            
            // Save changes
            try modelContext.save()
            
            // Clear local array
            contacts.removeAll()
            
            print("🗑️ [ContactService] Deleted \(contactCount) contacts, \(totalAddresses) addresses, and \(totalAssignments) contact assignments from SwiftData")
            
        } catch {
            print("❌ [ContactService] Failed to delete all contacts: \(error)")
            self.error = "Failed to delete all contacts: \(error)"
            throw error
        }
    }
}
