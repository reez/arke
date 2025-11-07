//
//  ContactChip.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI

struct ContactChip: View {
    let contact: ContactModel
    let isClickable: Bool
    let action: (() -> Void)?
    
    // Convenience initializers
    init(contact: ContactModel, action: @escaping () -> Void) {
        self.contact = contact
        self.isClickable = true
        self.action = action
    }
    
    init(contact: ContactModel) {
        self.contact = contact
        self.isClickable = false
        self.action = nil
    }
    
    var body: some View {
        let chipContent = HStack(spacing: 6) {
            // Avatar
            ContactAvatarView(avatarData: contact.avatarData, size: 16)
            
            Text(contact.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        
        if isClickable {
            Button(action: {
                action?()
            }) {
                chipContent
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }, perform: {})
        } else {
            chipContent
        }
    }
    
    @State private var isPressed: Bool = false
}

struct ContactChip_Selectable: View {
    let contact: ContactModel
    @Binding var isSelected: Bool
    let onToggle: (() -> Void)?
    
    init(contact: ContactModel, isSelected: Binding<Bool>, onToggle: (() -> Void)? = nil) {
        self.contact = contact
        self._isSelected = isSelected
        self.onToggle = onToggle
    }
    
    var body: some View {
        Button(action: {
            isSelected.toggle()
            onToggle?()
        }) {
            VStack(spacing: 8) {
                // Avatar
                ContactAvatarView(avatarData: contact.avatarData, size: 40)
                
                VStack(spacing: 2) {
                    Text(contact.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    
                    if let notes = contact.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.blue : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    @State private var isPressed: Bool = false
}

struct ContactChip_Removable: View {
    let contact: ContactModel
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // Avatar
            ContactAvatarView(avatarData: contact.avatarData, size: 16)
            
            Text(contact.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview Support

#Preview("Contact Chips") {
    let sampleContact = ContactModel(
        cachedName: "John Doe",
        notes: "Friend from work"
    )
    
    VStack(spacing: 16) {
        // Display-only chip
        ContactChip(contact: sampleContact)
        
        // Clickable chip
        ContactChip(contact: sampleContact) {
            print("Contact tapped")
        }
        
        // Selectable chip
        ContactChip_Selectable(
            contact: sampleContact,
            isSelected: .constant(false)
        )
        
        // Removable chip
        ContactChip_Removable(
            contact: sampleContact
        ) {
            print("Remove contact")
        }
    }
    .padding()
}
