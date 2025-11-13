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
    
    var body: some View {
        DisclosureGroup {
            VStack(spacing: 12) {
                DetailRow(
                    title: "Contact ID",
                    value: contact.id.uuidString,
                    isCopyable: true
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
                
                if contact.isLinkedToNativeContact {
                    Divider()
                        .padding(.vertical, 4)
                    
                    NativeContactLinkDetail(
                        contact: contact,
                        onRefresh: onRefreshFromNativeContact ?? {},
                        onUnlink: onUnlinkNativeContact ?? {}
                    )
                }
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
        }
    )
    .padding()
}
