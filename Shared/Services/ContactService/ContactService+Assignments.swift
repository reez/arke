//
//  ContactService+Assignments.swift
//  Arké
//
//  Transaction-contact assignment operations
//

import Foundation
import SwiftData

extension ContactService {
    
    /// Assign a contact to a transaction
    func assignContact(_ contactId: UUID, to transactionTxid: String) async throws {
        return try await taskManager.execute(key: "assignContact_\(contactId)_\(transactionTxid)") {
            try await self.performAssignContact(contactId, to: transactionTxid)
        }
    }
    
    private func performAssignContact(_ contactId: UUID, to transactionTxid: String) async throws {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        do {
            // Find the contact
            let contactDescriptor = FetchDescriptor<PersistentContact>(
                predicate: #Predicate<PersistentContact> { $0.id == contactId }
            )
            let contacts = try modelContext.fetch(contactDescriptor)
            guard let contact = contacts.first else {
                throw ContactServiceError.contactNotFound(contactId)
            }
            
            // Find the transaction
            let transactionDescriptor = FetchDescriptor<PersistentTransaction>(
                predicate: #Predicate<PersistentTransaction> { $0.txid == transactionTxid }
            )
            let transactions = try modelContext.fetch(transactionDescriptor)
            guard let transaction = transactions.first else {
                throw ContactServiceError.transactionNotFound(transactionTxid)
            }
            
            // Check if assignment already exists
            let assignmentDescriptor = FetchDescriptor<TransactionContactAssignment>(
                predicate: #Predicate<TransactionContactAssignment> {
                    assignment in
                    assignment.contact?.id == contactId && assignment.transaction?.txid == transactionTxid
                }
            )
            let existingAssignments = try modelContext.fetch(assignmentDescriptor)
            
            if !existingAssignments.isEmpty {
                throw ContactServiceError.contactAlreadyAssigned
            }
            
            // Create new assignment
            let assignment = TransactionContactAssignment(contact: contact, transaction: transaction)
            modelContext.insert(assignment)
            
            // Update contact's updated timestamp
            contact.touch()
            
            // Save changes
            try modelContext.save()
            
            print("✅ Assigned contact '\(contact.cachedName)' to transaction \(transactionTxid)")
            
        } catch {
            print("❌ Failed to assign contact: \(error)")
            self.error = "Failed to assign contact: \(error)"
            throw error
        }
    }
    
    /// Remove a contact assignment from a transaction
    /// Note: This only removes the contact from THIS transaction.
    /// It does NOT remove addresses from contacts or affect other transactions with the same address.
    func unassignContact(_ contactId: UUID, from transactionTxid: String) async throws {
        return try await taskManager.execute(key: "unassignContact_\(contactId)_\(transactionTxid)") {
            try await self.performUnassignContact(contactId, from: transactionTxid)
        }
    }
    
    /// Remove all contact assignments from a transaction
    /// Note: This only removes the contact-transaction assignments.
    /// It does NOT remove addresses from contacts or affect other transactions.
    func removeAllContactsFromTransaction(_ transactionId: String) async throws {
        return try await taskManager.execute(key: "removeAllContactsFromTransaction_\(transactionId)") {
            try await self.performRemoveAllContactsFromTransaction(transactionId)
        }
    }
    
    private func performUnassignContact(_ contactId: UUID, from transactionTxid: String) async throws {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        do {
            // Find the assignment
            let assignmentDescriptor = FetchDescriptor<TransactionContactAssignment>(
                predicate: #Predicate<TransactionContactAssignment> {
                    assignment in
                    assignment.contact?.id == contactId && assignment.transaction?.txid == transactionTxid
                }
            )
            let assignments = try modelContext.fetch(assignmentDescriptor)
            
            guard let assignment = assignments.first else {
                throw ContactServiceError.assignmentNotFound
            }
            
            let contactName = assignment.contact?.cachedName ?? "Unknown"
            
            // Delete the assignment
            modelContext.delete(assignment)
            
            // Update contact's updated timestamp if it still exists
            if let contact = assignment.contact {
                contact.touch()
            }
            
            // Save changes
            try modelContext.save()
            
            print("✅ Unassigned contact '\(contactName)' from transaction \(transactionTxid)")
            
        } catch {
            print("❌ Failed to unassign contact: \(error)")
            self.error = "Failed to unassign contact: \(error)"
            throw error
        }
    }
    
    private func performRemoveAllContactsFromTransaction(_ transactionId: String) async throws {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        do {
            // Find all assignments for this transaction
            let assignmentDescriptor = FetchDescriptor<TransactionContactAssignment>(
                predicate: #Predicate<TransactionContactAssignment> { $0.transaction?.txid == transactionId }
            )
            let assignments = try modelContext.fetch(assignmentDescriptor)
            
            guard !assignments.isEmpty else {
                print("ℹ️ No contact assignments found for transaction \(transactionId)")
                return
            }
            
            let contactNames = assignments.compactMap { $0.contact?.cachedName }
            
            // Delete all assignments
            for assignment in assignments {
                // Update contact's updated timestamp if it still exists
                if let contact = assignment.contact {
                    contact.touch()
                }
                modelContext.delete(assignment)
            }
            
            // Save changes
            try modelContext.save()
            
            print("✅ Removed \(assignments.count) contact assignment(s) from transaction \(transactionId): \(contactNames.joined(separator: ", "))")
            
        } catch {
            print("❌ Failed to remove contact assignments: \(error)")
            self.error = "Failed to remove contact assignments: \(error)"
            throw error
        }
    }
}
