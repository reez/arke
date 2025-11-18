//
//  ContactInfoBanner.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/7/25.
//

import SwiftUI

struct ContactInfoBanner: View {
    let contact: ContactModel
    let onClear: () -> Void
    let onViewContact: () -> Void
    
    init(contact: ContactModel, onClear: @escaping () -> Void, onViewContact: @escaping () -> Void) {
        self.contact = contact
        self.onClear = onClear
        self.onViewContact = onViewContact
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let avatarData = contact.avatarData,
               let nsImage = NSImage(data: avatarData) {
                // Show contact avatar
                Button(action: onViewContact) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                            )
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            } else {
                // Show default transaction icon
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                        )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sending to")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Button(action: onViewContact) {
                    Text(contact.displayName)
                        .font(.title2)
                        .fontWeight(.medium)
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            
            Spacer()
            
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear contact")
        }
    }
}

#Preview("With Avatar") {
    ContactInfoBanner(
        contact: ContactModel(
            cachedName: "Alice Johnson",
            notes: "Friend from work",
            avatarData: nil,
            addresses: []
        ),
        onClear: {},
        onViewContact: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("Without Avatar") {
    ContactInfoBanner(
        contact: ContactModel(
            cachedName: "Bob Smith",
            addresses: []
        ),
        onClear: {},
        onViewContact: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("Long Name") {
    ContactInfoBanner(
        contact: ContactModel(
            cachedName: "Christopher Alexander Wellington III",
            addresses: []
        ),
        onClear: {},
        onViewContact: {}
    )
    .padding()
    .frame(width: 400)
}
