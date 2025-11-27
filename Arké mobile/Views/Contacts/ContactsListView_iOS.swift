//
//  ContactsListView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct ContactsListView_iOS: View {
    let onSelectContact: (ContactModel) -> Void
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        List {
            // Your contacts list implementation
            // Each row should be a NavigationLink with value: contact
            Text("Contacts list coming soon")
                .foregroundStyle(.secondary)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Add new contact
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
