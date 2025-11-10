//
//  ContactPreviewCard.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/04/25.
//

import SwiftUI

struct ContactPreviewCard: View {
    let contact: ContactModel
    let isEmpty: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Preview")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                // Avatar
                ContactAvatarView(avatarData: contact.avatarData, size: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Name
                    Text(contact.displayName)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                    
                    // Notes preview
                    if let notes = contact.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }
}

#Preview("With Avatar") {
    ContactPreviewCard(
        contact: ContactModel(
            cachedName: "John Doe",
            notes: "Coffee shop owner downtown. Always has great recommendations for new blends."
        ),
        isEmpty: false
    )
    .padding()
}

#Preview("Without Avatar") {
    ContactPreviewCard(
        contact: ContactModel(
            cachedName: "Jane Smith",
            notes: nil
        ),
        isEmpty: false
    )
    .padding()
}

#Preview("Empty") {
    ContactPreviewCard(
        contact: ContactModel(
            cachedName: "Sample Contact",
            notes: nil
        ),
        isEmpty: true
    )
    .padding()
}
