//
//  ContactsView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI

struct ContactsView: View {
    @Environment(WalletManager.self) private var walletManager
    
    @Binding var selectedContact: ContactModel?
    
    let onSendToAddress: ((ContactAddressModel, ContactModel) -> Void)?
    let onNavigateToActivity: ((ContactModel) -> Void)?
    
    @State private var showingNewContactEditor = false
    @State private var editingContact: ContactModel?
    @State private var contactsWithStatistics: [ContactModel] = []
    @State private var isLoadingStatistics = false
    
    init(
        selectedContact: Binding<ContactModel?>,
        onNavigateToActivity: ((ContactModel) -> Void)? = nil,
        onSendToAddress: ((ContactAddressModel, ContactModel) -> Void)? = nil
    ) {
        self._selectedContact = selectedContact
        self.onNavigateToActivity = onNavigateToActivity
        self.onSendToAddress = onSendToAddress
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Content
                if walletManager.hasContacts {
                    contactsSection
                } else {
                    emptyStateView
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Contact") {
                        showingNewContactEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            Task {
                await loadContactsWithStatistics()
            }
        }
        .onChange(of: walletManager.alphabeticalContacts) { _, _ in
            Task {
                await loadContactsWithStatistics()
            }
        }
        // Sheet presentation for new contact
        .sheet(isPresented: $showingNewContactEditor) {
            ContactEditor(
                onSave: { contact in
                    Task {
                        await createNewContact(contact)
                    }
                    showingNewContactEditor = false
                },
                onCancel: {
                    showingNewContactEditor = false
                }
            )
            .environment(walletManager)
            .environment(walletManager.contactServiceForEnvironment)
            .frame(width: 500, height: 700)
        }
        // Sheet presentation for editing contact using item-based approach
        .sheet(item: $editingContact) { contact in
            print("🔧 ContactsView: Creating ContactEditor sheet with contact: \(contact.displayName) (ID: \(contact.id))")
            return ContactEditor(
                editingContact: contact,
                onSave: { updatedContact in
                    print("🔧 ContactsView: ContactEditor onSave called with contact: \(updatedContact.displayName) (ID: \(updatedContact.id))")
                    Task {
                        await updateContact(updatedContact)
                    }
                    editingContact = nil
                },
                onCancel: {
                    print("🔧 ContactsView: ContactEditor onCancel called")
                    editingContact = nil
                }
            )
            .environment(walletManager)
            .environment(walletManager.contactServiceForEnvironment)
            .frame(width: 500, height: 700)
            .onAppear {
                print("🔧 ContactsView: ContactEditor sheet appeared with contact: \(contact.displayName) (ID: \(contact.id))")
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var contactsSection: some View {
        if isLoadingStatistics {
            ProgressView("Loading contact statistics...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(contactsWithStatistics.isEmpty ? walletManager.alphabeticalContacts : contactsWithStatistics) { contact in
                    ContactRow(
                        contact: contact,
                        onTransactionCountTap: onNavigateToActivity,
                        onSendTap: { contact in
                            if let primaryAddress = contact.primaryAddress {
                                onSendToAddress?(primaryAddress, contact)
                            }
                        },
                        selectedContact: $selectedContact
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text("No Contacts Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add contacts to organize your transactions and make sending easier")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Button("Create Your First Contact") {
                showingNewContactEditor = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: 400)
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadContactsWithStatistics() async {
        isLoadingStatistics = true
        defer { isLoadingStatistics = false }
        
        do {
            let statistics = try await walletManager.getContactStatistics()
            let statisticsDict = Dictionary(uniqueKeysWithValues: statistics.map { ($0.contactId, $0) })
            
            let enrichedContacts = walletManager.alphabeticalContacts.map { contact in
                if let stat = statisticsDict[contact.id] {
                    return ContactModel(
                        id: contact.id,
                        cachedName: contact.cachedName,
                        notes: contact.notes,
                        avatarData: contact.avatarData,
                        createdAt: contact.createdAt,
                        updatedAt: contact.updatedAt,
                        transactionCount: stat.transactionCount,
                        sentAmount: stat.sentAmount,
                        receivedAmount: stat.receivedAmount,
                        addresses: contact.addresses  // ✅ Include addresses!
                    )
                } else {
                    return ContactModel(
                        id: contact.id,
                        cachedName: contact.cachedName,
                        notes: contact.notes,
                        avatarData: contact.avatarData,
                        createdAt: contact.createdAt,
                        updatedAt: contact.updatedAt,
                        transactionCount: 0,
                        sentAmount: 0,
                        receivedAmount: 0,
                        addresses: contact.addresses  // ✅ Include addresses!
                    )
                }
            }
            
            contactsWithStatistics = enrichedContacts
        } catch {
            print("❌ Failed to load contact statistics: \(error)")
            // Fall back to contacts without statistics
            contactsWithStatistics = walletManager.alphabeticalContacts
        }
    }
    
    private func createNewContact(_ contact: ContactModel) async {
        do {
            let createdContact = try await walletManager.createContact(contact)
            print("✅ Successfully created contact: \(createdContact.displayName)")
            await loadContactsWithStatistics()
        } catch {
            print("❌ Failed to create contact: \(error)")
        }
    }
    
    private func updateContact(_ contact: ContactModel) async {
        do {
            try await walletManager.updateContact(contact)
            print("✅ Successfully updated contact: \(contact.displayName)")
            await loadContactsWithStatistics()
        } catch {
            print("❌ Failed to update contact: \(error)")
        }
    }
    
    private func deleteContact(_ contact: ContactModel) async {
        do {
            try await walletManager.deleteContact(contact.id)
            print("✅ Successfully deleted contact: \(contact.displayName)")
            await loadContactsWithStatistics()
        } catch {
            print("❌ Failed to delete contact: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    ContactsView(selectedContact: .constant(nil))
        .environment(WalletManager(useMock: true))
        .frame(width: 800, height: 600)
}


