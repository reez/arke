//
//  TagChip.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/30/25.
//

import SwiftUI

enum TagChipSize {
    case small
    case medium
    case large
    
    var fontSize: Font {
        switch self {
        case .small:
            return .caption2
        case .medium:
            return .caption
        case .large:
            return .subheadline
        }
    }
    
    var emojiSize: Font {
        switch self {
        case .small:
            return .system(size: 10)
        case .medium:
            return .caption2
        case .large:
            return .caption
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return 6
        case .medium:
            return 8
        case .large:
            return 12
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
            return 3
        case .medium:
            return 4
        case .large:
            return 6
        }
    }
}

struct TagChip: View {
    let tag: TagModel
    let isClickable: Bool
    let size: TagChipSize
    let action: (() -> Void)?
    
    // Convenience initializers
    init(tag: TagModel, size: TagChipSize = .medium, action: @escaping () -> Void) {
        self.tag = tag
        self.isClickable = true
        self.size = size
        self.action = action
    }
    
    init(tag: TagModel, size: TagChipSize = .medium) {
        self.tag = tag
        self.isClickable = false
        self.size = size
        self.action = nil
    }
    
    var body: some View {
        let chipContent = HStack(spacing: size.spacing) {
            if !tag.emoji.isEmpty {
                Text(tag.emoji)
                    .font(size.emojiSize)
            }
            
            Text(tag.name)
                .font(size.fontSize)
                .fontWeight(.medium)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(tag.color.opacity(0.2))
        .foregroundColor(tag.color)
        .overlay(
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .stroke(tag.color.opacity(0.3), lineWidth: 1)
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

// MARK: - Alternative implementations for different use cases

struct TagChip_Selectable: View {
    let tag: TagModel
    let size: TagChipSize
    @Binding var isSelected: Bool
    let onToggle: (() -> Void)?
    
    init(tag: TagModel, size: TagChipSize = .medium, isSelected: Binding<Bool>, onToggle: (() -> Void)? = nil) {
        self.tag = tag
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
                if !tag.emoji.isEmpty {
                    Text(tag.emoji)
                        .font(size.emojiSize)
                }
                
                Text(tag.name)
                    .font(size.fontSize)
                    .fontWeight(.medium)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(size.emojiSize)
                        .foregroundColor(tag.color)
                }
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(isSelected ? tag.color.opacity(0.3) : tag.color.opacity(0.1))
            .foregroundColor(isSelected ? tag.color : tag.color.opacity(0.8))
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(
                        isSelected ? tag.color : tag.color.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    @State private var isPressed: Bool = false
}

struct TagChip_Removable: View {
    let tag: TagModel
    let size: TagChipSize
    let onRemove: () -> Void
    
    init(tag: TagModel, size: TagChipSize = .medium, onRemove: @escaping () -> Void) {
        self.tag = tag
        self.size = size
        self.onRemove = onRemove
    }
    
    var body: some View {
        HStack(spacing: size.spacing) {
            if !tag.emoji.isEmpty {
                Text(tag.emoji)
                    .font(size.emojiSize)
            }
            
            Text(tag.name)
                .font(size.fontSize)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(size.emojiSize)
                    .foregroundColor(tag.color.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(tag.color.opacity(0.2))
        .foregroundColor(tag.color)
        .overlay(
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .stroke(tag.color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
    }
}

// MARK: - Preview Support

#Preview("Basic TagChip") {
    ScrollView {
        VStack(spacing: 16) {
            // Different sizes - non-clickable
            VStack(alignment: .leading, spacing: 8) {
                Text("Small Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    TagChip(tag: TagModel(name: "Coffee", colorHex: "#8B4513", emoji: "☕"), size: .small)
                    TagChip(tag: TagModel(name: "Food", colorHex: "#FF6B35", emoji: "🍕"), size: .small)
                    TagChip(tag: TagModel(name: "Transport", colorHex: "#4A90E2", emoji: "🚗"), size: .small)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Medium Size (Default)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    TagChip(tag: TagModel(name: "Coffee", colorHex: "#8B4513", emoji: "☕"))
                    TagChip(tag: TagModel(name: "Food", colorHex: "#FF6B35", emoji: "🍕"))
                    TagChip(tag: TagModel(name: "Transport", colorHex: "#4A90E2", emoji: "🚗"))
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Large Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    TagChip(tag: TagModel(name: "Coffee", colorHex: "#8B4513", emoji: "☕"), size: .large)
                    TagChip(tag: TagModel(name: "Food", colorHex: "#FF6B35", emoji: "🍕"), size: .large)
                    TagChip(tag: TagModel(name: "Transport", colorHex: "#4A90E2", emoji: "🚗"), size: .large)
                }
            }
            
            Divider()
            
            // Clickable chips with different sizes
            VStack(alignment: .leading, spacing: 8) {
                Text("Clickable - Small")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    TagChip(tag: TagModel(name: "Shopping", colorHex: "#7B68EE", emoji: "🛒"), size: .small) {
                        print("Shopping tapped")
                    }
                    TagChip(tag: TagModel(name: "Bills", colorHex: "#FF4444", emoji: "📄"), size: .small) {
                        print("Bills tapped")
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Clickable - Large")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    TagChip(tag: TagModel(name: "Income", colorHex: "#32CD32", emoji: "💰"), size: .large) {
                        print("Income tapped")
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
                    TagChip_Selectable(
                        tag: TagModel(name: "Investment", colorHex: "#FFD700", emoji: "📈"),
                        size: .small,
                        isSelected: .constant(false)
                    )
                    TagChip_Selectable(
                        tag: TagModel(name: "Gift", colorHex: "#FF69B4", emoji: "🎁"),
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
                HStack {
                    TagChip_Removable(
                        tag: TagModel(name: "Custom", colorHex: "#9370DB", emoji: "⭐"),
                        size: .small
                    ) {
                        print("Remove custom tag")
                    }
                    TagChip_Removable(
                        tag: TagModel(name: "Premium", colorHex: "#FF8C00", emoji: "💎"),
                        size: .large
                    ) {
                        print("Remove premium tag")
                    }
                }
            }
        }
        .padding()
    }
}
