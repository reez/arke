//
//  TagRowContent.swift
//  Ark wallet prototype
//
//  Created by Assistant on 12/2/25.
//

import SwiftUI

/// Shared content component for displaying tag information in rows
/// Can be customized per platform while maintaining consistent data display
struct TagRowContent: View {
    let tag: TagModel
    let statistic: TagStatistic
    let showNetChangeBar: Bool
    let largestPositiveAmount: Int
    let largestNegativeAmount: Int
    
    init(
        tag: TagModel,
        statistic: TagStatistic,
        showNetChangeBar: Bool = false,
        largestPositiveAmount: Int = 0,
        largestNegativeAmount: Int = 0
    ) {
        self.tag = tag
        self.statistic = statistic
        self.showNetChangeBar = showNetChangeBar
        self.largestPositiveAmount = largestPositiveAmount
        self.largestNegativeAmount = largestNegativeAmount
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Tag chip
            TagChip(tag: tag, size: .medium)
            
            Spacer()
            
            // Transaction count
            Text("\(statistic.transactionCount) transaction\(statistic.transactionCount == 1 ? "" : "s")")
                .font(.body)
                .foregroundColor(.secondary)
            
            // Amount
            if statistic.transactionCount > 0 {
                Text(statistic.formattedTotalAmount)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(statistic.totalAmount >= 0 ? .green : .red)
                    .frame(minWidth: 80, alignment: .trailing)
            }
            
            // Optional net change bar (typically for macOS)
            if showNetChangeBar && (largestPositiveAmount > 0 || largestNegativeAmount < 0) {
                NetChangeBar(
                    currentAmount: statistic.totalAmount,
                    largestPositiveAmount: largestPositiveAmount,
                    largestNegativeAmount: largestNegativeAmount
                )
                .frame(width: 100)
            }
        }
    }
}

// MARK: - Preview

#Preview("With Transactions - Positive") {
    TagRowContent(
        tag: TagModel(
            name: "Groceries",
            colorHex: "#4A90E2",
            emoji: "🛒"
        ),
        statistic: TagStatistic(
            tagId: UUID(),
            tagName: "Groceries",
            transactionCount: 15,
            totalAmount: 45000,
            sentAmount: 5000,
            receivedAmount: 50000
        )
    )
    .padding()
}

#Preview("With Transactions - Negative") {
    TagRowContent(
        tag: TagModel(
            name: "Shopping",
            colorHex: "#E24A90",
            emoji: "🛍️"
        ),
        statistic: TagStatistic(
            tagId: UUID(),
            tagName: "Shopping",
            transactionCount: 8,
            totalAmount: -25000,
            sentAmount: 30000,
            receivedAmount: 5000
        )
    )
    .padding()
}

#Preview("No Transactions") {
    TagRowContent(
        tag: TagModel(
            name: "Travel",
            colorHex: "#90E24A",
            emoji: "✈️"
        ),
        statistic: TagStatistic(
            tagId: UUID(),
            tagName: "Travel",
            transactionCount: 0,
            totalAmount: 0,
            sentAmount: 0,
            receivedAmount: 0
        )
    )
    .padding()
}

#Preview("With Net Change Bar") {
    TagRowContent(
        tag: TagModel(
            name: "Salary",
            colorHex: "#4AE290",
            emoji: "💰"
        ),
        statistic: TagStatistic(
            tagId: UUID(),
            tagName: "Salary",
            transactionCount: 3,
            totalAmount: 150000,
            sentAmount: 0,
            receivedAmount: 150000
        ),
        showNetChangeBar: true,
        largestPositiveAmount: 200000,
        largestNegativeAmount: -100000
    )
    .padding()
    .frame(width: 500)
}
