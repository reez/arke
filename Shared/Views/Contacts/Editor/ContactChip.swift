//
//  ContactChip.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI

enum ContactChipSize {
    case small
    case medium
    case large
    
    var fontSize: Font {
        switch self {
        case .small:
            return .caption2
        case .medium:
            return .subheadline
        case .large:
            return .body
        }
    }
    
    var avatarSize: CGFloat {
        switch self {
        case .small:
            return 12
        case .medium:
            return 16
        case .large:
            return 20
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return 8
        case .medium:
            return 12
        case .large:
            return 16
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small:
            return 3
        case .medium:
            return 4
        case .large:
            return 6
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small:
            return 8
        case .medium:
            return 12
        case .large:
            return 16
        }
    }
    
    var spacing: CGFloat {
        switch self {
        case .small:
            return 4
        case .medium:
            return 6
        case .large:
            return 8
        }
    }
}

struct ContactChip: View {
    let contact: ContactModel
    let isClickable: Bool
    let size: ContactChipSize
    let action: (() -> Void)?
    
    // Convenience initializers
    init(contact: ContactModel, size: ContactChipSize = .medium, action: @escaping () -> Void) {
        self.contact = contact
        self.isClickable = true
        self.size = size
        self.action = action
    }
    
    init(contact: ContactModel, size: ContactChipSize = .medium) {
        self.contact = contact
        self.isClickable = false
        self.size = size
        self.action = nil
    }
    
    var body: some View {
        let chipContent = HStack(spacing: size.spacing) {
            // Avatar
            ContactAvatarView(avatarData: contact.avatarData, size: size.avatarSize)
            
            Text(contact.displayName)
                .font(size.fontSize)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .overlay(
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
        
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
    let size: ContactChipSize
    @Binding var isSelected: Bool
    let onToggle: (() -> Void)?
    
    init(contact: ContactModel, size: ContactChipSize = .medium, isSelected: Binding<Bool>, onToggle: (() -> Void)? = nil) {
        self.contact = contact
        self.size = size
        self._isSelected = isSelected
        self.onToggle = onToggle
    }
    
    var body: some View {
        Button(action: {
            isSelected.toggle()
            onToggle?()
        }) {
            HStack(spacing: size.spacing) {
                // Avatar - use a larger size for the selectable variant
                ContactAvatarView(avatarData: contact.avatarData, size: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName)
                        .font(.body)
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    
                    if let notes = contact.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.arkeGold)
                }
            }
            .padding(size.horizontalPadding)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.arkeGold.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    @State private var isPressed: Bool = false
}

struct ContactChip_Removable: View {
    let contact: ContactModel
    let size: ContactChipSize
    let onRemove: () -> Void
    
    init(contact: ContactModel, size: ContactChipSize = .medium, onRemove: @escaping () -> Void) {
        self.contact = contact
        self.size = size
        self.onRemove = onRemove
    }
    
    var body: some View {
        HStack(spacing: size.spacing) {
            // Avatar
            ContactAvatarView(avatarData: contact.avatarData, size: size.avatarSize)
            
            Text(contact.displayName)
                .font(size.fontSize)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(size.fontSize)
                    .foregroundColor(.blue.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .overlay(
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
    }
}

// MARK: - Preview Support

#Preview("Contact Chips") {
    let sampleContact = ContactModel(
        cachedName: "John Doe",
        notes: "Friend from work"
    )
    
    ScrollView {
        VStack(spacing: 16) {
            // Different sizes - non-clickable
            VStack(alignment: .leading, spacing: 8) {
                Text("Small Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    ContactChip(contact: sampleContact, size: .small)
                    ContactChip(contact: ContactModel(cachedName: "Jane Smith"), size: .small)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Medium Size (Default)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    ContactChip(contact: sampleContact)
                    ContactChip(contact: ContactModel(cachedName: "Jane Smith"))
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Large Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    ContactChip(contact: sampleContact, size: .large)
                    ContactChip(contact: ContactModel(cachedName: "Jane Smith"), size: .large)
                }
            }
            
            Divider()
            
            // Clickable chips with different sizes
            VStack(alignment: .leading, spacing: 8) {
                Text("Clickable - Small")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    ContactChip(contact: sampleContact, size: .small) {
                        print("Contact tapped")
                    }
                    ContactChip(contact: ContactModel(cachedName: "Alice Brown"), size: .small) {
                        print("Alice tapped")
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Clickable - Large")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    ContactChip(contact: sampleContact, size: .large) {
                        print("Contact tapped")
                    }
                }
            }
            
            Divider()
            
            // Selectable chips with different sizes
            VStack(alignment: .leading, spacing: 8) {
                Text("Selectable")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    ContactChip_Selectable(
                        contact: sampleContact,
                        size: .small,
                        isSelected: .constant(false)
                    )
                    ContactChip_Selectable(
                        contact: ContactModel(cachedName: "Bob Wilson", notes: "Colleague"),
                        size: .large,
                        isSelected: .constant(true)
                    )
                }
            }
            
            // Removable chip with different sizes
            VStack(alignment: .leading, spacing: 8) {
                Text("Removable")
                    .font(.caption)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    ContactChip_Removable(
                        contact: sampleContact,
                        size: .small
                    ) {
                        print("Remove contact")
                    }
                    ContactChip_Removable(
                        contact: ContactModel(cachedName: "Jane Smith"),
                        size: .medium
                    ) {
                        print("Remove contact")
                    }
                    ContactChip_Removable(
                        contact: ContactModel(cachedName: "Alice Brown"),
                        size: .large
                    ) {
                        print("Remove contact")
                    }
                }
            }
        }
        .padding()
    }
}
