//
//  ContactAvatarView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/5/25.
//

import SwiftUI

struct ContactAvatarView: View {
    let avatarData: Data?
    let size: CGFloat
    
    var body: some View {
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
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size * 0.8))
                    .foregroundColor(.blue)
                    .frame(width: size, height: size)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                    )
            }
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
