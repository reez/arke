//
//  ContactsView_iOS.swift
//  Arké
//
//  Created by Assistant on 12/4/25.
//

import SwiftUI
import UIKit

// MARK: - iOS Contact Management

/// Unified contacts view that handles both selection and management
/// Presents as a sheet with search, add, edit, delete, and send functionality
struct ContactsView_iOS: View {
    /// Called when user selects a contact to send to
    let onSelectContact: (ContactModel, ContactAddressModel) -> Void
    
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: ContactsViewModel?
    @State private var showingContactDetail: ContactModel?
    
    init(onSelectContact: @escaping (ContactModel, ContactAddressModel) -> Void) {
        self.onSelectContact = onSelectContact
    }
    
    var body: some View {
        Group {
            if let viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .task {
                        await initializeViewModel()
                    }
            }
        }
    }
    
    private func initializeViewModel() async {
        let vm = ContactsViewModel(walletManager: walletManager)
        await vm.loadContactsWithStatistics()
        viewModel = vm
    }
}

// MARK: - Main Content

extension ContactsView_iOS {
    @ViewBuilder
    private func contentView(viewModel: ContactsViewModel) -> some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            Group {
                if viewModel.filteredContacts.isEmpty && !viewModel.searchText.isEmpty {
                    noSearchResultsView(viewModel: viewModel)
                } else if viewModel.contacts.isEmpty {
                    emptyStateView(viewModel: viewModel)
                } else {
                    contactListView(viewModel: viewModel)
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search contacts")
            .toolbar {
                toolbarContent(viewModel: viewModel)
            }
            .refreshable {
                await viewModel.loadContactsWithStatistics()
            }
            .sheet(isPresented: $viewModel.showingNewContactEditor) {
                contactEditorSheet(viewModel: viewModel)
            }
            .sheet(item: $viewModel.editingContact) { contact in
                contactEditorSheet(viewModel: viewModel, editing: contact)
            }
            .navigationDestination(item: $showingContactDetail) { contact in
                contactDetailView(contact: contact, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Contact List

extension ContactsView_iOS {
    @ViewBuilder
    private func contactListView(viewModel: ContactsViewModel) -> some View {
        List {
            ForEach(viewModel.filteredContacts) { contact in
                contactRowButton(contact: contact)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    @ViewBuilder
    private func contactRowButton(contact: ContactModel) -> some View {
        Button {
            // Tap row = navigate to detail
            showingContactDetail = contact
        } label: {
            ContactRow_iOS(
                contact: contact,
                showStatistics: true,
                sendButtonStyle: .icon,
                onSendTap: {
                    handleQuickSend(contact: contact)
                }
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            swipeActionsForContact(contact)
        }
    }
    
    @ViewBuilder
    private func swipeActionsForContact(_ contact: ContactModel) -> some View {
        Button(role: .destructive) {
            Task {
                guard let viewModel else { return }
                await viewModel.deleteContact(contact)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
        
        Button {
            viewModel?.showEditContactEditor(for: contact)
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.blue)
    }
}

// MARK: - Actions

extension ContactsView_iOS {
    private func handleQuickSend(contact: ContactModel) {
        guard let primaryAddress = contact.primaryAddress else {
            print("⚠️ [ContactsView_iOS] No primary address for contact: \(contact.displayName)")
            return
        }
        
        // Haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        
        print("📤 [ContactsView_iOS] Quick send to \(contact.displayName) at \(primaryAddress.address)")
        
        onSelectContact(contact, primaryAddress)
        dismiss()
    }
}

// MARK: - Toolbar

extension ContactsView_iOS {
    @ToolbarContentBuilder
    private func toolbarContent(viewModel: ContactsViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button {
                viewModel.showNewContactEditor()
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}

// MARK: - Empty States

extension ContactsView_iOS {
    @ViewBuilder
    private func emptyStateView(viewModel: ContactsViewModel) -> some View {
        ContentUnavailableView {
            Label("No Contacts", systemImage: "person.2.circle")
        } description: {
            Text("Add contacts to organize your transactions and make sending easier")
        } actions: {
            Button("Create Your First Contact") {
                viewModel.showNewContactEditor()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    @ViewBuilder
    private func noSearchResultsView(viewModel: ContactsViewModel) -> some View {
        ContentUnavailableView.search(text: viewModel.searchText)
    }
}

// MARK: - Sheets

extension ContactsView_iOS {
    @ViewBuilder
    private func contactEditorSheet(
        viewModel: ContactsViewModel,
        editing contact: ContactModel? = nil
    ) -> some View {
        NavigationStack {
            ContactEditor(
                editingContact: contact,
                onSave: { updatedContact in
                    Task {
                        if contact != nil {
                            await viewModel.updateContact(updatedContact)
                        } else {
                            await viewModel.createNewContact(updatedContact)
                        }
                    }
                },
                onCancel: {
                    if contact != nil {
                        viewModel.hideEditContactEditor()
                    } else {
                        viewModel.hideNewContactEditor()
                    }
                }
            )
            .environment(walletManager.contactServiceForEnvironment)
        }
    }
    
    @ViewBuilder
    private func contactDetailView(
        contact: ContactModel,
        viewModel: ContactsViewModel
    ) -> some View {
        ContactDetailView_iOS(
            contact: contact,
            onSendToAddress: { address in
                print("📤 [ContactsView_iOS] Send to specific address: \(address.address)")
                onSelectContact(contact, address)
                dismiss()
            },
            onEdit: {
                viewModel.showEditContactEditor(for: contact)
            },
            onDelete: {
                Task {
                    await viewModel.deleteContact(contact)
                    showingContactDetail = nil
                }
            },
            onNavigateToActivity: { contact in
                // Navigate to activity view for this contact
                print("📊 [ContactsView_iOS] Navigate to activity for: \(contact.displayName)")
                // TODO: Implement navigation to activity view
            }
        )
    }
}

// MARK: - Preview

#Preview("With Contacts") {
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    ContactsView_iOS { contact, address in
        print("Selected: \(contact.displayName) - \(address.address)")
    }
    .environment(walletManager)
}

#Preview("Empty State") {
    @Previewable @State var walletManager = WalletManager(useMock: false)
    
    ContactsView_iOS { contact, address in
        print("Selected: \(contact.displayName) - \(address.address)")
    }
    .environment(walletManager)
}

