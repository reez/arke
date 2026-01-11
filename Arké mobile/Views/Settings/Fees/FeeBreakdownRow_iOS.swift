//
//  FeeBreakdownRow_iOS.swift
//  Arké
//
//  Created by Christoph on 1/11/26.
//

import SwiftUI

/// Row showing fee breakdown with percentage
struct FeeBreakdownRow_iOS: View {
    let label: String
    let amount: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return (Double(amount) / Double(total)) * 100.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(label)
                }
                Spacer()
                Text(BitcoinFormatter.shared.formatAmount(amount))
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                FeePercentageBar_iOS(percentage: percentage, color: color)
                    .frame(height: 6)
                Text(String(format: "%.1f%%", percentage))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 45, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }
}
