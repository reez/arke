//
//  ServerProfileButton.swift
//  Arké
//
//  Created by Christoph on 11/25/25.
//

import SwiftUI

struct ServerProfileButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.arkeDark : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.arkeGold : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        ServerProfileButton(title: "Default", isSelected: true) {
            print("Default tapped")
        }
        
        ServerProfileButton(title: "High Priority", isSelected: false) {
            print("High Priority tapped")
        }
        
        ServerProfileButton(title: "Economy", isSelected: false) {
            print("Economy tapped")
        }
    }
    .padding()
    .background(Color.black)
}
