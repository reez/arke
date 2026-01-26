//
//  ContactDetailsDisclosure.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/13/25.
//

import SwiftUI

struct ContactDetailsDisclosure: View {
    let contact: ContactModel
    let onRefreshFromNativeContact: (() -> Void)?
    let onUnlinkNativeContact: (() -> Void)?
    let onLinkNativeContact: (() -> Void)?
    
    var body: some View {
        DisclosureGroup {
            VStack(spacing: 12) {
                NativeContactLinkDetail(
                    contact: contact,
                    onRefresh: onRefreshFromNativeContact ?? {},
                    onUnlink: onUnlinkNativeContact ?? {},
                    onLink: onLinkNativeContact ?? {}
                )
                .padding(.top, 12)
                
                Divider()
                    .padding(.vertical, 4)
                
                DetailRow(
                    title: "Contact Type",
                    value: contact.contactType.displayName
                )
                
                DetailRow(
                    title: "Added",
                    value: contact.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
                
                if contact.updatedAt != contact.createdAt {
                    DetailRow(
                        title: "Last Updated",
                        value: contact.updatedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
                
                DetailRow(
                    title: "Contact ID",
                    value: contact.id.uuidString
                )
            }
        } label: {
            Text("Details")
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

#Preview("Standard Contact") {
    ContactDetailsDisclosure(
        contact: ContactModel(
            cachedName: "John Doe",
            notes: "My Bitcoin contact"
        ),
        onRefreshFromNativeContact: {
            print("Refresh from native contact")
        },
        onUnlinkNativeContact: {
            print("Unlink native contact")
        },
        onLinkNativeContact: {
            print("Link native contact")
        }
    )
    .padding()
}

#Preview("Linked to Native Contact") {
    ContactDetailsDisclosure(
        contact: ContactModel(
            cachedName: "Jane Smith",
            notes: "Linked to Contacts.app",
            nativeContactID: "12345",
            lastSyncedFromNative: Date().addingTimeInterval(-3600)
        ),
        onRefreshFromNativeContact: {
            print("Refresh from native contact")
        },
        onUnlinkNativeContact: {
            print("Unlink native contact")
        },
        onLinkNativeContact: {
            print("Link native contact")
        }
    )
    .padding()
}
