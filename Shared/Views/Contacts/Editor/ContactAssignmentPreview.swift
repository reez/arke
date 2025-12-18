//
//  ContactAssignmentPreview.swift
//  Ark wallet prototype
//
//  Created by Assistant on 12/18/25.
//

import SwiftUI

struct ContactAssignmentPreview: View {
    let currentContact: ContactModel?
    let pendingContact: ContactModel?
    let previewAddress: String?
    let previewAutoAssignCount: Int
    
    var body: some View {
        Group {
            if let pendingContact = pendingContact,
               pendingContact.id != currentContact?.id {
                assignmentChangePreview(pendingContact: pendingContact)
            } else if pendingContact == nil && currentContact != nil {
                removalPreview(currentContact: currentContact!)
            }
        }
    }
    
    // MARK: - Subviews
    
    private func assignmentChangePreview(pendingContact: ContactModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("This will:")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if let current = currentContact {
                    Label("Replace '\(current.displayName)' with '\(pendingContact.displayName)'",
                          systemImage: "arrow.left.arrow.right.circle")
                } else {
                    Label("Assign '\(pendingContact.displayName)' to this transaction",
                          systemImage: "checkmark.circle")
                }
                
                if let address = previewAddress {
                    Label("Save address \(shortAddress(address)) to contact",
                          systemImage: "plus.circle")
                }
                
                if previewAutoAssignCount > 0 {
                    Label("Auto-assign to \(previewAutoAssignCount) other transaction\(previewAutoAssignCount == 1 ? "" : "s") with this address",
                          systemImage: "arrow.triangle.branch")
                        .foregroundColor(.orange)
                }
            }
            .font(.callout)
            .foregroundColor(.secondary)
            .padding(.leading, 28)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func removalPreview(currentContact: ContactModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("This will:")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Label("Remove '\(currentContact.displayName)' from this transaction only",
                      systemImage: "xmark.circle")
                    .foregroundColor(.orange)
                
                // Show info about other transactions if they exist
                if previewAutoAssignCount > 0 {
                    Label("\(previewAutoAssignCount) other transaction\(previewAutoAssignCount == 1 ? "" : "s") with this address will remain assigned",
                          systemImage: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                Label("The address will stay in '\(currentContact.displayName)'s contact card",
                      systemImage: "info.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .font(.callout)
            .padding(.leading, 28)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helpers
    
    private func shortAddress(_ address: String) -> String {
        guard address.count > 16 else { return address }
        let start = address.prefix(8)
        let end = address.suffix(8)
        return "\(start)...\(end)"
    }
}

#Preview("Assignment Change") {
    ContactAssignmentPreview(
        currentContact: ContactModel(
            cachedName: "John Doe",
            addresses: []
        ),
        pendingContact: ContactModel(
            cachedName: "Jane Smith",
            addresses: []
        ),
        previewAddress: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        previewAutoAssignCount: 3
    )
}

#Preview("New Assignment") {
    ContactAssignmentPreview(
        currentContact: nil,
        pendingContact: ContactModel(
            cachedName: "Jane Smith",
            addresses: []
        ),
        previewAddress: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        previewAutoAssignCount: 0
    )
}

#Preview("Removal") {
    ContactAssignmentPreview(
        currentContact: ContactModel(
            cachedName: "John Doe",
            addresses: []
        ),
        pendingContact: nil,
        previewAddress: nil,
        previewAutoAssignCount: 2
    )
}
