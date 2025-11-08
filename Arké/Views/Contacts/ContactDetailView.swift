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
    
    // MARK: - Services
    @Environment(WalletManager.self) private var walletManager
    
    // MARK: - Address State
    @State private var addresses: [ContactAddressModel] = []
    @State private var isLoadingAddresses = false
    @State private var showingAddressEditor = false
    @State private var editingAddress: ContactAddressModel?
    @State private var addressError: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Section
                VStack(spacing: 16) {
                    // Contact Avatar and Name
                    HStack(spacing: 15) {
                        ContactAvatarView(avatarData: contact.avatarData, size: 75)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(contact.displayName)
                                .font(.title)
                                .fontWeight(.semibold)
                            
                            Text("Added \(contact.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Transaction Statistics Summary
                    if hasTransactionData {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sent")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(contact.formattedSentAmount ?? "0 ₿")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .foregroundColor(.red)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Received")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(contact.formattedReceivedAmount ?? "0 ₿")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            // Total transactions count
                            if let transactionCount = contact.formattedTransactionCount {
                                Text(transactionCount)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                
                // Addresses Section
                addressesSection
                
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
                DisclosureGroup {
                    VStack(spacing: 12) {
                        // Contact ID
                        DetailRow(
                            title: "Contact ID",
                            value: contact.id.uuidString,
                            isCopyable: true
                        )
                        
                        // Creation Date
                        DetailRow(
                            title: "Added",
                            value: contact.createdAt.formatted(date: .abbreviated, time: .shortened)
                        )
                        
                        // Last Updated
                        if contact.updatedAt != contact.createdAt {
                            DetailRow(
                                title: "Last Updated",
                                value: contact.updatedAt.formatted(date: .abbreviated, time: .shortened)
                            )
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Details")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
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
                
                if let onDelete = onDelete {
                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            Task {
                await loadAddresses()
            }
        }
        .sheet(isPresented: Binding(
            get: { showingAddressEditor && editingAddress == nil },
            set: { newValue in
                if !newValue {
                    showingAddressEditor = false
                    editingAddress = nil
                }
            }
        )) {
            ContactAddressEditor(
                contact: contact,
                editingAddress: nil,
                onSave: {
                    showingAddressEditor = false
                    editingAddress = nil
                    Task {
                        await loadAddresses()
                    }
                },
                onCancel: {
                    showingAddressEditor = false
                    editingAddress = nil
                }
            )
        }
        .sheet(item: $editingAddress) { address in
            ContactAddressEditor(
                contact: contact,
                editingAddress: address,
                onSave: {
                    showingAddressEditor = false
                    editingAddress = nil
                    Task {
                        await loadAddresses()
                    }
                },
                onCancel: {
                    showingAddressEditor = false
                    editingAddress = nil
                },
                onDelete: {
                    showingAddressEditor = false
                    editingAddress = nil
                    Task {
                        await deleteAddress(address)
                    }
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasTransactionData: Bool {
        contact.transactionCount != nil || contact.sentAmount != nil || contact.receivedAmount != nil
    }
    
    // MARK: - Address Section
    
    @ViewBuilder
    private var addressesSection: some View {
        Divider()
        
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Addresses")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add Address") {
                    showAddAddressSheet()
                }
                .buttonStyle(.bordered)
            }
            
            if isLoadingAddresses {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.7)
                    
                    Text("Loading addresses...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if addresses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "link.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No addresses added")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("Add addresses to send Bitcoin to this contact")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(addresses) { address in
                        AddressListItem(
                            address: address,
                            onEdit: {
                                editAddress(address)
                            },
                            onSetPrimary: {
                                Task {
                                    await setPrimaryAddress(address)
                                }
                            },
                            onSendTo: {
                                onSendToAddress?(address)
                            }
                        )
                    }
                }
            }
            
            // Error display
            if let error = addressError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
            }
        }
    }
    
    // MARK: - Address Actions
    
    private func loadAddresses() async {
        isLoadingAddresses = true
        addressError = nil
        
        addresses = await walletManager.getAddressesForContact(contact.id)
        
        isLoadingAddresses = false
    }
    
    private func showAddAddressSheet() {
        editingAddress = nil
        showingAddressEditor = true
    }
    
    private func editAddress(_ address: ContactAddressModel) {
        editingAddress = address
        showingAddressEditor = true
    }
    
    private func deleteAddress(_ address: ContactAddressModel) async {
        do {
            try await walletManager.deleteAddress(address.id)
            await loadAddresses() // Refresh the list
        } catch {
            addressError = "Failed to delete address: \(error.localizedDescription)"
        }
    }
    
    private func setPrimaryAddress(_ address: ContactAddressModel) async {
        do {
            try await walletManager.setPrimaryAddress(address.id, for: contact.id)
            await loadAddresses() // Refresh the list
        } catch {
            addressError = "Failed to set primary address: \(error.localizedDescription)"
        }
    }
}

#Preview {
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
            onDelete: { print("Delete tapped") }
        )
    }
    .environment(WalletManager(useMock: true))
}
