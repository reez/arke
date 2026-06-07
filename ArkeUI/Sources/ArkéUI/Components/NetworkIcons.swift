//
//  NetworkIcons.swift
//  ArkéUI
//
//  Created by Assistant on 6/7/26.
//

import SwiftUI

// MARK: - Network Type

public enum NetworkType {
    case bitcoin
    case ark
    case lightning
}

// MARK: - Network Icons Component

public struct NetworkIcons: View {
    let showBitcoin: Bool
    let showArk: Bool
    let showLightning: Bool
    let color: Color
    let spacing: CGFloat

    public init(
        showBitcoin: Bool = true,
        showArk: Bool = true,
        showLightning: Bool = true,
        color: Color = .primary,
        spacing: CGFloat = 4
    ) {
        self.showBitcoin = showBitcoin
        self.showArk = showArk
        self.showLightning = showLightning
        self.color = color
        self.spacing = spacing
    }

    public var body: some View {
        HStack(spacing: spacing) {
            if showBitcoin {
                BitcoinIcon(color: color)
            }
            
            if showArk {
                ArkIcon(color: color)
            }
            
            if showLightning {
                LightningIcon(color: color)
            }
        }
    }
}

// MARK: - Individual Network Icons

public struct BitcoinIcon: View {
    let color: Color

    public init(color: Color = .primary) {
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let rect = Path { path in
                // Rounded rectangle centered in 8x8 frame with 2px inset for stroke
                path.addRoundedRect(in: CGRect(x: 1, y: 1, width: 8, height: 8), cornerSize: CGSize(width: 1, height: 1))
            }

            context.stroke(
                rect,
                with: .color(color),
                lineWidth: 2
            )
        }
        .frame(width: 10, height: 10)
    }
}

public struct ArkIcon: View {
    let color: Color

    public init(color: Color = .primary) {
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let arch = Path { path in
                // Arch shape - semicircle arc at top of 8x8 frame
                // Start from bottom left, go up, arc over, come down
                path.move(to: CGPoint(x: 1, y: 9))
                path.addLine(to: CGPoint(x: 1, y: 5))
                path.addArc(
                    center: CGPoint(x: 5, y: 5),
                    radius: 4,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                path.addLine(to: CGPoint(x: 9, y: 9))
            }

            context.stroke(
                arch,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        }
        .frame(width: 10, height: 10)
    }
}

public struct LightningIcon: View {
    let color: Color

    public init(color: Color = .primary) {
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let zigzag = Path { path in
                // Zig-zag lightning bolt shape
                path.move(to: CGPoint(x: 5, y: 1))
                path.addLine(to: CGPoint(x: 1, y: 5))
                path.addLine(to: CGPoint(x: 9, y: 5))
                path.addLine(to: CGPoint(x: 5, y: 9))
            }

            context.stroke(
                zigzag,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: 10, height: 10)
    }
}

// MARK: - Preview

#Preview("Network Icons") {
    VStack(spacing: 32) {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Networks")
                .font(.headline)

            NetworkIcons()

            NetworkIcons(color: .blue)

            NetworkIcons(color: Color.Arke.gold, spacing: 8)
        }

        Divider()

        VStack(alignment: .leading, spacing: 16) {
            Text("Individual Networks")
                .font(.headline)

            HStack(spacing: 16) {
                VStack {
                    NetworkIcons(showBitcoin: true, showArk: false, showLightning: false)
                    Text("Bitcoin")
                        .font(.caption2)
                }

                VStack {
                    NetworkIcons(showBitcoin: false, showArk: true, showLightning: false)
                    Text("Ark")
                        .font(.caption2)
                }

                VStack {
                    NetworkIcons(showBitcoin: false, showArk: false, showLightning: true)
                    Text("Lightning")
                        .font(.caption2)
                }
            }
        }

        Divider()

        VStack(alignment: .leading, spacing: 16) {
            Text("Combinations")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    NetworkIcons(showBitcoin: true, showArk: true, showLightning: false)
                    Text("Bitcoin + Ark")
                        .font(.caption)
                }

                HStack {
                    NetworkIcons(showBitcoin: false, showArk: true, showLightning: true)
                    Text("Ark + Lightning")
                        .font(.caption)
                }

                HStack {
                    NetworkIcons(showBitcoin: true, showArk: false, showLightning: true, color: Color.Arke.orange)
                    Text("Bitcoin + Lightning")
                        .font(.caption)
                }
            }
        }

        Divider()

        VStack(alignment: .leading, spacing: 16) {
            Text("Individual Icon Components")
                .font(.headline)

            HStack(spacing: 16) {
                VStack {
                    BitcoinIcon()
                    Text("BitcoinIcon")
                        .font(.caption2)
                }

                VStack {
                    ArkIcon(color: Color.Arke.gold)
                    Text("ArkIcon")
                        .font(.caption2)
                }

                VStack {
                    LightningIcon(color: Color.Arke.blue)
                    Text("LightningIcon")
                        .font(.caption2)
                }
            }
        }

        Divider()

        VStack(alignment: .leading, spacing: 16) {
            Text("Scaled Up (3x) for Visibility")
                .font(.headline)

            HStack(spacing: 24) {
                BitcoinIcon()
                    .scaleEffect(3)
                    .frame(width: 24, height: 24)

                ArkIcon()
                    .scaleEffect(3)
                    .frame(width: 24, height: 24)

                LightningIcon()
                    .scaleEffect(3)
                    .frame(width: 24, height: 24)
            }
        }
    }
    .padding()
}
