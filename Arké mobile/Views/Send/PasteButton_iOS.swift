//
//  PasteButton_iOS.swift
//  Arké
//
//  Created by Assistant on 12/17/25.
//

import SwiftUI

/// A circular button that pastes clipboard content into the send form
/// Appears on the camera view when clipboard contains content
struct PasteButton_iOS: View {
    let action: () -> Void
    
    private let buttonSize: CGFloat = 64
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Icon
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(ScaleButtonStyle())
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        .accessibilityLabel("Paste from clipboard")
        .accessibilityHint("Pastes payment address or invoice from clipboard")
    }
}

// MARK: - Button Style

/// A button style that scales down on press with haptic feedback
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    // Haptic feedback on press
                    #if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    #endif
                }
            }
    }
}

// MARK: - Previews

#Preview("Paste Button") {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()
        
        PasteButton_iOS {
            print("Paste tapped")
        }
    }
}

#Preview("With Camera Background") {
    ZStack {
        // Simulate camera view
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        // Floating buttons in corners
        VStack {
            HStack {
                // Contact button on left
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 30)
                
                Spacer()
                
                // Paste button on right
                PasteButton_iOS {
                    print("Paste tapped")
                }
                .padding(.trailing, 30)
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
}
