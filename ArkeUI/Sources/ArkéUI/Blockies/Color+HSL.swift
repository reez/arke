//
//  Color+HSL.swift
//  ArkeUI
//
//  Created by Christoph on 4/28/26.
//  Based on BlockiesSwift by Koray Koska (https://github.com/Boilertalk/BlockiesSwift).
//  Optimized and modernized for Swift 6.
//

#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit

    extension UIColor {
        /**
         * Initializes UIColor with the given HSL color values.
         *
         * H must be between 0 and 360.
         * S must be between 0 and 1.
         * L must be between 0 and 1.
         *
         * - parameter h: The hue value (0-360).
         * - parameter s: The saturation value (0-1).
         * - parameter l: The lightness value (0-1).
         */
        convenience init?(h: Double, s: Double, l: Double) {
            // Validate input ranges
            guard (0...360).contains(h),
                  (0...1).contains(s),
                  (0...1).contains(l) else {
                return nil
            }

            let c = (1 - abs(2 * l - 1)) * s
            let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
            let m = l - (c / 2)

            let (r, g, b): (Double, Double, Double)

            switch h {
            case 0..<60:
                (r, g, b) = (c, x, 0)
            case 60..<120:
                (r, g, b) = (x, c, 0)
            case 120..<180:
                (r, g, b) = (0, c, x)
            case 180..<240:
                (r, g, b) = (0, x, c)
            case 240..<300:
                (r, g, b) = (x, 0, c)
            case 300..<360:
                (r, g, b) = (c, 0, x)
            case 360:
                // Handle exactly 360 as red (same as 0)
                (r, g, b) = (c, x, 0)
            default:
                return nil
            }

            self.init(
                red: CGFloat(r + m),
                green: CGFloat(g + m),
                blue: CGFloat(b + m),
                alpha: 1
            )
        }

        static func fromHSL(h: Double, s: Double, l: Double) -> UIColor? {
            return UIColor(h: h, s: s, l: l)
        }
    }

#elseif os(macOS)
    import AppKit

    extension NSColor {
        /**
         * Initializes NSColor with the given HSL color values.
         *
         * H must be between 0 and 360.
         * S must be between 0 and 1.
         * L must be between 0 and 1.
         *
         * - parameter h: The hue value (0-360).
         * - parameter s: The saturation value (0-1).
         * - parameter l: The lightness value (0-1).
         */
        convenience init?(h: Double, s: Double, l: Double) {
            // Validate input ranges
            guard (0...360).contains(h),
                  (0...1).contains(s),
                  (0...1).contains(l) else {
                return nil
            }

            let c = (1 - abs(2 * l - 1)) * s
            let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
            let m = l - (c / 2)

            let (r, g, b): (Double, Double, Double)

            switch h {
            case 0..<60:
                (r, g, b) = (c, x, 0)
            case 60..<120:
                (r, g, b) = (x, c, 0)
            case 120..<180:
                (r, g, b) = (0, c, x)
            case 180..<240:
                (r, g, b) = (0, x, c)
            case 240..<300:
                (r, g, b) = (x, 0, c)
            case 300..<360:
                (r, g, b) = (c, 0, x)
            case 360:
                // Handle exactly 360 as red (same as 0)
                (r, g, b) = (c, x, 0)
            default:
                return nil
            }

            self.init(
                red: CGFloat(r + m),
                green: CGFloat(g + m),
                blue: CGFloat(b + m),
                alpha: 1
            )
        }

        static func fromHSL(h: Double, s: Double, l: Double) -> NSColor? {
            return NSColor(h: h, s: s, l: l)
        }
    }
#endif
