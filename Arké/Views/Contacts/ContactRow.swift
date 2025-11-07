//
//  ContactRow.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI

struct ContactRow: View {
    @Binding var selectedContact: ContactModel?
    
    let contact: ContactModel
    let onTransactionCountTap: ((ContactModel) -> Void)?
    
    init(contact: ContactModel, onTransactionCountTap: ((ContactModel) -> Void)? = nil, selectedContact: Binding<ContactModel?>) {
        self.contact = contact
        self.onTransactionCountTap = onTransactionCountTap
        self._selectedContact = selectedContact
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarData = contact.avatarData,
               let nsImage = NSImage(data: avatarData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                        )
            } else {
                // Default avatar with initials
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(contact.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let notes = contact.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Transaction statistics
                if let transactionCount = contact.formattedTransactionCount {
                    Text(transactionCount)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Amount statistics in a horizontal layout
                HStack(spacing: 12) {
                    if let sentAmount = contact.formattedSentAmount {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.primary)
                                .font(.caption2)
                            Text(sentAmount)
                                .foregroundColor(.primary)
                        }
                        .font(.caption2)
                    }
                    
                    if let receivedAmount = contact.formattedReceivedAmount {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .foregroundColor(.green)
                                .font(.caption2)
                            Text(receivedAmount)
                                .foregroundColor(.green)
                        }
                        .font(.caption2)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(selectedContact == contact ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .cornerRadius(15)
        .onTapGesture {
            selectedContact = contact
        }
    }
}

#Preview("Contact with Avatar and Stats") {
    @Previewable @State var selectedContact: ContactModel? = nil
    
    let contact = ContactModel(
        cachedName: "Alice Johnson",
        notes: "Regular trading partner",
        avatarData: nil,
        transactionCount: 12,
        sentAmount: 500_000,
        receivedAmount: 750_000
    )
    
    ContactRow(
        contact: contact,
        onTransactionCountTap: { _ in },
        selectedContact: $selectedContact
    )
    .padding()
}

#Preview("Contact without Stats") {
    @Previewable @State var selectedContact: ContactModel? = nil
    
    let contact = ContactModel(
        cachedName: "Bob Smith",
        notes: "Met at conference",
        avatarData: nil
    )
    
    ContactRow(
        contact: contact,
        onTransactionCountTap: nil,
        selectedContact: $selectedContact
    )
    .padding()
}

#Preview("Selected Contact") {
    @Previewable @State var selectedContact: ContactModel? = ContactModel(
        cachedName: "Charlie Brown",
        notes: "Long-term partner",
        avatarData: nil,
        transactionCount: 45,
        sentAmount: 2_500_000,
        receivedAmount: 1_800_000
    )
    
    if let contact = selectedContact {
        ContactRow(
            contact: contact,
            onTransactionCountTap: { _ in },
            selectedContact: $selectedContact
        )
        .padding()
    }
}

#Preview("Contact without Notes") {
    @Previewable @State var selectedContact: ContactModel? = nil
    
    let contact = ContactModel(
        cachedName: "Diana Prince",
        notes: nil,
        avatarData: nil,
        transactionCount: 3,
        sentAmount: 100_000,
        receivedAmount: 50_000
    )
    
    ContactRow(
        contact: contact,
        onTransactionCountTap: { _ in },
        selectedContact: $selectedContact
    )
    .padding()
}
