//
//  ContactService.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/04/25.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

/// Service responsible for managing all contact-related operations
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
    
    private let taskManager: TaskDeduplicationManager
    private var modelContext: ModelContext?
    
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
    
    // MARK: - Contact CRUD Operations
    
    /// Load all contacts from SwiftData
    func loadContacts() async {
        guard let modelContext = modelContext else {
            print("⚠️ No model context available for loading contacts")
            return
        }
        
        do {
            var descriptor = FetchDescriptor<PersistentContact>(sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse)
            ])
            // Prefetch the addresses relationship to avoid lazy loading issues
            descriptor.relationshipKeyPathsForPrefetching = [\.addresses]
            
            let persistentContacts = try modelContext.fetch(descriptor)
            
            // Convert to UI models (addresses will now be included)
            self.contacts = persistentContacts.map { ContactModel(from: $0) }
            
            print("👥 Loaded \(contacts.count) contacts with addresses from SwiftData")
            
        } catch {
            print("❌ Failed to load contacts: \(error)")
            self.error = "Failed to load contacts: \(error)"
        }
    }
    
    /// Create a new contact
    func createContact(_ contactModel: ContactModel) async throws -> ContactModel {
        return try await taskManager.execute(key: "createContact_\(contactModel.cachedName)") {
            try await self.performCreateContact(contactModel)
        }
    }
    
    private func performCreateContact(_ contactModel: ContactModel) async throws -> ContactModel {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check if contact with same name already exists
            let contactName = contactModel.cachedName
            let existingDescriptor = FetchDescriptor<PersistentContact>(
                predicate: #Predicate<PersistentContact> { $0.cachedName == contactName }
            )
            let existingContacts = try modelContext.fetch(existingDescriptor)
            
            if !existingContacts.isEmpty {
                throw ContactServiceError.contactAlreadyExists(contactModel.cachedName)
            }
            
            // Create persistent contact
            let persistentContact = contactModel.toPersistentContact()
            modelContext.insert(persistentContact)
            
            // Save changes
            try modelContext.save()
            
            // Add to local array
            // Access addresses to ensure they're loaded (though new contacts won't have addresses yet)
            _ = persistentContact.addresses
            let newContact = ContactModel(from: persistentContact)
            self.contacts.append(newContact)
            
            print("✅ Created contact: \(newContact.cachedName)")
            return newContact
            
        } catch {
            print("❌ Failed to create contact: \(error)")
            self.error = "Failed to create contact: \(error)"
            throw error
        }
    }
    
    /// Update an existing contact
    func updateContact(_ updatedContact: ContactModel) async throws {
        return try await taskManager.execute(key: "updateContact_\(updatedContact.id)") {
            try await self.performUpdateContact(updatedContact)
        }
    }
    
    private func performUpdateContact(_ updatedContact: ContactModel) async throws {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Find existing persistent contact
            let contactId = updatedContact.id
            let descriptor = FetchDescriptor<PersistentContact>(
                predicate: #Predicate<PersistentContact> { $0.id == contactId }
            )
            let existingContacts = try modelContext.fetch(descriptor)
            
            guard let persistentContact = existingContacts.first else {
                throw ContactServiceError.contactNotFound(updatedContact.id)
            }
            
            // Update properties
            persistentContact.cachedName = updatedContact.cachedName
            persistentContact.notes = updatedContact.notes
            persistentContact.avatarData = updatedContact.avatarData
            persistentContact.touch() // Update timestamp
            
            // Save changes
            try modelContext.save()
            
            // Update local array
            if let index = contacts.firstIndex(where: { $0.id == updatedContact.id }) {
                // Access addresses to ensure they're loaded
                _ = persistentContact.addresses
                contacts[index] = ContactModel(from: persistentContact)
            }
            
            print("✅ Updated contact: \(updatedContact.cachedName)")
            
        } catch {
            print("❌ Failed to update contact: \(error)")
            self.error = "Failed to update contact: \(error)"
            throw error
        }
    }
    
    /// Delete a contact and all its assignments
    func deleteContact(_ contactId: UUID) async throws {
        return try await taskManager.execute(key: "deleteContact_\(contactId)") {
            try await self.performDeleteContact(contactId)
        }
    }
    
    private func performDeleteContact(_ contactId: UUID) async throws {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Find the contact
            let descriptor = FetchDescriptor<PersistentContact>(
                predicate: #Predicate<PersistentContact> { $0.id == contactId }
            )
            let existingContacts = try modelContext.fetch(descriptor)
            
            guard let persistentContact = existingContacts.first else {
                throw ContactServiceError.contactNotFound(contactId)
            }
            
            let contactName = persistentContact.cachedName
            
            // Delete the contact (cascade will delete assignments)
            modelContext.delete(persistentContact)
            
            // Save changes
            try modelContext.save()
            
            // Remove from local array
            contacts.removeAll { $0.id == contactId }
            
            print("✅ Deleted contact: \(contactName)")
            
        } catch {
            print("❌ Failed to delete contact: \(error)")
            self.error = "Failed to delete contact: \(error)"
            throw error
        }
    }
    
    // MARK: - Contact Assignment Operations
    
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
    
    // MARK: - Query Operations
    
    /// Get all transactions that have a specific contact
    func getTransactionsWithContact(_ contactId: UUID) async throws -> [TransactionModel] {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        do {
            // Find contact assignments for this contact
            let assignmentDescriptor = FetchDescriptor<TransactionContactAssignment>(
                predicate: #Predicate<TransactionContactAssignment> { $0.contact?.id == contactId }
            )
            let assignments = try modelContext.fetch(assignmentDescriptor)
            
            // Extract persistent transactions and convert to UI models
            let persistentTransactions = assignments.compactMap { $0.transaction }
            return persistentTransactions.map { TransactionModel(from: $0) }
            
        } catch {
            print("❌ Failed to get transactions for contact: \(error)")
            throw error
        }
    }
    
    /// Get all contacts assigned to a specific transaction
    func getContactsForTransaction(_ transactionId: String) async throws -> [ContactModel] {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        do {
            // Find contact assignments for this transaction
            var assignmentDescriptor = FetchDescriptor<TransactionContactAssignment>(
                predicate: #Predicate<TransactionContactAssignment> { $0.transaction?.txid == transactionId }
            )
            // Prefetch the contact relationship and its addresses
            assignmentDescriptor.relationshipKeyPathsForPrefetching = [\.contact]
            
            let assignments = try modelContext.fetch(assignmentDescriptor)
            
            // Extract contacts and convert to UI models
            // Note: We need to manually access addresses within the model context
            let contactModels: [ContactModel] = assignments.compactMap { assignment in
                guard let contact = assignment.contact else { return nil }
                // Access addresses to ensure they're loaded before conversion
                _ = contact.addresses
                return ContactModel(from: contact)
            }
            return contactModels
            
        } catch {
            print("❌ Failed to get contacts for transaction: \(error)")
            throw error
        }
    }
    
    /// Search contacts by name
    func searchContacts(_ searchText: String) -> [ContactModel] {
        guard !searchText.isEmpty else { return contacts }
        
        return contacts.filter { contact in
            contact.cachedName.localizedCaseInsensitiveContains(searchText) ||
            (contact.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    /// Get contact statistics
    func getContactStatistics() async throws -> [ContactStatistic] {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        do {
            let contactDescriptor = FetchDescriptor<PersistentContact>()
            let persistentContacts = try modelContext.fetch(contactDescriptor)
            
            let statistics = persistentContacts.map { contact in
                ContactStatistic(
                    contactId: contact.id,
                    contactName: contact.displayName,
                    transactionCount: contact.transactionCount,
                    totalAmount: contact.totalTransactionAmount,
                    sentAmount: contact.sentAmount,
                    receivedAmount: contact.receivedAmount,
                    lastActivity: contact.updatedAt
                )
            }
            
            return statistics.sorted { $0.transactionCount > $1.transactionCount }
            
        } catch {
            print("❌ Failed to get contact statistics: \(error)")
            throw error
        }
    }
    
    /// Find or create contact by name
    func findOrCreateContact(name: String) async throws -> ContactModel {
        // First try to find existing contact
        if let existingContact = contacts.first(where: { $0.cachedName.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return existingContact
        }
        
        // Create new contact if not found
        let newContact = ContactModel(cachedName: name)
        return try await createContact(newContact)
    }
    
    // MARK: - Native Contact Integration
    
    /// Import a contact from native Contacts app
    func importFromNativeContact(nativeID: String, nativeData: ImportedContactData) async throws -> ContactModel {
        return try await taskManager.execute(key: "importNativeContact_\(nativeID)") {
            try await self.performImportFromNativeContact(nativeID: nativeID, nativeData: nativeData)
        }
    }
    
    private func performImportFromNativeContact(nativeID: String, nativeData: ImportedContactData) async throws -> ContactModel {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check if already imported
            let existingDescriptor = FetchDescriptor<PersistentContact>(
                predicate: #Predicate<PersistentContact> { $0.nativeContactID == nativeID }
            )
            let existingContacts = try modelContext.fetch(existingDescriptor)
            
            if let existingContact = existingContacts.first {
                print("ℹ️ Contact already imported from native: \(existingContact.cachedName)")
                // Return existing contact
                _ = existingContact.addresses
                return ContactModel(from: existingContact)
            }
            
            // Create new contact with native link
            let now = Date()
            let newContact = ContactModel(
                cachedName: nativeData.fullName,
                avatarData: nativeData.imageData,
                createdAt: now,
                updatedAt: now,
                nativeContactID: nativeData.identifier,
                lastSyncedFromNative: now
            )
            
            return try await createContact(newContact)
            
        } catch {
            print("❌ Failed to import from native contact: \(error)")
            self.error = "Failed to import contact: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Refresh a linked contact from native Contacts app
    func refreshFromNativeContact(contactID: UUID) async throws -> ContactModel {
        return try await taskManager.execute(key: "refreshNativeContact_\(contactID)") {
            try await self.performRefreshFromNativeContact(contactID: contactID)
        }
    }
    
    private func performRefreshFromNativeContact(contactID: UUID) async throws -> ContactModel {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Find existing persistent contact
            let descriptor = FetchDescriptor<PersistentContact>(
                predicate: #Predicate<PersistentContact> { $0.id == contactID }
            )
            let existingContacts = try modelContext.fetch(descriptor)
            
            guard let persistentContact = existingContacts.first else {
                throw ContactServiceError.contactNotFound(contactID)
            }
            
            guard let nativeID = persistentContact.nativeContactID else {
                throw ContactServiceError.custom("Contact is not linked to native Contacts")
            }
            
            // Fetch from native contacts
            let nativeService = NativeContactService()
            guard let nativeData = try await nativeService.extractContactData(identifier: nativeID) else {
                // Native contact was deleted - unlink but keep the contact
                print("⚠️ Native contact deleted, unlinking: \(persistentContact.cachedName)")
                persistentContact.nativeContactID = nil
                persistentContact.lastSyncedFromNative = nil
                persistentContact.touch()
                try modelContext.save()
                
                throw ContactServiceError.custom("Native contact no longer exists")
            }
            
            // Update contact with fresh data
            persistentContact.cachedName = nativeData.fullName
            if let imageData = nativeData.imageData {
                persistentContact.avatarData = imageData
            }
            persistentContact.lastSyncedFromNative = Date()
            persistentContact.touch()
            
            // Save changes
            try modelContext.save()
            
            // Update local array
            if let index = contacts.firstIndex(where: { $0.id == contactID }) {
                _ = persistentContact.addresses
                contacts[index] = ContactModel(from: persistentContact)
            }
            
            print("✅ Refreshed contact from native: \(persistentContact.cachedName)")
            
            _ = persistentContact.addresses
            return ContactModel(from: persistentContact)
            
        } catch {
            print("❌ Failed to refresh from native contact: \(error)")
            self.error = "Failed to refresh contact: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Unlink a contact from native Contacts (but keep the contact)
    func unlinkFromNativeContact(contactID: UUID) async throws {
        return try await taskManager.execute(key: "unlinkNativeContact_\(contactID)") {
            try await self.performUnlinkFromNativeContact(contactID: contactID)
        }
    }
    
    private func performUnlinkFromNativeContact(contactID: UUID) async throws {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Find existing persistent contact
            let descriptor = FetchDescriptor<PersistentContact>(
                predicate: #Predicate<PersistentContact> { $0.id == contactID }
            )
            let existingContacts = try modelContext.fetch(descriptor)
            
            guard let persistentContact = existingContacts.first else {
                throw ContactServiceError.contactNotFound(contactID)
            }
            
            guard persistentContact.nativeContactID != nil else {
                throw ContactServiceError.custom("Contact is not linked to native Contacts")
            }
            
            let contactName = persistentContact.cachedName
            
            // Clear native contact link
            persistentContact.nativeContactID = nil
            persistentContact.lastSyncedFromNative = nil
            persistentContact.touch()
            
            // Save changes
            try modelContext.save()
            
            // Update local array
            if let index = contacts.firstIndex(where: { $0.id == contactID }) {
                _ = persistentContact.addresses
                contacts[index] = ContactModel(from: persistentContact)
            }
            
            print("✅ Unlinked contact from native: \(contactName)")
            
        } catch {
            print("❌ Failed to unlink from native contact: \(error)")
            self.error = "Failed to unlink contact: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Link an existing contact to a native Contact
    func linkToNativeContact(contactID: UUID, nativeContactData: ImportedContactData) async throws -> ContactModel {
        return try await taskManager.execute(key: "linkNativeContact_\(contactID)") {
            try await self.performLinkToNativeContact(contactID: contactID, nativeContactData: nativeContactData)
        }
    }
    
    private func performLinkToNativeContact(contactID: UUID, nativeContactData: ImportedContactData) async throws -> ContactModel {
        guard let modelContext = modelContext else {
            throw ContactServiceError.noModelContext
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Find existing persistent contact
            let descriptor = FetchDescriptor<PersistentContact>(
                predicate: #Predicate<PersistentContact> { $0.id == contactID }
            )
            let existingContacts = try modelContext.fetch(descriptor)
            
            guard let persistentContact = existingContacts.first else {
                throw ContactServiceError.contactNotFound(contactID)
            }
            
            // Validate contact is not already linked
            if persistentContact.nativeContactID != nil {
                throw ContactServiceError.custom("Contact is already linked to native Contacts")
            }
            
            // Check if the native contact is already linked to another contact
            let nativeID = nativeContactData.identifier
            let checkDescriptor = FetchDescriptor<PersistentContact>(
                predicate: #Predicate<PersistentContact> { $0.nativeContactID == nativeID }
            )
            let linkedContacts = try modelContext.fetch(checkDescriptor)
            
            if !linkedContacts.isEmpty {
                throw ContactServiceError.custom("This native contact is already linked to another wallet contact")
            }
            
            let contactName = persistentContact.cachedName
            
            // Link to native contact (preserve local data, only establish link)
            persistentContact.nativeContactID = nativeContactData.identifier
            persistentContact.lastSyncedFromNative = Date()
            persistentContact.touch()
            
            // Save changes
            try modelContext.save()
            
            // Update local array
            if let index = contacts.firstIndex(where: { $0.id == contactID }) {
                _ = persistentContact.addresses
                contacts[index] = ContactModel(from: persistentContact)
            }
            
            print("✅ Linked contact '\(contactName)' to native contact '\(nativeContactData.fullName)'")
            
            _ = persistentContact.addresses
            return ContactModel(from: persistentContact)
            
        } catch {
            print("❌ Failed to link to native contact: \(error)")
            self.error = "Failed to link contact: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Check if a native contact ID is already imported
    func isNativeContactImported(_ nativeID: String) async -> Bool {
        guard let modelContext = modelContext else {
            return false
        }
        
        do {
            let descriptor = FetchDescriptor<PersistentContact>(
                predicate: #Predicate<PersistentContact> { $0.nativeContactID == nativeID }
            )
            let existingContacts = try modelContext.fetch(descriptor)
            return !existingContacts.isEmpty
        } catch {
            print("❌ Failed to check if native contact imported: \(error)")
            return false
        }
    }
    
    // MARK: - State Management
    
    /// Clear error state
    func clearError() {
        error = nil
    }
    
    /// Refresh contacts from storage
    func refreshContacts() async {
        await loadContacts()
    }
    
    // MARK: - Default Contacts Operations
    
    /// Create default contacts if none exist
    func createDefaultContactsIfNeeded() async {
        // Check if we should create default contacts
        // Only create if no contacts exist at all
        guard contactCount == 0 else {
            print("ℹ️ Contacts already exist, skipping default contact creation")
            return
        }
        
        await taskManager.execute(key: "createDefaultContacts") {
            await self.performCreateDefaultContacts()
        }
    }
    
    // Faucetto Signetto is a default contact for signet testing
    private func performCreateDefaultContacts() async {
        guard let modelContext = modelContext else {
            print("❌ Cannot create default contacts: no model context")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            var avatarData: Data?
            
            #if os(iOS)
            if let image = UIImage(named: "faucetto-signetto"),
               let imageData = image.pngData() {
                avatarData = imageData
            }
            #elseif os(macOS)
            if let image = NSImage(named: "faucetto-signetto"),
               let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
               let bitmapRep = NSBitmapImageRep(cgImage: cgImage),
               let imageData = bitmapRep.representation(using: .png, properties: [:]) {
                avatarData = imageData
            }
            #endif
            
            // Create "Faucetto Signetto" system contact
            let defaultContact = ContactModel(
                cachedName: "Faucetto Signetto",
                notes: "I'll help you test Arké. You can request free test bitcoin from me, and send me some back.",
                avatarData: avatarData,
                contactType: .faucet
            )
            
            // Create the contact
            let persistentContact = defaultContact.toPersistentContact()
            modelContext.insert(persistentContact)
            
            // Save to get the contact persisted before adding addresses
            try modelContext.save()
            
            print("✅ Created default system contact: \(defaultContact.cachedName)")
            
            // Now add addresses using ContactAddressService
            // We need to get the service from the ServiceContainer
            let contactAddressService = ServiceContainer.shared.contactAddressService
            
            // Placeholder Ark address (signet format)
            // This is a valid signet Ark address format - replace with actual faucet address
            let arkAddress = "tark1pem36wcfzqqpsp9x4spq03lgxz0ypsh36553g5ruj8te8w7wgehx7h4a58q2emxezqyphvs9qmw3et6eutxx6netps535rdr8c5mjv2703sc50e96s4f9qygx5rkzk"
            
            // Placeholder Bitcoin signet address (tb1q format)
            let onchainAddress = "tb1ptg6t5dqn0dq6z2sj56zkakzfrvynr38pa4lhdkhuq0tpc9wdmdtqd53lwz"
            
            // Add Ark address (primary)
            do {
                let arkAddressModel = try await contactAddressService.validateAndCreateAddress(
                    arkAddress,
                    for: persistentContact.id,
                    label: "Ark Address",
                    isPrimary: true
                )
                print("✅ Added primary Ark address to contact: \(arkAddressModel.shortAddress)")
            } catch {
                print("⚠️ Failed to add Ark address to default contact: \(error)")
                // Continue even if address creation fails
            }
            
            // Add onchain address
            do {
                let onchainAddressModel = try await contactAddressService.validateAndCreateAddress(
                    onchainAddress,
                    for: persistentContact.id,
                    label: "Onchain Address",
                    isPrimary: false
                )
                print("✅ Added onchain address to contact: \(onchainAddressModel.shortAddress)")
            } catch {
                print("⚠️ Failed to add onchain address to default contact: \(error)")
                // Continue even if address creation fails
            }
            
            // Reload contacts to update the in-memory cache with addresses
            await loadContacts()
            
            print("✅ Default contact setup complete")
            
        } catch {
            print("❌ Failed to create default contacts: \(error)")
            self.error = "Failed to create default contacts: \(error)"
        }
    }
    
    // MARK: - Address Integration
    
    /// Load contacts with their addresses included
    func loadContactsWithAddresses() async {
        guard let modelContext = modelContext else {
            print("⚠️ No model context available for loading contacts")
            return
        }
        
        do {
            var descriptor = FetchDescriptor<PersistentContact>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            // Prefetch the addresses relationship to avoid lazy loading issues
            descriptor.relationshipKeyPathsForPrefetching = [\.addresses]
            
            let persistentContacts = try modelContext.fetch(descriptor)
            
            // Convert to UI models (addresses will now be included)
            self.contacts = persistentContacts.map { ContactModel(from: $0) }
            
            print("👥 Loaded \(contacts.count) contacts with addresses from SwiftData")
            
        } catch {
            print("❌ Failed to load contacts with addresses: \(error)")
            self.error = "Failed to load contacts with addresses: \(error)"
        }
    }
    
    /// Get addresses for a specific contact
    func getAddresses(for contactId: UUID) -> [ContactAddressModel] {
        return contacts.first { $0.id == contactId }?.addresses ?? []
    }
    
    /// Update a contact's addresses in the local cache
    func updateContactAddresses(_ contactId: UUID, addresses: [ContactAddressModel]) {
        guard let contactIndex = contacts.firstIndex(where: { $0.id == contactId }) else { return }
        
        let updatedContact = ContactModel(
            id: contacts[contactIndex].id,
            cachedName: contacts[contactIndex].cachedName,
            notes: contacts[contactIndex].notes,
            avatarData: contacts[contactIndex].avatarData,
            createdAt: contacts[contactIndex].createdAt,
            updatedAt: Date(),
            contactType: contacts[contactIndex].contactType,  // Preserve contact type
            nativeContactID: contacts[contactIndex].nativeContactID,  // Preserve native contact link
            lastSyncedFromNative: contacts[contactIndex].lastSyncedFromNative,  // Preserve sync date
            transactionCount: contacts[contactIndex].transactionCount,
            sentAmount: contacts[contactIndex].sentAmount,
            receivedAmount: contacts[contactIndex].receivedAmount,
            addresses: addresses
        )
        
        contacts[contactIndex] = updatedContact
    }
    
    // MARK: - Bulk Operations
    
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

// MARK: - Error Types

enum ContactServiceError: LocalizedError {
    case noModelContext
    case contactNotFound(UUID)
    case transactionNotFound(String)
    case contactAlreadyExists(String)
    case contactAlreadyAssigned
    case assignmentNotFound
    case invalidAddress(String)
    case duplicateAddress(String)
    case addressNotFound(UUID)
    case multiplePrimaryAddresses(UUID)
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "Database context not available"
        case .contactNotFound(let id):
            return "Contact with ID \(id) not found"
        case .transactionNotFound(let txid):
            return "Transaction with ID \(txid) not found"
        case .contactAlreadyExists(let name):
            return "Contact '\(name)' already exists"
        case .contactAlreadyAssigned:
            return "Contact is already assigned to this transaction"
        case .assignmentNotFound:
            return "Contact assignment not found"
        case .invalidAddress(let address):
            return "Invalid address format: \(address)"
        case .duplicateAddress(let address):
            return "Address already exists: \(address)"
        case .addressNotFound(let id):
            return "Address with ID \(id) not found"
        case .multiplePrimaryAddresses(let contactId):
            return "Multiple primary addresses found for contact \(contactId)"
        case .custom(let message):
            return message
        }
    }
}

// MARK: - Supporting Models

struct ContactStatistic {
    let contactId: UUID
    let contactName: String
    let transactionCount: Int
    let totalAmount: Int        // Net total (received - sent)
    let sentAmount: Int         // Sum of sent transactions
    let receivedAmount: Int     // Sum of received transactions
    let lastActivity: Date
    
    // Computed properties for display
    var formattedTotalAmount: String {
        BitcoinFormatter.shared.formatAccountingAmount(totalAmount, transactionType: totalAmount >= 0 ? .received : .sent)
    }
    
    var formattedSentAmount: String {
        BitcoinFormatter.shared.formatAccountingAmount(sentAmount, transactionType: .sent)
    }
    
    var formattedReceivedAmount: String {
        BitcoinFormatter.shared.formatAccountingAmount(receivedAmount, transactionType: .received)
    }
    
    var formattedLastActivity: String {
        RelativeDateTimeFormatter().localizedString(for: lastActivity, relativeTo: Date())
    }
}
