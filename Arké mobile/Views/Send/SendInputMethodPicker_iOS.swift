//
//  SendInputMethodPicker.swift
//  Arké
//
//  Created by Assistant on 12/15/25.
//

import SwiftUI
import ArkeUI

/// A floating picker that allows users to switch between camera (QR scanning) and keyboard input methods
struct SendInputMethodPicker_iOS: View {
    @Binding var inputMethod: SendInputMethod_iOS
    
    var body: some View {
        Button {
            let newMode: SendInputMethod_iOS = inputMethod == .camera ? .input : .camera
            print("[SendInputMethodPicker_iOS] Mode switching from \(inputMethod) to \(newMode)")
            
            withAnimation(.smooth(duration: 0.3)) {
                inputMethod = inputMethod == .camera ? .input : .camera
            }
        } label: {
            GlassEffectContainer(spacing: 8.0) {
                HStack(spacing: 0) {
                    Label("Scan", systemImage: "qrcode.viewfinder")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .fontWeight(inputMethod == .camera ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(inputMethod == .camera ? Color.Arke.gold : .secondary)
                    
                    Label("Input", systemImage: "keyboard")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .fontWeight(inputMethod == .input ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(inputMethod == .input ? Color.Arke.gold : .secondary)
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
                            .offset(x: inputMethod == .camera ? 4 : geometry.size.width / 2, y: 2)
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
        .accessibilityLabel("Input Method")
        .accessibilityValue(inputMethod == .camera ? "Camera" : "Keyboard")
        .accessibilityHint("Double tap to switch input method")
    }
}

// MARK: - Previews

#Preview("Camera Selected") {
    @Previewable @State var inputMethod: SendInputMethod_iOS = .camera
    
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            SendInputMethodPicker_iOS(inputMethod: $inputMethod)
            Spacer()
        }
    }
}

#Preview("Input Selected") {
    @Previewable @State var inputMethod: SendInputMethod_iOS = .input
    
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            SendInputMethodPicker_iOS(inputMethod: $inputMethod)
            Spacer()
        }
    }
}

#Preview("Interactive") {
    @Previewable @State var inputMethod: SendInputMethod_iOS = .camera
    
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            SendInputMethodPicker_iOS(inputMethod: $inputMethod)
            
            Spacer()
            
            Text("Current Method: \(inputMethod == .camera ? "Camera" : "Input")")
                .font(.headline)
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(8)
                .padding()
        }
    }
}
