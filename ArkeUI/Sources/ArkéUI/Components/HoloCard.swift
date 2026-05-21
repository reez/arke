//
//  HoloCard.swift
//  ArkeUI
//
//  Created by Christoph on 5/21/26.
//

import SwiftUI
import CoreMotion

// MARK: - Public API
// Drop this entire file into your Xcode project and use HoloCard in your views.
// Usage:
//   HoloCard(cardImageName: "card", maskImageName: "card-mask")
//       .frame(width: 340, height: 215)

/// A holographic card view with tilt-responsive effects
/// - Parameters:
///   - cardImageName: Name of the card image in your asset catalog
///   - maskImageName: Name of the mask image (with baked-in alpha) in your asset catalog
public struct HoloCard: View {
    let cardImageName: String
    let maskImageName: String

    @StateObject private var motion = MotionManager()

    public init(cardImageName: String, maskImageName: String) {
        self.cardImageName = cardImageName
        self.maskImageName = maskImageName
    }

    public var body: some View {
        HoloCardView(
            cardImageName: cardImageName,
            maskImageName: maskImageName,
            roll: motion.roll,
            pitch: motion.pitch
        )
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }
}

// MARK: - Preview Version (for SwiftUI Previews)
/// Preview version with simulated motion - use this in #Preview blocks
public struct HoloCardPreview: View {
    let cardImageName: String
    let maskImageName: String

    @StateObject private var simulatedMotion = SimulatedMotionManager()

    public init(cardImageName: String, maskImageName: String) {
        self.cardImageName = cardImageName
        self.maskImageName = maskImageName
    }

    public var body: some View {
        HoloCardView(
            cardImageName: cardImageName,
            maskImageName: maskImageName,
            roll: simulatedMotion.roll,
            pitch: simulatedMotion.pitch
        )
        .onAppear { simulatedMotion.start() }
        .onDisappear { simulatedMotion.stop() }
    }
}

// MARK: - Core View Implementation
private struct HoloCardView: View {
    let cardImageName: String
    let maskImageName: String
    let roll: Double
    let pitch: Double

    @State private var isPressed = false

    private let sheenTravel: CGFloat = 180

    var body: some View {
        ZStack {
            Image(cardImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay(sheenLayer)
                .mask(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            withAnimation { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation { isPressed = false }
            }
        }
    }

    private var sheenLayer: some View {
        Canvas { context, size in
            // Calculate gradient center position based on tilt
            let centerX = size.width / 2 + CGFloat(roll) * sheenTravel
            let centerY = size.height / 2 + CGFloat(pitch) * sheenTravel
            let gradientCenter = CGPoint(x: centerX, y: centerY)

            // Create radial gradient
            let gradient = Gradient(colors: [.white, .clear])
            let radius = size.width * 0.6

            // Draw the gradient
            context.fill(
                Path(ellipseIn: CGRect(
                    x: centerX - radius,
                    y: centerY - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .radialGradient(
                    gradient,
                    center: gradientCenter,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
        .mask(
            Image(maskImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        )
        .blendMode(.colorDodge)
        .allowsHitTesting(false)
    }
}

// MARK: - Motion Manager
@MainActor
private final class MotionManager: ObservableObject {
    private nonisolated(unsafe) let manager = CMMotionManager()
    private nonisolated(unsafe) let queue = OperationQueue()

    @Published var roll: Double = 0
    @Published var pitch: Double = 0

    private let smoothing: Double = 0.12
    private let maxTilt: Double = .pi / 7

    nonisolated func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let targetRoll = max(-self.maxTilt, min(self.maxTilt, motion.attitude.roll)) / self.maxTilt
            let targetPitch = max(-self.maxTilt, min(self.maxTilt, motion.attitude.pitch)) / self.maxTilt

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.roll += (targetRoll - self.roll) * self.smoothing
                self.pitch += (targetPitch - self.pitch) * self.smoothing
            }
        }
    }

    nonisolated func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

// MARK: - Simulated Motion Manager (for Previews)
@MainActor
private final class SimulatedMotionManager: ObservableObject {
    @Published var roll: Double = 0
    @Published var pitch: Double = 0

    private var animationTask: Task<Void, Never>?
    private let speed: Double = 0.3
    private let amplitude: Double = 0.8

    func start() {
        animationTask?.cancel()
        let startTime = CACurrentMediaTime()

        animationTask = Task {
            while !Task.isCancelled {
                let elapsed = CACurrentMediaTime() - startTime
                let angle = elapsed * speed

                roll = sin(angle) * amplitude
                pitch = cos(angle) * amplitude

                try? await Task.sleep(nanoseconds: 33_000_000)
            }
        }
    }

    func stop() {
        animationTask?.cancel()
        animationTask = nil
    }
}
