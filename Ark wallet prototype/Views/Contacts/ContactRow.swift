//
//  ContactRow.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI

struct ContactRow: View {
    let contact: ContactModel
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
    init(contact: ContactModel, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.contact = contact
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarData = contact.avatarData,
               let nsImage = NSImage(data: avatarData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                // Default avatar with initials
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(contact.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let notes = contact.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text("Created \(contact.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Menu for edit/delete actions (only show if callbacks are provided)
            if onEdit != nil || onDelete != nil {
                Menu {
                    if let onEdit = onEdit {
                        Button("Edit") {
                            onEdit()
                        }
                    }
                    
                    if onEdit != nil && onDelete != nil {
                        Divider()
                    }
                    
                    if let onDelete = onDelete {
                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20, height: 20)
            }
        }
        .padding(.vertical, 8)
        .background(Color.clear)
    }
}
