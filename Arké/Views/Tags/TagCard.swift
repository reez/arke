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
    let largestPositiveAmount: Int
    let largestNegativeAmount: Int
    
    init(
        tag: TagModel,
        tagStatistic: TagStatistic,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onTransactionCountTap: ((TagModel) -> Void)? = nil,
        largestPositiveAmount: Int = 0,
        largestNegativeAmount: Int = 0
    ) {
        self.tag = tag
        self.tagStatistic = tagStatistic
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTransactionCountTap = onTransactionCountTap
        self.largestPositiveAmount = largestPositiveAmount
        self.largestNegativeAmount = largestNegativeAmount
    }
    
    var body: some View {
        HStack(spacing: 20) {
            TagChip(tag: tag)
            
            Spacer()
            
            // Tag statistics
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
            
            Spacer()
            
            if tagStatistic.transactionCount > 0 {
                Text(tagStatistic.formattedTotalAmount)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(tagStatistic.totalAmount >= 0 ? .green : .red)
            }
            
            // Net change visualization bar
            if largestPositiveAmount > 0 || largestNegativeAmount < 0 {
                netChangeBar
            }
            
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
        .padding(.vertical, 10)
    }
    
    // MARK: - Net Change Bar
    
    @ViewBuilder
    private var netChangeBar: some View {
        GeometryReader { geometry in
            let totalRange = largestPositiveAmount + abs(largestNegativeAmount)
            let zeroPosition: CGFloat = totalRange > 0 ? CGFloat(abs(largestNegativeAmount)) / CGFloat(totalRange) : 0.5
            let currentAmount = tagStatistic.totalAmount
            
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)
                
                // Value bar
                if currentAmount != 0 {
                    let barWidth: CGFloat = {
                        if currentAmount > 0 {
                            // Positive value: bar extends from zero to the right
                            let percentage = CGFloat(currentAmount) / CGFloat(largestPositiveAmount)
                            return geometry.size.width * (1.0 - zeroPosition) * percentage
                        } else {
                            // Negative value: bar extends from zero to the left
                            let percentage = CGFloat(abs(currentAmount)) / CGFloat(abs(largestNegativeAmount))
                            return geometry.size.width * zeroPosition * percentage
                        }
                    }()
                    
                    let barOffset: CGFloat = {
                        if currentAmount > 0 {
                            return geometry.size.width * zeroPosition
                        } else {
                            return geometry.size.width * zeroPosition - barWidth
                        }
                    }()
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(currentAmount >= 0 ? Color.green : Color.red)
                        .frame(width: barWidth, height: 4)
                        .offset(x: barOffset)
                    
                    // Zero line indicator
                    Rectangle()
                        .fill(Color.black.opacity(1))
                        .frame(width: 1, height: 8)
                        .offset(x: geometry.size.width * zeroPosition)
                }
            }
        }
        .frame(height: 6)
        .frame(maxWidth: 150)
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
            },
            largestPositiveAmount: 500000,
            largestNegativeAmount: -200000
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
            },
            largestPositiveAmount: 500000,
            largestNegativeAmount: -200000
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
            },
            largestPositiveAmount: 500000,
            largestNegativeAmount: -200000
        )
    }
    .padding()
    .frame(width: 500)
}
