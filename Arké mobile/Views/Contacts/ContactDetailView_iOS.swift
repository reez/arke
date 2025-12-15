//
//  ContactDetailView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct ContactDetailView_iOS: View {
    let contact: ContactModel
    let onSendToAddress: (ContactAddressModel) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onNavigateToActivity: (ContactModel) -> Void
    
    @Environment(\.serviceContainer) private var serviceContainer
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModel
    
    @State private var viewModel: ContactDetailViewModel?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        contentView
            .task(id: contact.id) {
                // Initialize ViewModel as soon as environment is available
                viewModel = ContactDetailViewModel(
                    contact: contact,
                    serviceContainer: serviceContainer
                )
            }
    }
    
    @ViewBuilder
    private var contentView: some View {
        listContent
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        onEdit()
                    }
                }
            }
            .confirmationDialog(
                "Delete Contact",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(contact.displayName)?")
            }
            .sheet(isPresented: contactImportSheetBinding) {
                contactImportSheetView
            }
            .alert("Contact Link", isPresented: alertBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                if let alertMessage = viewModel?.alertMessage {
                    Text(alertMessage)
                }
            }
    }
    
    private var listContent: some View {
        List {
            headerSection
            
            if viewModel?.hasTransactionData == true {
                transactionSummarySection
            }
            
            addressesSection
            
            if let notes = contact.notes, !notes.isEmpty {
                notesSection(notes)
            }
            
            if let viewModel {
                contactDetailsSection(viewModel: viewModel)
            }
            
            managementSection
        }
    }
    
    private var headerSection: some View {
        Section {
            ContactHeaderView(contact: contact)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .listRowBackground(Color.clear)
    }
    
    private var transactionSummarySection: some View {
        Section {
            ContactTransactionSummaryView(
                contact: contact,
                onViewActivity: {
                    onNavigateToActivity(contact)
                }
            )
        }
    }
    
    private var addressesSection: some View {
        Section {
            ContactAddressesSection(
                contact: contact,
                onSendToAddress: onSendToAddress
            )
        }
    }
    
    private func notesSection(_ notes: String) -> some View {
        Section("Notes") {
            Text(notes)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    private func contactDetailsSection(viewModel: ContactDetailViewModel) -> some View {
        Section {
            ContactDetailsDisclosure(
                contact: contact,
                onRefreshFromNativeContact: {
                    Task {
                        await viewModel.handleRefreshFromNativeContact()
                    }
                },
                onUnlinkNativeContact: {
                    Task {
                        await viewModel.handleUnlinkFromNativeContact()
                    }
                },
                onLinkNativeContact: {
                    viewModel.handleLinkToNativeContact()
                }
            )
        }
    }
    
    private var managementSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Contact", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var contactImportSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showingContactImport ?? false },
            set: { if let viewModel { viewModel.showingContactImport = $0 } }
        )
    }
    
    private var contactImportSheetView: some View {
        NavigationStack {
            ContactImportSheet(
                onSelect: { importedData in
                    Task {
                        await viewModel?.handleContactImportSelection(importedData)
                    }
                    viewModel?.showingContactImport = false
                },
                onCancel: {
                    viewModel?.showingContactImport = false
                }
            )
        }
        .presentationDetents([.medium, .large])
    }
    
    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showingAlert ?? false },
            set: { if let viewModel { viewModel.showingAlert = $0 } }
        )
    }
}

// MARK: - Previews

#Preview("Standard Contact") {
    NavigationStack {
        ContactDetailView_iOS(
            contact: ContactModel(
                cachedName: "John Doe",
                notes: "My Bitcoin contact",
                transactionCount: 5,
                sentAmount: 25000,
                receivedAmount: 75000
            ),
            onSendToAddress: { _ in print("Send to address") },
            onEdit: { print("Edit tapped") },
            onDelete: { print("Delete tapped") },
            onNavigateToActivity: { contact in print("Navigate to activity for \(contact.displayName)") }
        )
    }
    .environment(WalletManager(useMock: true))
}

#Preview("Linked to Native Contact") {
    NavigationStack {
        ContactDetailView_iOS(
            contact: ContactModel(
                cachedName: "Jane Smith",
                notes: "Linked to Contacts.app",
                nativeContactID: "12345",
                lastSyncedFromNative: Date().addingTimeInterval(-7200),
                transactionCount: 12,
                sentAmount: 50000,
                receivedAmount: 125000
            ),
            onSendToAddress: { _ in print("Send to address") },
            onEdit: { print("Edit tapped") },
            onDelete: { print("Delete tapped") },
            onNavigateToActivity: { contact in print("Navigate to activity for \(contact.displayName)") }
        )
    }
    .environment(WalletManager(useMock: true))
}

#Preview("No Transaction Data") {
    NavigationStack {
        ContactDetailView_iOS(
            contact: ContactModel(
                cachedName: "New Contact",
                notes: "Just added, no transactions yet"
            ),
            onSendToAddress: { _ in print("Send to address") },
            onEdit: { print("Edit tapped") },
            onDelete: { print("Delete tapped") },
            onNavigateToActivity: { contact in print("Navigate to activity for \(contact.displayName)") }
        )
    }
    .environment(WalletManager(useMock: true))
}
