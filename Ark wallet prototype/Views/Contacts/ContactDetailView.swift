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
                        ContactAvatarView(contact: contact, size: 40)
                        
                        VStack(alignment: .leading) {
                            Text(contact.displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Added \(contact.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
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
                
                // Transaction Summary Section (if data available)
                if hasTransactionData {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Transaction Summary")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            if let transactionCount = contact.transactionCount {
                                DetailRow(
                                    title: "Total Transactions",
                                    value: "\(transactionCount)"
                                )
                            }
                            
                            if let sentAmount = contact.sentAmount, sentAmount > 0 {
                                DetailRow(
                                    title: "Total Sent",
                                    value: BitcoinFormatter.formatAmount(sentAmount)
                                )
                            }
                            
                            if let receivedAmount = contact.receivedAmount, receivedAmount > 0 {
                                DetailRow(
                                    title: "Total Received",
                                    value: BitcoinFormatter.formatAmount(receivedAmount)
                                )
                            }
                        }
                    }
                }
                
                // Notes Section
                if let notes = contact.notes, !notes.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Notes")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                } else {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Notes")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Text("No notes added")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Add Notes") {
                                // TODO: Implement note editing
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                
                Divider()
                
                // Contact Information Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Contact Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
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
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Contact")
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task {
                await loadAddresses()
            }
        }
        .sheet(isPresented: $showingAddressEditor) {
            ContactAddressEditor(
                contact: contact,
                editingAddress: editingAddress,
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
                            onDelete: {
                                Task {
                                    await deleteAddress(address)
                                }
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

// MARK: - Contact Avatar View

struct ContactAvatarView: View {
    let contact: ContactModel
    let size: CGFloat
    
    var body: some View {
        if let avatarData = contact.avatarData,
           let nsImage = NSImage(data: avatarData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: size * 0.8))
                .foregroundColor(.blue)
                .frame(width: size, height: size)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
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
            onSendToAddress: nil
        )
    }
    .environment(WalletManager(useMock: true))
}
