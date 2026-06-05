//
//  SlideToActionButton.swift
//  ArkeUI
//
//  Created by Assistant on 6/5/26.
//

import SwiftUI

#if os(iOS)
import UIKit

/// A slide-to-action button with iOS 18 Liquid Glass styling
/// Requires the user to drag a slider to confirm a critical action
public struct SlideToActionButton_iOS: View {
    let text: String
    let icon: String
    let tintColor: Color
    let isEnabled: Bool
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isCompleted = false

    private let buttonHeight: CGFloat = 56
    private let thumbSize: CGFloat = 48
    private let dragThreshold: CGFloat = 0.95

    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let successHaptic = UINotificationFeedbackGenerator()

    public init(
        text: String,
        icon: String = "arrow.right",
        tintColor: Color = .red,
        isEnabled: Bool = true,
        onComplete: @escaping () -> Void
    ) {
        self.text = text
        self.icon = icon
        self.tintColor = tintColor
        self.isEnabled = isEnabled
        self.onComplete = onComplete
    }

    public var body: some View {
        GeometryReader { geometry in
            let maxDragDistance = geometry.size.width - thumbSize - 8
            let progress = min(max(dragOffset / maxDragDistance, 0), 1)

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: buttonHeight / 2)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // Progress fill
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: buttonHeight / 2)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            tintColor.opacity(0.3),
                                            tintColor.opacity(0.5)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: dragOffset + thumbSize)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: buttonHeight / 2)
                            .strokeBorder(tintColor.opacity(0.3), lineWidth: 2)
                    }

                // Text label
                Text(text)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(1.0 - progress * 0.7))
                    .frame(maxWidth: .infinity)

                // Sliding thumb
                Circle()
                    .fill(.thinMaterial)
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tintColor.opacity(0.8),
                                        tintColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .opacity(0.3 + progress * 0.7)
                    }
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(progress * 360))
                    }
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: tintColor.opacity(0.3 + progress * 0.4), radius: 8, x: 0, y: 2)
                    .offset(x: 4 + dragOffset)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard isEnabled && !isCompleted else { return }

                                let translation = value.translation.width
                                dragOffset = min(max(translation, 0), maxDragDistance)

                                // Haptic feedback at milestones
                                if progress > 0.5 && progress < 0.52 {
                                    hapticGenerator.impactOccurred(intensity: 0.5)
                                } else if progress > 0.75 && progress < 0.77 {
                                    hapticGenerator.impactOccurred(intensity: 0.7)
                                }
                            }
                            .onEnded { _ in
                                guard isEnabled && !isCompleted else { return }

                                if progress >= dragThreshold {
                                    // Completed - trigger action
                                    isCompleted = true
                                    successHaptic.notificationOccurred(.success)

                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = maxDragDistance
                                    }

                                    // Delay slightly for animation to complete
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        onComplete()
                                    }
                                } else {
                                    // Reset with bounce
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
            .frame(height: buttonHeight)
        }
        .frame(height: buttonHeight)
        .opacity(isEnabled ? 1.0 : 0.5)
        .onAppear {
            hapticGenerator.prepare()
            successHaptic.prepare()
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        SlideToActionButton_iOS(
            text: "Slide to Delete",
            icon: "trash.fill",
            tintColor: Color.Arke.red
        ) {
            print("Delete action completed")
        }
        .padding(.horizontal, 25)
        
        SlideToActionButton_iOS(
            text: "Slide to Send",
            icon: "checkmark",
            tintColor: Color.Arke.gold
        ) {
            print("Confirm action completed")
        }
        .padding(.horizontal, 25)
        
        SlideToActionButton_iOS(
            text: "Slide to Confirm",
            icon: "checkmark",
            tintColor: Color.Arke.green
        ) {
            print("Confirm action completed")
        }
        .padding(.horizontal, 25)

        SlideToActionButton_iOS(
            text: "Slide to Continue",
            icon: "arrow.right",
            tintColor: Color.Arke.blue
        ) {
            print("Continue action completed")
        }
        .padding(.horizontal, 25)

        SlideToActionButton_iOS(
            text: "Disabled Action",
            icon: "lock.fill",
            tintColor: .gray,
            isEnabled: false
        ) {
            print("This shouldn't trigger")
        }
        .padding(.horizontal, 25)
    }
    .padding()
    .background(Color.black)
}
#endif
