//
//  BalanceTypeSelectionSheet.swift
//  Arké
//
//  Created by Assistant on 1/27/26.
//

import SwiftUI

struct BalanceTypeSelectionSheet_iOS: View {
    let viewModel: ReceiveViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("How do you want to receive?")
                        .font(.system(.title2, weight: .semibold))
                        .padding(.top, 30)
                    
                    /*
                    Text("Select how you'd like to receive Bitcoin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    */
                }
                .padding(.bottom, 20)
                
                // Balance type options
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(ReceiveBalanceType.allCases, id: \.self) { balanceType in
                            BalanceTypeOptionRow_iOS(
                                balanceType: balanceType,
                                isSelected: viewModel.selectedBalance == balanceType,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        viewModel.changeBalanceType(to: balanceType)
                                    }
                                    isPresented = false
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

struct BalanceTypeOptionRow_iOS: View {
    let balanceType: ReceiveBalanceType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                /*
                Image(systemName: iconForBalanceType)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.arkeGold : .primary)
                    .frame(width: 40)
                */
                
                // Title and Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(balanceType.rawValue)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text(balanceType.receiveDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                /*
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.arkeGold)
                }
                */
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.arkeGold.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.arkeGold.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var iconForBalanceType: String {
        switch balanceType {
        case .payments:
            return "bolt.circle.fill"
        case .savings:
            return "lock.shield.fill"
        case .paymentsAndSavings:
            return "square.stack.3d.up.fill"
        case .lightning:
            return "bolt.fill"
        }
    }
}
