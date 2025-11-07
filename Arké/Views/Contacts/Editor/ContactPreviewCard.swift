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
            
            VStack(spacing: 12) {
                // Avatar
                Group {
                    if let avatarData = contact.avatarData,
                       let nsImage = NSImage(data: avatarData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
                
                // Name
                Text(contact.displayName)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                
                // Notes preview
                if let notes = contact.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                } else if !isEmpty {
                    Text("No notes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(radius: 1, y: 1)
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