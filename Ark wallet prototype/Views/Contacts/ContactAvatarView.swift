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
        if let avatarData = avatarData,
           let nsImage = NSImage(data: avatarData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    RoundedRectangle(cornerRadius: size/2)
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
                    RoundedRectangle(cornerRadius: size/2)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                    )
        }
    }
}
