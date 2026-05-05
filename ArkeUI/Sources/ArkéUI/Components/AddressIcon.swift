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
        if let blockieImage = Blockies(seed: address, size: 8, scale: 4)
            .createImage() {
            #if os(macOS)
            Image(nsImage: blockieImage)
                .resizable()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            #else
            Image(uiImage: blockieImage)
                .resizable()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            #endif
        }
    }
}
