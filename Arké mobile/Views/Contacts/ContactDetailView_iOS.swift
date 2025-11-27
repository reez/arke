//
//  ContactDetailView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct ContactDetailView_iOS: View {
    let contact: ContactModel
    let onSendToAddress: (ContactAddressModel) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onNavigateToActivity: (ContactModel) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(contact.displayName)
                    .font(.largeTitle)
                
                Text("Contact ID: \(contact.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Implement your contact detail UI here
                // Show addresses, notes, etc.
            }
            .padding()
        }
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", action: onEdit)
            }
        }
    }
}
