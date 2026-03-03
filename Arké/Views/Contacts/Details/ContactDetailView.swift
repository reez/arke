//
//  ContactDetailView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/5/25.
//

import SwiftUI
import AppKit

struct ContactDetailView: View {
    let contact: ContactModel
    let onSendToAddress: ((ContactAddressModel) -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onNavigateToActivity: ((ContactModel) -> Void)?
    
    @Environment(\.serviceContainer) private var serviceContainer
    
    // MARK: - ViewModel
    
    @State private var viewModel: ContactDetailViewModel?
    
    var body: some View {
        Group {
            if let viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .task {
                        viewModel = ContactDetailViewModel(
                            contact: contact,
                            serviceContainer: serviceContainer
                        )
                    }
            }
        }
    }
    
    @ViewBuilder
    private func contentView(viewModel: ContactDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Section
                VStack(spacing: 16) {
                    ContactHeaderView(contact: contact)
                    
                    // Transaction Statistics Summary
                    if viewModel.hasTransactionData {
                        ContactTransactionSummaryView(
                            contact: contact,
                            onViewActivity: {
                                onNavigateToActivity?(contact)
                            }
                        )
                    }
                }
                
                // Addresses Section
                Divider()
                
                ContactAddressesSection(
                    contact: contact,
                    onSendToAddress: onSendToAddress
                )
                
                // Notes Section
                if let notes = contact.notes, !notes.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("label_notes")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Divider()
                
                // Contact Information Section
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
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Contact")
        .background(Color(NSColor.windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let onEdit = onEdit {
                    Button("button_edit") {
                        onEdit()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingContactImport },
            set: { viewModel.showingContactImport = $0 }
        )) {
            ContactImportSheet(
                onSelect: { importedData in
                    Task {
                        await viewModel.handleContactImportSelection(importedData)
                    }
                    viewModel.showingContactImport = false
                },
                onCancel: {
                    viewModel.showingContactImport = false
                }
            )
        }
        .alert("contacts_link", isPresented: Binding(
            get: { viewModel.showingAlert },
            set: { viewModel.showingAlert = $0 }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let alertMessage = viewModel.alertMessage {
                Text(alertMessage)
            }
        }
    }
}

#Preview("Standard Contact") {
    NavigationStack {
        ContactDetailView(
            contact: ContactModel(
                cachedName: "John Doe",
                notes: "My Bitcoin contact",
                transactionCount: 5,
                sentAmount: 25000,
                receivedAmount: 75000
            ),
            onSendToAddress: nil,
            onEdit: { print("Edit tapped") },
            onDelete: { print("Delete tapped") },
            onNavigateToActivity: { contact in print("Navigate to activity for \(contact.displayName)") }
        )
    }
    .environment(WalletManager(useMock: true))
}

#Preview("Linked to Native Contact") {
    NavigationStack {
        ContactDetailView(
            contact: ContactModel(
                cachedName: "Jane Smith",
                notes: "Linked to Contacts.app",
                nativeContactID: "12345",
                lastSyncedFromNative: Date().addingTimeInterval(-7200),
                transactionCount: 12,
                sentAmount: 50000,
                receivedAmount: 125000
            ),
            onSendToAddress: nil,
            onEdit: { print("Edit tapped") },
            onDelete: { print("Delete tapped") },
            onNavigateToActivity: { contact in print("Navigate to activity for \(contact.displayName)") }
        )
    }
    .environment(WalletManager(useMock: true))
}
