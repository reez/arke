//
//  ReceiveModePicker_iOS.swift
//  Arké
//
//  Created by Assistant on 12/16/25.
//

import SwiftUI

/// A floating picker that allows users to switch between QR code display and addresses list
struct ReceiveModePicker_iOS: View {
    @Binding var mode: ReceiveMode_iOS
    
    var body: some View {
        Button {
            withAnimation(.smooth(duration: 0.3)) {
                mode = mode == .qrcode ? .addresses : .qrcode
            }
        } label: {
            GlassEffectContainer(spacing: 8.0) {
                HStack(spacing: 0) {
                    Label("QR Code", systemImage: "qrcode")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .fontWeight(mode == .qrcode ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(mode == .qrcode ? Color.arkeGold : .secondary)
                    
                    Label("Addresses", systemImage: "list.bullet")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .fontWeight(mode == .addresses ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(mode == .addresses ? Color.arkeGold : .secondary)
                }
                .background {
                    // Selection indicator - simple fill without glass effect
                    GeometryReader { geometry in
                        Capsule()
                            .fill(Color.black.opacity(0.05))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .frame(width: geometry.size.width / 2 - 4, height: 40)
                            .offset(x: mode == .qrcode ? 4 : geometry.size.width / 2, y: 2)
                    }
                }
                .padding(4)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .frame(width: 120)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Receive Mode")
        .accessibilityValue(mode == .qrcode ? "QR Code" : "Addresses")
        .accessibilityHint("Double tap to switch receive mode")
    }
}

// MARK: - Previews

#Preview("QR Code Selected") {
    @Previewable @State var mode: ReceiveMode_iOS = .qrcode
    
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            ReceiveModePicker_iOS(mode: $mode)
            Spacer()
        }
    }
}

#Preview("Addresses Selected") {
    @Previewable @State var mode: ReceiveMode_iOS = .addresses
    
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            ReceiveModePicker_iOS(mode: $mode)
            Spacer()
        }
    }
}

#Preview("Interactive") {
    @Previewable @State var mode: ReceiveMode_iOS = .qrcode
    
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            ReceiveModePicker_iOS(mode: $mode)
            
            Spacer()
            
            Text("Current Mode: \(mode == .qrcode ? "QR Code" : "Addresses")")
                .font(.headline)
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(8)
                .padding()
        }
    }
}
