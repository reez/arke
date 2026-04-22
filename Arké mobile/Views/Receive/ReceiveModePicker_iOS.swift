//
//  ReceiveModePicker_iOS.swift
//  Arké
//
//  Created by Assistant on 12/16/25.
//

import SwiftUI
import ArkeUI

/// A floating picker that allows users to switch between QR code display and addresses list
struct ReceiveModePicker_iOS: View {
    @Binding var mode: ReceiveMode_iOS
    
    var body: some View {
        GlassEffectContainer(spacing: 8.0) {
            HStack(spacing: 0) {
                Label("label_qr_code", systemImage: "qrcode")
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .fontWeight(mode == .qrcode ? .semibold : .regular)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(mode == .qrcode ? Color.Arke.gold : .secondary)
                    .animation(nil, value: mode)
                
                Label("label_addresses", systemImage: "list.bullet")
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .fontWeight(mode == .addresses ? .semibold : .regular)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(mode == .addresses ? Color.Arke.gold : .secondary)
                    .animation(nil, value: mode)
            }
            .background {
                GeometryReader { geometry in
                    Capsule()
                        .fill(Color.black.opacity(0.05))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .frame(width: geometry.size.width / 2 - 4, height: 40)
                        .offset(x: mode == .qrcode ? 4 : geometry.size.width / 2, y: 2)
                        .allowsHitTesting(false)
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .frame(width: 120)
        .contentShape(Capsule())
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    let newMode: ReceiveMode_iOS = mode == .qrcode ? .addresses : .qrcode
                    print("[ReceiveModePicker_iOS] Mode switching from \(mode) to \(newMode)")
                    
                    withAnimation(.smooth(duration: 0.3)) {
                        mode = newMode
                    }
                }
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("receive_mode")
        .accessibilityValue(mode == .qrcode ? "QR Code" : "Addresses")
        .accessibilityHint(String(localized: "receive_double_tap_mode"))
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


