//
//  TransactionListItem.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI

struct TransactionListItem: View {
    let transaction: TransactionModel
    @Binding var selectedTransaction: TransactionModel?
    @Environment(WalletManager.self) private var walletManager
    
    private var transactionDisplayText: String {
        // Access dataVersion to create observation dependency
        _ = walletManager.dataVersion
        
        if let contact = transaction.associatedContacts.first {
            switch transaction.transactionType {
            case .received:
                return "From \(contact.cachedName)"
            case .sent:
                return "To \(contact.cachedName)"
            case .pending:
                return "Pending..."
            }
        }
        return transaction.transactionType.displayName
    }
    
    private var dateAndTagsText: String {
        // Access dataVersion to create observation dependency
        _ = walletManager.dataVersion
        
        var components: [String] = [transaction.formattedDate]
        
        // Add tag names
        let tagNames = transaction.associatedTags.map { $0.name }
        components.append(contentsOf: tagNames)
        
        return components.joined(separator: " · ")
    }
    
    var body: some View {
        // Access dataVersion at the beginning to ensure entire body observes changes
        let _ = walletManager.dataVersion
        
        HStack(spacing: 12) {
            // Transaction Icon with optional tag badge
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let contact = transaction.associatedContacts.first {
                        // Show contact avatar
                        ContactAvatarView(avatarData: contact.avatarData, size: 32)
                    } else if let firstTag = transaction.associatedTags.first {
                        Text(firstTag.emoji)
                            .font(.system(size: 11))
                            .frame(width: 32, height: 32)
                            .background(firstTag.color.opacity(0.2))
                            .foregroundColor(firstTag.color)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        // Show default transaction icon
                        Image(systemName: transaction.transactionType.iconName)
                            .font(.title3)
                            .foregroundColor(transaction.transactionType.iconColor)
                            .frame(width: 32, height: 32)
                            .background(transaction.transactionType.iconColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // Tag emoji badge
                if let firstTag = transaction.associatedTags.first,
                   transaction.associatedContacts.first != nil {
                    Text(firstTag.emoji)
                        .font(.system(size: 9))
                        .frame(width: 16, height: 16)
                        .background(Color.white)
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
            }
            .frame(width: 32, height: 32)
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transactionDisplayText)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(dateAndTagsText)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {                
                if transaction.transactionStatus != .confirmed {
                    TransactionStatusBadge(status: transaction.transactionStatus)
                }
                
                Text(transaction.formattedAmount)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(transaction.transactionType.amountColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(selectedTransaction?.txid == transaction.txid ? Color.arkeGold.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .cornerRadius(15)
        .onTapGesture {
            selectedTransaction = transaction
        }
    }
}

#Preview("Transaction List Item") {
    @Previewable @State var selectedTransaction: TransactionModel? = nil
    
    let sampleTransactions = [
        TransactionModel(
            txid: "movement_1",
            movementId: 1,
            recipientIndex: nil,
            type: .received,
            amount: 50000,
            date: Date().addingTimeInterval(-3600), // 1 hour ago
            status: .confirmed,
            address: nil
        ),
        TransactionModel(
            txid: "movement_2_recipient_0",
            movementId: 2,
            recipientIndex: 0,
            type: .sent,
            amount: 25000,
            date: Date().addingTimeInterval(-86400), // 1 day ago
            status: .pending,
            address: "3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy"
        ),
        TransactionModel(
            txid: "movement_3",
            movementId: 3,
            recipientIndex: nil,
            type: .received,
            amount: 10000,
            date: Date().addingTimeInterval(-300), // 5 minutes ago
            status: .confirmed,
            address: nil
        )
    ]
    
    return VStack(spacing: 0) {
        ForEach(sampleTransactions) { transaction in
            TransactionListItem(
                transaction: transaction,
                selectedTransaction: $selectedTransaction
            )
            Divider()
        }
    }
    .padding()
}
