//
//  FeeOptionRow.swift
//  Arke
//
//  Created by Christoph on 3/25/26.
//

import SwiftUI
import ArkeUI

struct FeeOptionRow: View {
    let priority: FeePriority
    let feeRate: UInt64
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(priority.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                
                    HStack(spacing: 8) {
                        Text(priority.estimatedConfirmationTime)
                            .font(.body)
                            .foregroundColor(.secondary)
                    
                        /*
                        Text("\(feeRate) sat/vB")
                            .font(.body)
                            .foregroundColor(.secondary)
                         */
                    }
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.Arke.gold : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.Arke.gold)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.Arke.gold.opacity(0.1))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.Arke.gold.opacity(0.5) : Color.arkeSeparatorColor.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
