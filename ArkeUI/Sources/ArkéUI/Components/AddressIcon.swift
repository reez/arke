//
//  AddressIcon.swift
//  Ark wallet prototype
//
//  Created by Assistant on 5/5/26.
//

import SwiftUI

public struct AddressIcon: View {
    let address: String
    let size: CGFloat
    
    public init(address: String, size: CGFloat = 32) {
        self.address = address
        self.size = size
    }
    
    public var body: some View {
        let blockies = Blockies(seed: address, size: 8, scale: 4)
        if let blockieImage = blockies.createImage(customScale: 4, style: .rounded(spacing: 5, cornerRadius: 3)) {
            #if os(macOS)
            let backgroundColor = Color(nsColor: blockies.bgColor)
            Image(nsImage: blockieImage)
                .resizable()
                .frame(width: size, height: size)
                .padding(size/8)
                .background(backgroundColor)
            #else
            let backgroundColor = Color(uiColor: blockies.bgColor)
            Image(uiImage: blockieImage)
                .resizable()
                .frame(width: size, height: size)
                .padding(size/8)
                .background(backgroundColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: size/8))
            #endif
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Different addresses to show variety
        HStack(spacing: 16) {
            AddressIcon(address: "tark1pem36wcfzqqpjd0k62h4q3lff58qd3s6uwkxmepfj0vej6feputqefw3xxh075hpzqypwp4zfyppxq3ghr57y8n2n5afsn3cyzjnydhcleek3a3cj22swd6q45fepe", size: 32)
            AddressIcon(address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh", size: 32)
            AddressIcon(address: "3J98t1WpEZ73CNmYviecrnyiWrnqRhWNLy", size: 32)
        }

        // Different sizes
        HStack(spacing: 16) {
            VStack {
                AddressIcon(address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh", size: 24)
                Text("24pt")
                    .font(.caption)
            }
            VStack {
                AddressIcon(address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh", size: 32)
                Text("32pt")
                    .font(.caption)
            }
            VStack {
                AddressIcon(address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh", size: 48)
                Text("48pt")
                    .font(.caption)
            }
            VStack {
                AddressIcon(address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh", size: 64)
                Text("64pt")
                    .font(.caption)
            }
        }
    }
    .padding()
}
