//
//  PaymentDestinationItem.swift
//  Arké
//
//  Created by Christoph on 11/18/25.
//

import SwiftUI

struct PaymentDestinationItem: View {
    let formatName: String
    let shortAddress: String
    let estimatedFee: Int?
    let isSelectable: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Group {
            if isSelectable {
                Button {
                    onTap()
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }
    
    private var rowContent: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatName)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text(shortAddress)
                    .font(.body)
            }
            
            Spacer()
            
            if let fee = estimatedFee {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Estimated fee")
                        .foregroundColor(.secondary)
                    
                    Text(fee > 0 ? "~\(BitcoinFormatter.shared.formatAmount(fee))" : "Free")
                        .font(.body)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }
    
    private var borderColor: Color {
        if isSelected {
            return .arkeGold
        } else if isSelectable {
            return Color(nsColor: .separatorColor)
        } else {
            return Color(nsColor: .separatorColor).opacity(0.5)
        }
    }
}

#Preview("With Fee") {
    @Previewable @State var isSelected = false
    
    PaymentDestinationItem(
        formatName: "Bitcoin Address",
        shortAddress: "bc1q...xyz",
        estimatedFee: 250,
        isSelectable: true,
        isSelected: isSelected,
        onTap: { isSelected.toggle() }
    )
    .padding()
}

#Preview("No Fee") {
    @Previewable @State var isSelected = true
    
    PaymentDestinationItem(
        formatName: "Lightning Invoice",
        shortAddress: "lnbc...abc",
        estimatedFee: 0,
        isSelectable: true,
        isSelected: isSelected,
        onTap: { isSelected.toggle() }
    )
    .padding()
}

#Preview("Without Fee Info") {
    @Previewable @State var isSelected = false
    
    PaymentDestinationItem(
        formatName: "Payment Address",
        shortAddress: "tb1q...def",
        estimatedFee: nil,
        isSelectable: true,
        isSelected: isSelected,
        onTap: { isSelected.toggle() }
    )
    .padding()
}

#Preview("Not Selectable") {
    @Previewable @State var isSelected = false
    
    PaymentDestinationItem(
        formatName: "Payment Address",
        shortAddress: "tb1q...def",
        estimatedFee: 250,
        isSelectable: false,
        isSelected: isSelected,
        onTap: { isSelected.toggle() }
    )
    .padding()
}
