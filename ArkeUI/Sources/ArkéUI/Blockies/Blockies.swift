//
//  Blockies.swift
//  ArkeUI
//
//  Created by Christoph on 4/28/26.
//  Based on BlockiesSwift by Koray Koska (https://github.com/Boilertalk/BlockiesSwift).
//  Optimized and modernized for Swift 6.
//

#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

import SwiftUI

public final class Blockies: @unchecked Sendable {

    // MARK: - Types

    public enum RenderStyle {
        case classic
        case rounded(spacing: CGFloat, cornerRadius: CGFloat)
    }

    // MARK: - Properties

    private var randSeed: [UInt32]

    public let seed: String
    public let size: Int
    public let scale: Int

    #if os(iOS) || os(tvOS) || os(watchOS)
    public typealias Color = UIColor
    public typealias Image = UIImage
    #elseif os(macOS)
    public typealias Color = NSColor
    public typealias Image = NSImage
    #endif

    public let color: Color
    public let bgColor: Color
    public let spotColor: Color

    // MARK: - Initialization

    /**
     * Initializes this instance of `Blockies` with the given values or default values.
     *
     * - parameter seed: The seed to be used for this Blockies. Defaults to random.
     * - parameter size: The number of blocks per side for this image. Defaults to 8.
     * - parameter scale: The number of pixels per block. Defaults to 4.
     * - parameter color: The foreground color. Defaults to random.
     * - parameter bgColor: The background color. Defaults to random.
     * - parameter spotColor: A color which forms mouths and eyes. Defaults to random.
     */
    public init(
        seed: String? = nil,
        size: Int = 8,
        scale: Int = 4,
        color: Color? = nil,
        bgColor: Color? = nil,
        spotColor: Color? = nil
    ) {
        let seed = seed ?? String(Int64.random(in: 0..<10_000_000_000_000_000))
        self.seed = seed
        self.randSeed = BlockiesHelper.createRandSeed(seed: seed)
        self.size = size
        self.scale = scale

        // Generate colors efficiently with nil-coalescing
        var tempRandSeed = self.randSeed
        self.color = color ?? Self.createColor(randSeed: &tempRandSeed)
        self.bgColor = bgColor ?? Self.createColor(randSeed: &tempRandSeed)
        self.spotColor = spotColor ?? Self.createColor(randSeed: &tempRandSeed)
    }

    /**
     * Creates the Blockies Image with currently set values.
     *
     * You can change the absolute size in pixels of the resulting image
     * by passing a `customScale` value which will result in the total pixel size
     * calculated as follows:
     *
     * `size * scale * customScale`
     *
     * For example: Default values `size = 8` and `scale = 4` result in an image
     * with 32x32px size. If you provide a `customScale` of `10`, you will get
     * an image with 320x320px in size.
     *
     * - parameter customScale: A scale factor which will be used to calculate the total image size.
     * - parameter style: The rendering style to use. Defaults to `.classic`.
     *
     * - returns: The generated image or `nil` if something went wrong.
     */
    public func createImage(customScale: Int = 1, style: RenderStyle = .classic) -> Image? {
        var mutableRandSeed = randSeed
        let imageData = Self.createImageData(size: size, randSeed: &mutableRandSeed)
        return image(data: imageData, customScale: customScale, style: style)
    }

    @inline(__always)
    private static func rand(randSeed: inout [UInt32]) -> Double {
        let t = randSeed[0] ^ (randSeed[0] << 11)

        randSeed[0] = randSeed[1]
        randSeed[1] = randSeed[2]
        randSeed[2] = randSeed[3]
        let tmp = Int32(bitPattern: randSeed[3])
        let tmpT = Int32(bitPattern: t)
        randSeed[3] = UInt32(bitPattern: (tmp ^ (tmp >> 19) ^ tmpT ^ (tmpT >> 8)))

        let divisor = Int32.max

        return Double((UInt32(randSeed[3]) >> UInt32(0))) / Double(divisor)
    }

    private static func createColor(randSeed: inout [UInt32]) -> Color {
        let h = rand(randSeed: &randSeed) * 360
        let s = (rand(randSeed: &randSeed) * 60 + 40) / 100
        let l = (rand(randSeed: &randSeed) + rand(randSeed: &randSeed) + rand(randSeed: &randSeed) + rand(randSeed: &randSeed)) * 25 / 100

        return Color(h: h, s: s, l: l) ?? .black
    }

    private static func createImageData(size: Int, randSeed: inout [UInt32]) -> [Double] {
        let dataWidth = (size + 1) / 2  // Equivalent to ceil(size / 2)
        let mirrorWidth = size - dataWidth

        var data: [Double] = []
        data.reserveCapacity(size * size)

        for _ in 0..<size {
            var row: [Double] = []
            row.reserveCapacity(size)

            // Generate left half
            for _ in 0..<dataWidth {
                // 43% foreground, 43% background, 13% spot color
                row.append(floor(rand(randSeed: &randSeed) * 2.3))
            }

            // Mirror to create symmetry
            for i in stride(from: mirrorWidth - 1, through: 0, by: -1) {
                row.append(row[i])
            }

            data.append(contentsOf: row)
        }

        return data
    }

    private func image(data: [Double], customScale: Int, style: RenderStyle) -> Image? {
        let finalSize = size * scale * customScale
        let finalSizeCG = CGFloat(finalSize)
        let scaledBlockSize = CGFloat(scale * customScale)

        #if os(iOS) || os(tvOS) || os(watchOS)
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: finalSize, height: finalSize))
            return renderer.image { context in
                let ctx = context.cgContext

                // Fill background (only for classic style)
                switch style {
                case .classic:
                    ctx.setFillColor(bgColor.cgColor)
                    ctx.fill(CGRect(x: 0, y: 0, width: finalSizeCG, height: finalSizeCG))
                case .rounded:
                    break // Leave background transparent for rounded style
                }

                // Draw blocks
                var y: CGFloat = 0
                var x: CGFloat = 0

                for value in data {
                    let fillColor: Color
                    switch value {
                    case 0:
                        fillColor = bgColor
                    case 1:
                        fillColor = color
                    case 2:
                        fillColor = spotColor
                    default:
                        fillColor = .black
                    }

                    switch style {
                    case .classic:
                        ctx.setFillColor(fillColor.cgColor)
                        ctx.fill(CGRect(x: x, y: y, width: scaledBlockSize, height: scaledBlockSize))
                    case .rounded(let spacing, let cornerRadius):
                        // Skip drawing background blocks to let canvas background show through
                        ctx.setFillColor(fillColor.cgColor)
                        let insetRect = CGRect(
                            x: x + spacing / 2,
                            y: y + spacing / 2,
                            width: scaledBlockSize - spacing,
                            height: scaledBlockSize - spacing
                        )
                        let path = UIBezierPath(roundedRect: insetRect, cornerRadius: cornerRadius)
                        ctx.addPath(path.cgPath)
                        ctx.fillPath()
                    }

                    x += scaledBlockSize
                    if x >= finalSizeCG {
                        x = 0
                        y += scaledBlockSize
                    }
                }
            }
        #elseif os(macOS)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            guard let context = CGContext(
                data: nil,
                width: finalSize,
                height: finalSize,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                return nil
            }

            // Fill background (only for classic style)
            switch style {
            case .classic:
                context.setFillColor(bgColor.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: finalSizeCG, height: finalSizeCG))
            case .rounded:
                break // Leave background transparent for rounded style
            }

            // Draw blocks
            var y: CGFloat = 0
            var x: CGFloat = 0

            for value in data {
                let fillColor: Color
                switch value {
                case 0:
                    fillColor = bgColor
                case 1:
                    fillColor = color
                case 2:
                    fillColor = spotColor
                default:
                    fillColor = .black
                }

                switch style {
                case .classic:
                    context.setFillColor(fillColor.cgColor)
                    context.fill(CGRect(x: x, y: y, width: scaledBlockSize, height: scaledBlockSize))
                case .rounded(let spacing, let cornerRadius):
                    // Skip drawing background blocks to let canvas background show through
                    if value != 0 {
                        context.setFillColor(fillColor.cgColor)
                        let insetRect = CGRect(
                            x: x + spacing / 2,
                            y: y + spacing / 2,
                            width: scaledBlockSize - spacing,
                            height: scaledBlockSize - spacing
                        )
                        let path = NSBezierPath(roundedRect: insetRect, xRadius: cornerRadius, yRadius: cornerRadius)
                        context.addPath(path.cgPath)
                        context.fillPath()
                    }
                }

                x += scaledBlockSize
                if x >= finalSizeCG {
                    x = 0
                    y += scaledBlockSize
                }
            }

            guard let cgImage = context.makeImage() else {
                return nil
            }

            return NSImage(cgImage: cgImage, size: CGSize(width: finalSize, height: finalSize))
        #endif
    }
}

final class BlockiesHelper {

    /**
     * Creates the initial version of the 4 UInt32 array for the given seed.
     * The result is equal for equal seeds.
     *
     * - parameter seed: The seed.
     *
     * - returns: The UInt32 array with exactly 4 values stored in it.
     */
    static func createRandSeed(seed: String) -> [UInt32] {
        var randSeed = [UInt32](repeating: 0, count: 4)

        // Optimized string iteration - O(n) instead of O(n²)
        var index = 0
        for char in seed {
            let seedIndex = index % 4
            // Use proper left shift: 1 << 5 instead of 2 << 4
            randSeed[seedIndex] = ((randSeed[seedIndex] &* (1 << 5)) &- randSeed[seedIndex])
            // Use built-in asciiValue (Swift 5+)
            if let asciiValue = char.asciiValue {
                randSeed[seedIndex] = randSeed[seedIndex] &+ UInt32(asciiValue)
            }
            index += 1
        }

        return randSeed
    }
}

// MARK: - Previews

#Preview("Default Blockies") {
    VStack(spacing: 20) {
        if let image = Blockies().createImage(customScale: 4) {
            #if os(iOS) || os(tvOS) || os(watchOS)
            Image(uiImage: image)
                .resizable()
                .frame(width: 128, height: 128)
            #elseif os(macOS)
            Image(nsImage: image)
                .resizable()
                .frame(width: 128, height: 128)
            #endif
        }
    }
    .padding()
}

#Preview("Seeded Blockies") {
    VStack(spacing: 20) {
        ForEach(["0x1234567890abcdef", "alice@example.com", "bob@example.com", "test123"], id: \.self) { seed in
            HStack {
                if let image = Blockies(seed: seed).createImage(customScale: 4) {
                    #if os(iOS) || os(tvOS) || os(watchOS)
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 80, height: 80)
                    #elseif os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: 80, height: 80)
                    #endif
                }
                Text(seed)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
    }
    .padding()
}

#Preview("Custom Sizes") {
    HStack(spacing: 20) {
        ForEach([4, 8, 12], id: \.self) { size in
            VStack {
                if let image = Blockies(seed: "0xSampleAddress", size: size).createImage(customScale: 4) {
                    #if os(iOS) || os(tvOS) || os(watchOS)
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 100, height: 100)
                    #elseif os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: 100, height: 100)
                    #endif
                }
                Text("Size: \(size)")
                    .font(.caption2)
            }
        }
    }
    .padding()
}

#Preview("Rounded Style") {
    HStack(spacing: 30) {
        VStack(spacing: 10) {
            if let image = Blockies(seed: "0x1234567890abcdef").createImage(customScale: 4, style: .classic) {
                #if os(iOS) || os(tvOS) || os(watchOS)
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 64, height: 64)
                #elseif os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 64, height: 64)
                #endif
            }
            Text("Classic")
                .font(.caption)
        }

        VStack(spacing: 10) {
            if let image = Blockies(seed: "0x1234567890abcdef").createImage(customScale: 4, style: .rounded(spacing: 5, cornerRadius: 3)) {
                #if os(iOS) || os(tvOS) || os(watchOS)
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 64, height: 64)
                #elseif os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 64, height: 64)
                #endif
            }
            Text("Rounded")
                .font(.caption)
        }
    }
    .padding()
}
