//
//  ContactRow.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI
import ArkeUI

struct ContactRow: View {
    @Binding var selectedContact: ContactModel?
    
    let contact: ContactModel
    let onTransactionCountTap: ((ContactModel) -> Void)?
    let onSendTap: ((ContactModel) -> Void)?
    
    init(contact: ContactModel, onTransactionCountTap: ((ContactModel) -> Void)? = nil, onSendTap: ((ContactModel) -> Void)? = nil, selectedContact: Binding<ContactModel?>) {
        self.contact = contact
        self.onTransactionCountTap = onTransactionCountTap
        self.onSendTap = onSendTap
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
                    .fill(Color.Arke.blue.gradient)
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
            
            HStack(spacing: 12) {
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
                                    .foregroundColor(.Arke.green)
                                    .font(.caption2)
                                Text(receivedAmount)
                                    .foregroundColor(.Arke.green)
                            }
                            .font(.caption2)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onTransactionCountTap?(contact)
                }
                
                // Send button - only show if contact has a primary address
                if contact.primaryAddress != nil {
                    Button(action: {
                        onSendTap?(contact)
                    }) {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(ArkeIconButtonStyle(size: .small))
                    .help(String(format: NSLocalizedString("help_send_to", bundle: .module, comment: ""), contact.displayName))
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
    
    let contactId = UUID()
    let contact = ContactModel(
        cachedName: "Alice Johnson",
        notes: "Regular trading partner",
        avatarData: nil,
        transactionCount: 12,
        sentAmount: 500_000,
        receivedAmount: 750_000,
        addresses: [
            ContactAddressModel(
                address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
                normalizedAddress: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
                format: .bitcoin,
                label: "Primary",
                isPrimary: true,
                contactId: contactId
            )
        ]
    )
    
    ContactRow(
        contact: contact,
        onTransactionCountTap: { _ in },
        onSendTap: { contact in
            print("Send button tapped for: \(contact.displayName)")
        },
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
        onSendTap: { contact in
            print("Send button tapped for: \(contact.displayName)")
        },
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
        receivedAmount: 1_800_000,
        addresses: [
            ContactAddressModel(
                address: "sp1qqgste7k9hx0qftg6qmwlkqtwuy6cycyavzmzj85c6qdfhjdpdjtdgqjuexzk6murw56suy3e0rd2cgqvycxttddwsvgxe2usfpxumr70xc9pkqwv",
                normalizedAddress: "sp1qqgste7k9hx0qftg6qmwlkqtwuy6cycyavzmzj85c6qdfhjdpdjtdgqjuexzk6murw56suy3e0rd2cgqvycxttddwsvgxe2usfpxumr70xc9pkqwv",
                format: .silentPayments,
                label: "Silent Payment Address",
                isPrimary: true,
                contactId: UUID()
            )
        ]
    )
    
    if let contact = selectedContact {
        ContactRow(
            contact: contact,
            onTransactionCountTap: { _ in },
            onSendTap: { contact in
                print("Send button tapped for: \(contact.displayName)")
            },
            selectedContact: $selectedContact
        )
        .padding()
    }
}

#Preview("Contact without Notes") {
    @Previewable @State var selectedContact: ContactModel? = nil
    
    let contactId = UUID()
    let contact = ContactModel(
        cachedName: "Diana Prince",
        notes: nil,
        avatarData: nil,
        transactionCount: 3,
        sentAmount: 100_000,
        receivedAmount: 50_000,
        addresses: [
            ContactAddressModel(
                address: "lnbc1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdpl2pkx2ctnv5sxxmmwwd5kgetjypeh2ursdae8g6twvus8g6rfwvs8qun0dfjkxaq8rkx3yf5tcsyz3d73gafnh3cax9rn449d9p5uxz9ezhhypd0elx87sjle52x86fux2ypatgddc6k63n7erqz25le42c4u4ecky03ylcqca784w",
                normalizedAddress: "lnbc1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdpl2pkx2ctnv5sxxmmwwd5kgetjypeh2ursdae8g6twvus8g6rfwvs8qun0dfjkxaq8rkx3yf5tcsyz3d73gafnh3cax9rn449d9p5uxz9ezhhypd0elx87sjle52x86fux2ypatgddc6k63n7erqz25le42c4u4ecky03ylcqca784w",
                format: .lightning,
                label: "Lightning Invoice",
                isPrimary: true,
                contactId: contactId
            )
        ]
    )
    
    ContactRow(
        contact: contact,
        onTransactionCountTap: { _ in },
        onSendTap: { contact in
            print("Send button tapped for: \(contact.displayName)")
        },
        selectedContact: $selectedContact
    )
    .padding()
}
