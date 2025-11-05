//
//  AddressListItem.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/5/25.
//

import SwiftUI
import AppKit

struct AddressListItem: View {
    let address: ContactAddressModel
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSetPrimary: () -> Void
    let onSendTo: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Address info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(address.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if address.isPrimary {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        // Network badge
                        if let network = address.network {
                            Text(network.displayName.uppercased())
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(networkColor(for: network).opacity(0.2))
                                .foregroundColor(networkColor(for: network))
                                .cornerRadius(3)
                        }
                    }
                    
                    // Address with copy functionality
                    Button(action: copyAddress) {
                        HStack(spacing: 4) {
                            Text(address.shortAddress)
                                .font(.body.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Action buttons
                HStack(spacing: 8) {
                    // Send button
                    Button(action: onSendTo) {
                        Image(systemName: "paperplane.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Send to this address")
                    
                    // Edit button
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("Edit address")
                    
                    // Delete button
                    Button(action: { showingDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .help("Delete address")
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .confirmationDialog(
            "Delete Address",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this address? This action cannot be undone.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func copyAddress() {
        NSPasteboard.general.setString(address.address, forType: .string)
        
        // Could add a toast notification here if desired
        print("📋 Copied address to clipboard: \(address.shortAddress)")
    }
    
    private func networkColor(for network: BitcoinNetwork) -> Color {
        switch network {
        case .mainnet:
            return .green
        case .testnet, .signet:
            return .orange
        case .regtest:
            return .purple
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AddressListItem(
            address: ContactAddressModel(
                address: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
                normalizedAddress: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
                format: .bitcoin,
                label: "My Bitcoin Address",
                isPrimary: true,
                contactId: UUID()
            ),
            onEdit: {},
            onDelete: {},
            onSetPrimary: {},
            onSendTo: {}
        )
        
        AddressListItem(
            address: ContactAddressModel(
                address: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
                normalizedAddress: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
                format: .bitcoin,
                label: nil,
                isPrimary: false,
                contactId: UUID()
            ),
            onEdit: {},
            onDelete: {},
            onSetPrimary: {},
            onSendTo: {}
        )
    }
    .padding()
}
