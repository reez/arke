//
//  ContactsView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI

struct ContactsView: View {
    @Environment(WalletManager.self) private var walletManager
    
    @State private var showingNewContactEditor = false
    @State private var editingContact: ContactModel?
    
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
            .padding(.vertical, 20)
            .padding(.horizontal, 30)
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
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(walletManager.alphabeticalContacts) { contact in
                ContactRow(
                    contact: contact,
                    onEdit: {
                        print("🔧 ContactsView: Edit button pressed for contact: \(contact.displayName) (ID: \(contact.id))")
                        editingContact = contact
                        print("🔧 ContactsView: Set editingContact to: \(editingContact?.displayName ?? "nil") (ID: \(editingContact?.id.uuidString ?? "nil"))")
                    },
                    onDelete: {
                        Task {
                            await deleteContact(contact)
                        }
                    }
                )
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
    
    private func createNewContact(_ contact: ContactModel) async {
        do {
            let createdContact = try await walletManager.createContact(contact)
            print("✅ Successfully created contact: \(createdContact.displayName)")
        } catch {
            print("❌ Failed to create contact: \(error)")
        }
    }
    
    private func updateContact(_ contact: ContactModel) async {
        do {
            try await walletManager.updateContact(contact)
            print("✅ Successfully updated contact: \(contact.displayName)")
        } catch {
            print("❌ Failed to update contact: \(error)")
        }
    }
    
    private func deleteContact(_ contact: ContactModel) async {
        do {
            try await walletManager.deleteContact(contact.id)
            print("✅ Successfully deleted contact: \(contact.displayName)")
        } catch {
            print("❌ Failed to delete contact: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    ContactsView()
        .environment(WalletManager(useMock: true))
        .frame(width: 800, height: 600)
}


