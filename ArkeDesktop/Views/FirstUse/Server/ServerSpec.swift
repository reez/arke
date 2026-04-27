//
//  ServerSpec.swift
//  Arké
//
//  Created by Christoph on 11/25/25.
//

import SwiftUI

struct ServerSpec: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        ServerSpec(label: "CPU", value: "2.4 GHz")
        ServerSpec(label: "Memory", value: "16 GB")
        ServerSpec(label: "Storage", value: "512 GB SSD")
    }
    .padding()
    .background(.black)
}
