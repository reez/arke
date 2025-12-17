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
    @State private var pendingContact: ContactModel?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var previewAutoAssignCount: Int = 0
    @State private var previewAddress: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Preview of changes (shown when selection differs from current)
            if let pendingContact = pendingContact,
               pendingContact.id != currentAssignedContact?.id {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("This will:")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        if currentAssignedContact != nil {
                            Label("Replace '\(currentAssignedContact!.displayName)' with '\(pendingContact.displayName)'", 
                                  systemImage: "arrow.left.arrow.right.circle")
                        } else {
                            Label("Assign '\(pendingContact.displayName)' to this transaction", 
                                  systemImage: "checkmark.circle")
                        }
                        
                        if let address = previewAddress {
                            Label("Save address \(shortAddress(address)) to contact", 
                                  systemImage: "plus.circle")
                        }
                        
                        if previewAutoAssignCount > 0 {
                            Label("Auto-assign to \(previewAutoAssignCount) other transaction\(previewAutoAssignCount == 1 ? "" : "s") with this address", 
                                  systemImage: "arrow.triangle.branch")
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.vertical, 8)
            } else if pendingContact == nil && currentAssignedContact != nil {
                // Show removal preview
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("This will:")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Remove '\(currentAssignedContact!.displayName)' from this transaction only", 
                              systemImage: "xmark.circle")
                            .foregroundColor(.orange)
                        
                        // Show info about other transactions if they exist
                        if previewAutoAssignCount > 0 {
                            Label("\(previewAutoAssignCount) other transaction\(previewAutoAssignCount == 1 ? "" : "s") with this address will remain assigned", 
                                  systemImage: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        Label("The address will stay in '\(currentAssignedContact!.displayName)'s contact card", 
                              systemImage: "info.circle")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .font(.callout)
                    .padding(.leading, 28)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Existing Contacts Section
                    if walletManager.hasContacts {
                        LazyVStack(spacing: 12) {
                            ForEach(walletManager.alphabeticalContacts) { contact in
                                ContactChip_Selectable(
                                    contact: contact,
                                    isSelected: Binding(
                                        get: { 
                                            // Show as selected if it's pending OR currently assigned (when no pending)
                                            if let pending = pendingContact {
                                                return pending.id == contact.id
                                            } else {
                                                return selectedContactId == contact.id
                                            }
                                        },
                                        set: { isSelected in
                                            if isSelected {
                                                pendingContact = contact
                                                selectedContactId = contact.id
                                                Task {
                                                    await updatePreview(for: contact)
                                                }
                                            } else {
                                                pendingContact = nil
                                                selectedContactId = currentAssignedContact?.id
                                                previewAutoAssignCount = 0
                                                previewAddress = nil
                                            }
                                        }
                                    )
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            // Error display
            if let errorMessage = errorMessage {
                ErrorView(errorMessage: errorMessage)
            }
        }
        .disabled(isLoading)
        .toolbar {
            /*
            ToolbarItem(placement: .cancellationAction) {
                if pendingContact != nil || currentAssignedContact != nil {
                    Button {
                        pendingContact = nil
                        selectedContactId = currentAssignedContact?.id
                        previewAutoAssignCount = 0
                        previewAddress = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }
            }
            */
            
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    showingContactEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Contact")
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        await applyChanges()
                    }
                } label: {
                    Image(systemName: "checkmark")
                }
                .accessibilityLabel("Apply")
                .disabled(pendingContact?.id == currentAssignedContact?.id && currentAssignedContact != nil)
            }
        }
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
            #if os(macOS)
            .frame(width: 500, height: 500)
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    private func updatePreview(for contact: ContactModel) async {
        // Get the transaction to find its address and count matches
        let allTransactions = walletManager.transactions
        if let transaction = allTransactions.first(where: { $0.txid == transactionId }),
           let address = transaction.address {
            
            await MainActor.run {
                previewAddress = address
                
                // Count how many OTHER transactions would be affected
                let normalizedAddress = address.lowercased()
                previewAutoAssignCount = allTransactions.filter { tx in
                    guard let txAddress = tx.address else { return false }
                    return txAddress.lowercased() == normalizedAddress && tx.txid != transactionId
                }.count
            }
        }
    }
    
    private func applyChanges() async {
        if let pending = pendingContact {
            await assignContact(pending)
        } else if currentAssignedContact != nil {
            await removeAssignment()
        }
        
        // Dismiss after successful application (or error shown)
        if errorMessage == nil {
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func shortAddress(_ address: String) -> String {
        guard address.count > 16 else { return address }
        let start = address.prefix(8)
        let end = address.suffix(8)
        return "\(start)...\(end)"
    }
    
    private func loadCurrentAssignment() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let contacts = try await walletManager.getTransactionContacts(transactionId)
            await MainActor.run {
                currentAssignedContact = contacts.first
                selectedContactId = contacts.first?.id
                pendingContact = contacts.first
                isLoading = false
            }
            
            // Load preview data for the current assignment
            if let currentContact = contacts.first {
                await updatePreview(for: currentContact)
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
            
            // Assign new contact with address learning and bulk assignment
            _ = try await walletManager.assignContactWithAddressLearning(contact.id, to: transactionId)
            
            await MainActor.run {
                currentAssignedContact = contact
                pendingContact = contact
                isLoading = false
            }
            
            await onAssignContact(contact)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to assign contact: \(error.localizedDescription)"
                selectedContactId = currentAssignedContact?.id
                pendingContact = currentAssignedContact
                isLoading = false
            }
        }
    }
    
    private func removeAssignment() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Remove contact from this transaction only
            // Note: This does NOT remove the contact from other transactions
            // or remove the address from the contact's address book
            try await walletManager.removeContactAssignment(from: transactionId)
            
            await MainActor.run {
                currentAssignedContact = nil
                selectedContactId = nil
                pendingContact = nil
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
            
            // Assign new contact with address learning and bulk assignment
            _ = try await walletManager.assignContactWithAddressLearning(createdContact.id, to: transactionId)
            
            await MainActor.run {
                currentAssignedContact = createdContact
                selectedContactId = createdContact.id
                pendingContact = createdContact
                isLoading = false
            }
            
            await onAssignContact(createdContact)
            
            // Auto-dismiss after creating and assigning new contact
            await MainActor.run {
                dismiss()
            }
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
