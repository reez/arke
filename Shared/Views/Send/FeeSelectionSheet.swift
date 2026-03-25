//
//  FeeSelectionSheet.swift
//  Arké
//
//  Created by Assistant on 3/25/26.
//

import SwiftUI
import ArkeUI

/// Sheet for selecting on-chain transaction fee priority
struct FeeSelectionSheet: View {
    @Binding var selectedPriority: FeePriority
    let feeRates: OnchainFeeRates
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Fee Priority")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // Description
            Text("Choose how quickly you want your transaction to be confirmed")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            
            // Fee options
            VStack(spacing: 12) {
                ForEach(FeePriority.allCases) { priority in
                    FeeOptionRow(
                        priority: priority,
                        feeRate: feeRates.rate(for: priority),
                        isSelected: selectedPriority == priority,
                        onSelect: {
                            selectedPriority = priority
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Done button
            Button {
                onDismiss()
            } label: {
                Text("button_done")
                    .font(.title3)
                    .foregroundStyle(Color.Arke.gold3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Color.Arke.gold)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 450)
    }
}

/// Individual fee option row
private struct FeeOptionRow: View {
    let priority: FeePriority
    let feeRate: UInt64
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(priority.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text("(\(priority.estimatedConfirmationTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(feeRate) sat/vB")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.Arke.gold.opacity(0.1) : .ultraThinMaterial)
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

#Preview("Fee Selection Sheet") {
    @Previewable @State var selectedPriority: FeePriority = .medium
    
    FeeSelectionSheet(
        selectedPriority: $selectedPriority,
        feeRates: OnchainFeeRates(slow: 2, medium: 5, fast: 10),
        onDismiss: { print("Dismissed") }
    )
    .frame(height: 500)
    .padding()
}

#Preview("All Priorities") {
    @Previewable @State var selectedPriority: FeePriority = .medium
    
    VStack(spacing: 20) {
        ForEach(FeePriority.allCases) { priority in
            FeeOptionRow(
                priority: priority,
                feeRate: OnchainFeeRates.default.rate(for: priority),
                isSelected: selectedPriority == priority,
                onSelect: { selectedPriority = priority }
            )
        }
    }
    .padding()
    .frame(width: 400)
}
