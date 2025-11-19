//
//  PaymentDestinationItem.swift
//  Arké
//
//  Created by Christoph on 11/18/25.
//

import SwiftUI

struct PaymentDestinationItem: View {
    let formatName: String
    let shortAddress: String
    let estimatedFee: Int?
    let isSelectable: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let contactName: String?
    let contactAvatar: Data?
    
    init(
        formatName: String,
        shortAddress: String,
        estimatedFee: Int?,
        isSelectable: Bool,
        isSelected: Bool,
        onTap: @escaping () -> Void,
        contactName: String? = nil,
        contactAvatar: Data? = nil
    ) {
        self.formatName = formatName
        self.shortAddress = shortAddress
        self.estimatedFee = estimatedFee
        self.isSelectable = isSelectable
        self.isSelected = isSelected
        self.onTap = onTap
        self.contactName = contactName
        self.contactAvatar = contactAvatar
    }
    
    var body: some View {
        Group {
            if isSelectable {
                Button {
                    onTap()
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }
    
    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let contactName = contactName, let avatarData = contactAvatar {
                HStack {
                    // Contact avatar
                    if let nsImage = NSImage(data: avatarData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Known address")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Text(contactName)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    // Original layout without contact
                    Text(formatName)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(shortAddress)
                        .font(.body)
                }
                
                Spacer()
                
                if let fee = estimatedFee {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fee")
                            .foregroundColor(.secondary)
                        
                        Text(fee > 0 ? "~\(BitcoinFormatter.shared.formatAmount(fee))" : "Free")
                            .font(.body)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background {
            if isSelectable && isSelected {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.arkeGold.opacity(0.05))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }
    
    private var borderColor: Color {
        if isSelected {
            return .arkeGold
        } else if isSelectable {
            return Color(nsColor: .separatorColor)
        } else {
            return Color(nsColor: .separatorColor).opacity(0.5)
        }
    }
}

#Preview("Fee & Selected") {
    @Previewable @State var isSelected = false
    
    PaymentDestinationItem(
        formatName: "Bitcoin Address",
        shortAddress: "bc1q...xyz",
        estimatedFee: 250,
        isSelectable: true,
        isSelected: isSelected,
        onTap: { isSelected.toggle() }
    )
    .padding()
}

#Preview("No Fee") {
    @Previewable @State var isSelected = true
    
    PaymentDestinationItem(
        formatName: "Lightning Invoice",
        shortAddress: "lnbc...abc",
        estimatedFee: 0,
        isSelectable: true,
        isSelected: isSelected,
        onTap: { isSelected.toggle() }
    )
    .padding()
}

#Preview("Without Fee Info") {
    @Previewable @State var isSelected = false
    
    PaymentDestinationItem(
        formatName: "Payment Address",
        shortAddress: "tb1q...def",
        estimatedFee: nil,
        isSelectable: true,
        isSelected: isSelected,
        onTap: { isSelected.toggle() }
    )
    .padding()
}

#Preview("Not Selectable") {
    @Previewable @State var isSelected = false
    
    PaymentDestinationItem(
        formatName: "Payment Address",
        shortAddress: "tb1q...def",
        estimatedFee: 250,
        isSelectable: false,
        isSelected: isSelected,
        onTap: { isSelected.toggle() }
    )
    .padding()
}

#Preview("With Contact") {
    @Previewable @State var isSelected = false
    
    PaymentDestinationItem(
        formatName: "Lightning Address",
        shortAddress: "alice@example.com",
        estimatedFee: 0,
        isSelectable: true,
        isSelected: isSelected,
        onTap: { isSelected.toggle() },
        contactName: "Alice Smith",
        contactAvatar: createPlaceholderAvatar()
    )
    .padding()
}

private func createPlaceholderAvatar() -> Data? {
    let size = CGSize(width: 80, height: 80)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
    image.unlockFocus()
    return image.tiffRepresentation
}
