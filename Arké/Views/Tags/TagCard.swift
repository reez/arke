//
//  TagCard.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/30/25.
//

import SwiftUI

struct TagCard: View {
    let tag: TagModel
    let tagStatistic: TagStatistic
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTransactionCountTap: ((TagModel) -> Void)?
    
    init(tag: TagModel, tagStatistic: TagStatistic, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void, onTransactionCountTap: ((TagModel) -> Void)? = nil) {
        self.tag = tag
        self.tagStatistic = tagStatistic
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTransactionCountTap = onTransactionCountTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TagChip(tag: tag)
                
                Spacer()
                
                Menu {
                    Button("Edit") {
                        onEdit()
                    }
                    
                    Divider()
                    
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20, height: 20)
            }
            
            // Tag statistics
            VStack(alignment: .leading, spacing: 4) {
                if let onTransactionCountTap = onTransactionCountTap,
                   tagStatistic.transactionCount > 0 {
                    Button {
                        onTransactionCountTap(tag)
                    } label: {
                        Text("\(tagStatistic.transactionCount) transactions")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("\(tagStatistic.transactionCount) transactions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if tagStatistic.transactionCount > 0 {
                    Text(tagStatistic.formattedTotalAmount)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(tagStatistic.totalAmount >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tag.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Tag Card") {
    VStack(spacing: 16) {
        TagCard(
            tag: TagModel(name: "Coffee", colorHex: "#8B4513", emoji: "☕"),
            tagStatistic: TagStatistic(
                tagId: UUID(),
                tagName: "☕ Coffee",
                transactionCount: 42,
                totalAmount: -125000, // Net spent (negative)
                sentAmount: 125000,
                receivedAmount: 0,
                isActive: true
            ),
            onEdit: {
                print("Edit coffee tag")
            },
            onDelete: {
                print("Delete coffee tag")
            },
            onTransactionCountTap: { tag in
                print("Tapped transaction count for \(tag.name)")
            }
        )
        
        TagCard(
            tag: TagModel(name: "Investment", colorHex: "#FFD700", emoji: "📈"),
            tagStatistic: TagStatistic(
                tagId: UUID(),
                tagName: "📈 Investment",
                transactionCount: 15,
                totalAmount: 500000, // Net gain (positive)
                sentAmount: 1000000,
                receivedAmount: 1500000,
                isActive: true
            ),
            onEdit: {
                print("Edit investment tag")
            },
            onDelete: {
                print("Delete investment tag")
            },
            onTransactionCountTap: { tag in
                print("Tapped transaction count for \(tag.name)")
            }
        )
        
        // Example without transaction count tap (shows as regular text)
        TagCard(
            tag: TagModel(name: "Bills", colorHex: "#FF4444", emoji: "📄"),
            tagStatistic: TagStatistic(
                tagId: UUID(),
                tagName: "📄 Bills",
                transactionCount: 8,
                totalAmount: -200000, // Net spent (negative)
                sentAmount: 200000,
                receivedAmount: 0,
                isActive: true
            ),
            onEdit: {
                print("Edit bills tag")
            },
            onDelete: {
                print("Delete bills tag")
            }
        )
    }
    .padding()
    .frame(width: 300)
}
