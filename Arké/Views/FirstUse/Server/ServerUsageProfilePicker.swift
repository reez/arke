//
//  ServerUsageProfilePicker.swift
//  Arké
//
//  Created by Christoph on 11/25/25.
//

import SwiftUI

struct ServerUsageProfilePicker: View {
    @Binding var selectedProfile: ServerUsageProfile
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        
                        Text("Your Usage Pattern")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 12) {
                    ServerProfileButton(
                        title: "Casual",
                        isSelected: selectedProfile == .casual,
                        action: { selectedProfile = .casual }
                    )
                    
                    ServerProfileButton(
                        title: "Spender",
                        isSelected: selectedProfile == .spender,
                        action: { selectedProfile = .spender }
                    )
                    
                    ServerProfileButton(
                        title: "Saver",
                        isSelected: selectedProfile == .saver,
                        action: { selectedProfile = .saver }
                    )
                }
            }
            
            // Expandable Profile Details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ProfileDetailRow(
                        label: "Average Balance:",
                        value: "\(selectedProfile.averageBalance.formatted()) ₿"
                    )
                    
                    ProfileDetailRow(
                        label: "Transactions per month:",
                        value: "\(selectedProfile.onArkPayments + selectedProfile.lightningPayments)"
                    )
                    
                    ProfileDetailRow(
                        label: "Monthly transaction volume:",
                        value: "\(selectedProfile.monthlyVolume.formatted()) ₿"
                    )
                    
                    ProfileDetailRow(
                        label: "Refreshes:",
                        value: "\(selectedProfile.refreshesPerMonth) per month"
                    )
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.05))
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                ))
            }
        }
    }
}

// MARK: - Profile Detail Row

private struct ProfileDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.white.opacity(0.75))
            
            Text(value)
                .font(.body)
                .foregroundStyle(.white)
            
            Spacer()
        }
    }
}

#Preview {
    @Previewable @State var selectedProfile: ServerUsageProfile = .casual
    
    ServerUsageProfilePicker(selectedProfile: $selectedProfile)
        .padding()
        .background(Color.black)
}
