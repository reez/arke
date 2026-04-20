//
//  WalletManager+Contacts.swift
//  Arké
//
//  Contact operations - delegates to ContactService
//

import Foundation
import SwiftData

extension WalletManager {
    
    // MARK: - Contact Properties
    
    var contacts: [ContactModel] {
        contactService.contacts
    }
    
    var alphabeticalContacts: [ContactModel] {
        contactService.alphabeticalContacts
    }
    
    var recentContacts: [ContactModel] {
        contactService.recentContacts
    }
    
    var contactCount: Int {
        contactService.contactCount
    }
    
    var hasContacts: Bool {
        contactService.hasContacts
    }
    
    var contactServiceError: String? {
        contactService.error
    }
    
    /// Access to ContactService for SwiftUI environment injection
    var contactServiceForEnvironment: ContactService {
        contactService
    }
    
    // MARK: - Contact Operations
    
    /// Create a new contact
    func createContact(_ contactModel: ContactModel) async throws -> ContactModel {
        return try await contactService.createContact(contactModel)
    }
    
    /// Update an existing contact
    func updateContact(_ contactModel: ContactModel) async throws {
        try await contactService.updateContact(contactModel)
    }
    
    /// Delete a contact
    func deleteContact(_ contactId: UUID) async throws {
        try await contactService.deleteContact(contactId)
    }
    
    /// Assign a contact to a transaction
    func assignContact(_ contactId: UUID, to transactionTxid: String) async throws {
        try await contactService.assignContact(contactId, to: transactionTxid)
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after contact assignment")
    }
    
    /// Assign a contact to a transaction with address learning and bulk assignment
    /// - If the transaction has an address, it will be added to the contact's addresses
    /// - All other transactions with the same address (without contacts) will be auto-assigned
    /// - Returns the number of additional transactions that were auto-assigned
    @discardableResult
    func assignContactWithAddressLearning(_ contactId: UUID, to transactionTxid: String) async throws -> Int {
        guard let modelContext = modelContext else {
            throw BarkErrorArke.commandFailed("Model context not available")
        }
        
        print("🔗 Starting contact assignment with address learning for transaction: \(transactionTxid)")
        
        // First, assign the contact to the transaction
        try await contactService.assignContact(contactId, to: transactionTxid)
        print("✅ Created basic contact assignment")
        
        // Try to get the transaction and its address
        let transactionDescriptor = FetchDescriptor<PersistentTransaction>(
            predicate: #Predicate<PersistentTransaction> { $0.txid == transactionTxid }
        )
        let transactions = try modelContext.fetch(transactionDescriptor)
        
        guard let transaction = transactions.first,
              let address = transaction.address,
              !address.isEmpty else {
            // Transaction has no address, just return after basic assignment
            print("ℹ️ Transaction \(transactionTxid) has no address, skipping address learning")
            return 0
        }
        
        // Get the contact to check if it already has this address
        let contactDescriptor = FetchDescriptor<PersistentContact>(
            predicate: #Predicate<PersistentContact> { $0.id == contactId }
        )
        let contacts = try modelContext.fetch(contactDescriptor)
        
        guard let contact = contacts.first else {
            print("⚠️ Contact \(contactId) not found for address learning")
            return 0
        }
        
        // Normalize the address for comparison
        let normalizedAddress = address.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
        
        // Check if the contact already has this address
        let hasAddress = contact.addresses?.contains { 
            $0.normalizedAddress == normalizedAddress 
        } ?? false
        
        // Add the address to the contact if it's new
        if !hasAddress {
            do {
                // Determine if this should be the primary address
                let isPrimary = contact.addresses?.isEmpty ?? true
                
                let newAddress = try await contactAddressService.validateAndCreateAddress(
                    address,
                    for: contactId,
                    label: "From transaction",
                    isPrimary: isPrimary
                )
                
                print("✅ Added address to contact '\(contact.cachedName)': \(newAddress.shortAddress)")
            } catch {
                // Don't fail the whole operation if address creation fails
                print("⚠️ Failed to add address to contact: \(error)")
            }
        } else {
            print("ℹ️ Contact '\(contact.cachedName)' already has address \(address)")
        }
        
        // Step 2: Find all other transactions with the same address
        // Note: We can't use lowercased() in predicates, so we fetch all transactions with addresses
        // and filter in memory for case-insensitive comparison
        let allTransactionsWithAddressDescriptor = FetchDescriptor<PersistentTransaction>(
            predicate: #Predicate<PersistentTransaction> { transaction in
                transaction.address != nil
            }
        )
        let allTransactionsWithAddresses = try modelContext.fetch(allTransactionsWithAddressDescriptor)
        
        // Filter in memory for case-insensitive address matching
        let allTransactionsWithAddress = allTransactionsWithAddresses.filter { transaction in
            guard let txAddress = transaction.address else { return false }
            return txAddress.lowercased() == normalizedAddress
        }
        
        // Filter to only transactions without any contact assignments
        let unassignedTransactions = allTransactionsWithAddress.filter { tx in
            (tx.contactAssignments?.isEmpty ?? true) && tx.txid != transactionTxid
        }
        
        // Bulk assign the contact to all unassigned transactions
        var autoAssignedCount = 0
        for unassignedTransaction in unassignedTransactions {
            // Create the assignment
            let assignment = TransactionContactAssignment(contact: contact, transaction: unassignedTransaction)
            modelContext.insert(assignment)
            autoAssignedCount += 1
        }
        
        // Save all the new assignments at once
        if autoAssignedCount > 0 {
            do {
                contact.touch() // Update contact's timestamp
                try modelContext.save()
                print("✅ Auto-assigned contact '\(contact.cachedName)' to \(autoAssignedCount) additional transaction(s) with address \(address)")
            } catch {
                print("⚠️ Failed to save auto-assignments: \(error)")
                // Don't throw - the main assignment already succeeded
            }
        } else {
            print("ℹ️ No additional transactions to auto-assign (all transactions with this address already have contacts)")
        }
        
        // Final summary
        print("📊 Contact assignment complete - Total auto-assigned: \(autoAssignedCount)")
        
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after contact assignment with address learning")
        
        return autoAssignedCount
    }
    
    /// Remove a contact assignment from a transaction
    func unassignContact(_ contactId: UUID, from transactionTxid: String) async throws {
        try await contactService.unassignContact(contactId, from: transactionTxid)
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after contact unassignment")
    }
    
    /// Remove all contact assignments from a transaction
    func removeContactAssignment(from transactionId: String) async throws {
        try await contactService.removeAllContactsFromTransaction(transactionId)
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after removing all contact assignments")
    }
    
    /// Get all transactions with a specific contact
    func getTransactionsWithContact(_ contactId: UUID) async throws -> [TransactionModel] {
        return try await contactService.getTransactionsWithContact(contactId)
    }
    
    /// Get all contacts assigned to a specific transaction
    func getTransactionContacts(_ transactionId: String) async throws -> [ContactModel] {
        return try await contactService.getContactsForTransaction(transactionId)
    }
    
    /// Check if a transaction has any contacts
    func transactionHasContacts(_ transactionId: String) async throws -> Bool {
        let contacts = try await getTransactionContacts(transactionId)
        return !contacts.isEmpty
    }
    
    /// Search contacts by name
    func searchContacts(_ searchText: String) -> [ContactModel] {
        return contactService.searchContacts(searchText)
    }
    
    /// Get contact usage statistics
    func getContactStatistics() async throws -> [ContactStatistic] {
        return try await contactService.getContactStatistics()
    }
    
    /// Find or create contact by name
    func findOrCreateContact(name: String) async throws -> ContactModel {
        return try await contactService.findOrCreateContact(name: name)
    }
    
    /// Clear contact service errors
    func clearContactError() {
        contactService.clearError()
    }
    
    /// Refresh contacts from storage
    func refreshContacts() async {
        await contactService.refreshContacts()
    }
    
    /// Create default contacts if needed
    func createDefaultContactsIfNeeded() async {
        await contactService.createDefaultContactsIfNeeded()
    }
}
