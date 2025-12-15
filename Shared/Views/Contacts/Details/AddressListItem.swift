//
//  AddressListItem.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/5/25.
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

struct AddressListItem: View {
    let address: ContactAddressModel
    let onEdit: () -> Void
    let onSetPrimary: () -> Void
    let onSendTo: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Send button
                Button(action: onSendTo) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                #if os(macOS)
                .help("Send to this address")
                #endif
                
                // Address info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(address.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if address.isPrimary {
                            Image(systemName: "star.fill")
                                .font(.caption)
                        }
                    }
                    
                    // Address
                    Text(address.shortAddress)
                        .font(.body.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.body)
                        .tint(Color.arkeDark)
                }
                .accessibilityLabel("Edit address")
                .buttonStyle(.bordered)
                #if os(macOS)
                .help("Edit address")
                #endif
            }
            .padding(.vertical, 8)
        }
        /*
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(.secondarySystemBackground))
        #endif
        */
        .cornerRadius(8)
        .contextMenu {
            Button(action: copyAddress) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            if !address.isPrimary {
                Button(action: onSetPrimary) {
                    Label("Set as Primary", systemImage: "star.fill")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func copyAddress() {
        copyToClipboard(address.address)
        print("📋 Copied address to clipboard: \(address.shortAddress)")
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
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
            onSetPrimary: {},
            onSendTo: {}
        )
    }
    .padding()
}
