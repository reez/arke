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
    
    var body: some View {
        HStack(spacing: 12) {
            if let avatarData = contact.avatarData,
               let nsImage = NSImage(data: avatarData) {
                // Show contact avatar
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                        )
                
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
                
                Text(contact.displayName)
                    .font(.title2)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
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
        onClear: {}
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
        onClear: {}
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
        onClear: {}
    )
    .padding()
    .frame(width: 400)
}
