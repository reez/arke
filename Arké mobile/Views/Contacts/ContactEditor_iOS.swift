//
//  ContactEditor_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct ContactEditor_iOS: View {
    let editingContact: ContactModel?
    let onSave: (ContactModel) -> Void
    let onCancel: () -> Void
    let onDelete: (ContactModel) -> Void
    
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        Form {
            Section {
                Text("Contact Editor")
                Text("Implement your contact editing form here")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(editingContact == nil ? "New Contact" : "Edit Contact")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // Implement save logic
                    if let contact = editingContact {
                        onSave(contact)
                    }
                }
            }
        }
    }
}
