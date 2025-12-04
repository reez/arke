//
//  ContactsView_iOS.swift
//  Arké
//
//  Created by Assistant on 12/4/25.
//

import SwiftUI
import UIKit

// MARK: - iOS Contact Management

struct ContactsView_iOS: View {
    @Environment(WalletManager.self) private var walletManager
    
    let onSendToAddress: (ContactAddressModel, ContactModel) -> Void
    let onNavigateToActivity: (ContactModel) -> Void
    let onSelectContact: ((ContactModel)) -> Void
    
    @State private var viewModel: ContactsViewModel?
    @State private var selectedContact: ContactModel?
    
    var body: some View {
        Group {
            if let viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .task {
                        viewModel = ContactsViewModel(walletManager: walletManager)
                        await viewModel?.loadContactsWithStatistics()
                    }
            }
        }
    }
    
    @ViewBuilder
    private func contentView(viewModel: ContactsViewModel) -> some View {
        List {
            if viewModel.hasContacts {
                contactsSection(viewModel: viewModel)
            } else {
                emptyStateSection(viewModel: viewModel)
            }
        }
        .navigationTitle("Contacts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showNewContactEditor()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.loadContactsWithStatistics()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func contactsSection(viewModel: ContactsViewModel) -> some View {
        let contacts = viewModel.contacts
        
        if contacts.isEmpty {
            ContentUnavailableView {
                Label("Loading Contacts", systemImage: "person.2.circle")
            } description: {
                Text("Please wait...")
            }
        } else {
            ForEach(contacts) { contact in
                ContactRow_iOS(
                    contact: contact,
                    onTransactionCountTap: {
                        onNavigateToActivity(contact)
                    },
                    onSendTap: {
                        if let primaryAddress = contact.primaryAddress {
                            onSendToAddress(primaryAddress, contact)
                        }
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private func emptyStateSection(viewModel: ContactsViewModel) -> some View {
        Section {
            ContentUnavailableView {
                Label("No Contacts Yet", systemImage: "person.2.circle")
            } description: {
                Text("Add contacts to organize your transactions and make sending easier")
            } actions: {
                Button("Create Your First Contact") {
                    viewModel.showNewContactEditor()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: - Preview

#Preview("With Contacts") {
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    NavigationStack {
        ContactsView_iOS(
            onSendToAddress: { address, contact in
                print("Send to \(contact.displayName) at \(address.address)")
            },
            onNavigateToActivity: { contact in
                print("Navigate to activity for \(contact.displayName)")
            },
            onSelectContact: { contact in
                print("Contact selected: \(contact.displayName)")
            }
        )
        .environment(walletManager)
    }
}

#Preview("Empty State") {
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    NavigationStack {
        ContactsView_iOS(
            onSendToAddress: { address, contact in
                print("Send to \(contact.displayName) at \(address.address)")
            },
            onNavigateToActivity: { contact in
                print("Navigate to activity for \(contact.displayName)")
            },
            onSelectContact: { contact in
                print("Contact selected: \(contact.displayName)")
            }
        )
        .environment(walletManager)
    }
}
