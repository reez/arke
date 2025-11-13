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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Section
                VStack(spacing: 16) {
                    ContactHeaderView(contact: contact)
                    
                    // Transaction Statistics Summary
                    if hasTransactionData {
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
                        Text("Notes")
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
                            await handleRefreshFromNativeContact()
                        }
                    },
                    onUnlinkNativeContact: {
                        Task {
                            await handleUnlinkFromNativeContact()
                        }
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
                    Button("Edit") {
                        onEdit()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasTransactionData: Bool {
        contact.transactionCount != nil || contact.sentAmount != nil || contact.receivedAmount != nil
    }
    
    // MARK: - Native Contact Actions
    
    private func handleRefreshFromNativeContact() async {
        do {
            _ = try await serviceContainer.contactService.refreshFromNativeContact(contactID: contact.id)
            print("✅ Successfully refreshed contact from native Contacts")
        } catch {
            print("❌ Failed to refresh from native contact: \(error)")
            // TODO: Show user-facing error alert
        }
    }
    
    private func handleUnlinkFromNativeContact() async {
        do {
            try await serviceContainer.contactService.unlinkFromNativeContact(contactID: contact.id)
            print("✅ Successfully unlinked contact from native Contacts")
        } catch {
            print("❌ Failed to unlink from native contact: \(error)")
            // TODO: Show user-facing error alert
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
