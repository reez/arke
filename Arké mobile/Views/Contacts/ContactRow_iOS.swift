//
//  ContactRow_iOS.swift
//  Arké
//
//  Created by Christoph on 12/4/25.
//

import SwiftUI

/// iOS-specific row component for displaying contact information
struct ContactRow_iOS: View {
    let contact: ContactModel
    let onTransactionCountTap: () -> Void
    let onSendTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            avatarView
            
            // Contact info
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let notes = contact.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Transaction statistics
                if let transactionCount = contact.transactionCount, transactionCount > 0 {
                    HStack(spacing: 8) {
                        Text("\(transactionCount) transaction\(transactionCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let sentAmount = contact.formattedSentAmount {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.up")
                                Text(sentAmount)
                            }
                            .font(.caption2)
                            .foregroundColor(.primary)
                        }
                        
                        if let receivedAmount = contact.formattedReceivedAmount {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.down")
                                Text(receivedAmount)
                            }
                            .font(.caption2)
                            .foregroundColor(.green)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Send button
            if contact.primaryAddress != nil {
                Button(action: onSendTap) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if contact.transactionCount ?? 0 > 0 {
                onTransactionCountTap()
            }
        }
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if let avatarData = contact.avatarData,
           let uiImage = UIImage(data: avatarData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(
                    Circle()
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
    }
}
