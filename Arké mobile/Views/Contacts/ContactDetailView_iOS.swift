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
    
    // MARK: - ViewModel
    
    @State private var viewModel: ContactDetailViewModel?
    
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
        List {
            // Header Section
            Section {
                ContactHeaderView(contact: contact)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }
            .listRowBackground(Color.clear)
            
            // Transaction Statistics Summary
            if viewModel?.hasTransactionData == true {
                Section {
                    ContactTransactionSummaryView(
                        contact: contact,
                        onViewActivity: {
                            onNavigateToActivity(contact)
                        }
                    )
                }
            }
            
            // Addresses Section
            Section("Addresses") {
                ContactAddressesSection(
                    contact: contact,
                    onSendToAddress: onSendToAddress
                )
            }
            
            // Notes Section
            if let notes = contact.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            
            // Contact Information Section
            if let viewModel {
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
                            Task {
                                await viewModel.handleLinkToNativeContact()
                            }
                        }
                    )
                }
            }
        }
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", action: onEdit)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.showingContactImport ?? false },
            set: { if let viewModel { viewModel.showingContactImport = $0 } }
        )) {
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
        .alert("Contact Link", isPresented: Binding(
            get: { viewModel?.showingAlert ?? false },
            set: { if let viewModel { viewModel.showingAlert = $0 } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let alertMessage = viewModel?.alertMessage {
                Text(alertMessage)
            }
        }
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
