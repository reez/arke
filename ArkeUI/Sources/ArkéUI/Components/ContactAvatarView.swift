//
//  ContactAvatarView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/5/25.
//

import SwiftUI

public struct ContactAvatarView: View {
    let avatarData: Data?
    let size: CGFloat
    let fallbackText: String?
    
    public init(avatarData: Data?, size: CGFloat, fallbackText: String? = nil) {
        self.avatarData = avatarData
        self.size = size
        self.fallbackText = fallbackText
    }
    
    public var body: some View {
        Group {
            if let avatarData = avatarData,
               let image = createImage(from: avatarData) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                    )
            } else {
                fallbackView
            }
        }
    }
    
    @ViewBuilder
    private var fallbackView: some View {
        if let fallbackText = fallbackText, !fallbackText.isEmpty {
            // Show initials
            Circle()
                .fill(Color.Arke.gold)
                .frame(width: size, height: size)
                .overlay {
                    Text(fallbackText.prefix(1).uppercased())
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(.white)
                }
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                )
        } else {
            // Show person icon
            Image(systemName: "person")
                .font(.system(size: size * 0.5))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(Color.Arke.gold)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                )
        }
    }
    
    private func createImage(from data: Data) -> Image? {
        #if os(macOS)
        if let nsImage = NSImage(data: data) {
            return Image(nsImage: nsImage)
        }
        #else
        if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        #endif
        return nil
    }
}

#Preview("With Fallback Text") {
    VStack(spacing: 20) {
        ContactAvatarView(avatarData: nil, size: 40, fallbackText: "Alice")
        ContactAvatarView(avatarData: nil, size: 60, fallbackText: "Bob")
        ContactAvatarView(avatarData: nil, size: 80, fallbackText: "Charlie")
    }
    .padding()
}

#Preview("Without Fallback Text") {
    VStack(spacing: 20) {
        ContactAvatarView(avatarData: nil, size: 40, fallbackText: nil)
        ContactAvatarView(avatarData: nil, size: 60, fallbackText: nil)
        ContactAvatarView(avatarData: nil, size: 80, fallbackText: nil)
    }
    .padding()
}

#Preview("Various Sizes") {
    HStack(spacing: 20) {
        ContactAvatarView(avatarData: nil, size: 24, fallbackText: "S")
        ContactAvatarView(avatarData: nil, size: 32, fallbackText: "M")
        ContactAvatarView(avatarData: nil, size: 48, fallbackText: "L")
        ContactAvatarView(avatarData: nil, size: 64, fallbackText: "XL")
        ContactAvatarView(avatarData: nil, size: 80, fallbackText: "XXL")
    }
    .padding()
}

#Preview("Empty Fallback Text") {
    VStack(spacing: 20) {
        ContactAvatarView(avatarData: nil, size: 60, fallbackText: "")
        ContactAvatarView(avatarData: nil, size: 60, fallbackText: nil)
    }
    .padding()
}
