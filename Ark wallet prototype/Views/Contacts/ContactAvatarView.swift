//
//  ContactAvatarView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/5/25.
//

import SwiftUI

struct ContactAvatarView: View {
    let contact: ContactModel
    let size: CGFloat
    
    var body: some View {
        if let avatarData = contact.avatarData,
           let nsImage = NSImage(data: avatarData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: size * 0.8))
                .foregroundColor(.blue)
                .frame(width: size, height: size)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
        }
    }
}
