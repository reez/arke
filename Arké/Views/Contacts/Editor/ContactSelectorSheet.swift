//
//  ContactSelectorSheet.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/04/25.
//

import SwiftUI

struct ContactSelectorSheet: View {
    @Binding var selectedContactId: UUID?
    let transactionId: String
    let onAssignContact: (ContactModel?) async -> Void
    
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingContactEditor = false
    @State private var currentAssignedContact: ContactModel?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Assign Contact")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if currentAssignedContact != nil {
                    Button {
                        Task {
                            await removeAssignment()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                
                Button("New contact") {
                    showingContactEditor = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Current Assignment Section
                    /*
                    if let currentContact = currentAssignedContact {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Currently Assigned")
                                .font(.headline)
                            
                            ContactAssignmentCard(
                                contact: currentContact,
                                onRemove: {
                                    Task {
                                        await removeAssignment()
                                    }
                                }
                            )
                        }
                    }
                    */
                    
                    /*
                    // Create New Contact Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Create New Contact")
                            .font(.headline)
                        
                        Button(action: {
                            showingContactEditor = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                
                                Text("Create New Contact")
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    */
                    
                    // Existing Contacts Section
                    if walletManager.hasContacts {
                        LazyVStack(spacing: 12) {
                            ForEach(walletManager.alphabeticalContacts) { contact in
                                ContactChip_Selectable(
                                    contact: contact,
                                    isSelected: Binding(
                                        get: { selectedContactId == contact.id },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedContactId = contact.id
                                                Task {
                                                    await assignContact(contact)
                                                }
                                            } else {
                                                selectedContactId = nil
                                                Task {
                                                    await removeAssignment()
                                                }
                                            }
                                        }
                                    )
                                )
                            }
                        }
                    }
                    
                    // No Contact Option
                    /*
                    if currentAssignedContact != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Remove Assignment")
                                .font(.headline)
                            
                            Button(action: {
                                Task {
                                    await removeAssignment()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                    
                                    Text("No Contact")
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    */
                }
                .padding()
            }
            
            // Error display
            if let errorMessage = errorMessage {
                ErrorView(errorMessage: errorMessage)
            }
        }
        .disabled(isLoading)
        .task {
            await loadCurrentAssignment()
        }
        .sheet(isPresented: $showingContactEditor) {
            ContactEditor(
                editingContact: nil,
                onSave: { contact in
                    Task {
                        await createAndAssignContact(contact)
                    }
                    showingContactEditor = false
                },
                onCancel: {
                    showingContactEditor = false
                }
            )
            .environment(walletManager)
            .environment(walletManager.contactServiceForEnvironment)
            .frame(width: 500, height: 600)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCurrentAssignment() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let contacts = try await walletManager.getTransactionContacts(transactionId)
            await MainActor.run {
                currentAssignedContact = contacts.first
                selectedContactId = contacts.first?.id
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load current assignment: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func assignContact(_ contact: ContactModel) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Remove existing assignment first if there is one
            if currentAssignedContact != nil {
                try await walletManager.removeContactAssignment(from: transactionId)
            }
            
            // Assign new contact
            try await walletManager.assignContact(contact.id, to: transactionId)
            
            await MainActor.run {
                currentAssignedContact = contact
                isLoading = false
            }
            
            await onAssignContact(contact)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to assign contact: \(error.localizedDescription)"
                selectedContactId = currentAssignedContact?.id // Revert selection
                isLoading = false
            }
        }
    }
    
    private func removeAssignment() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await walletManager.removeContactAssignment(from: transactionId)
            
            await MainActor.run {
                currentAssignedContact = nil
                selectedContactId = nil
                isLoading = false
            }
            
            await onAssignContact(nil)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to remove assignment: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func createAndAssignContact(_ contact: ContactModel) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let createdContact = try await walletManager.createContact(contact)
            
            // Remove existing assignment first if there is one
            if currentAssignedContact != nil {
                try await walletManager.removeContactAssignment(from: transactionId)
            }
            
            // Assign new contact
            try await walletManager.assignContact(createdContact.id, to: transactionId)
            
            await MainActor.run {
                currentAssignedContact = createdContact
                selectedContactId = createdContact.id
                isLoading = false
            }
            
            await onAssignContact(createdContact)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create and assign contact: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

#Preview {
    // Create a mock wallet manager for the preview
    @Previewable @State var selectedContactId: UUID? = nil
    
    // Mock WalletManager for preview
    let mockWalletManager = WalletManager()
    
    ContactSelectorSheet(
        selectedContactId: $selectedContactId,
        transactionId: "sample_transaction_id",
        onAssignContact: { contact in
            if let contact = contact {
                print("Assigned contact: \(contact.displayName)")
            } else {
                print("Removed contact assignment")
            }
        }
    )
    .environment(mockWalletManager)
    .frame(width: 600, height: 700)
}
