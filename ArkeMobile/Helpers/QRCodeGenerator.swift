//
//  QRCodeGenerator.swift
//  Arké
//
//  Created by Claude on 4/22/26.
//

import UIKit
import CoreImage
import QRCode

/// Shared utility for generating QR codes with optimized memory management
final class QRCodeGenerator {
    static let shared = QRCodeGenerator()
    
    // Reusable CIContext - expensive to create, so we share one instance
    private let ciContext = CIContext()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Generate a simple QR code with white padding and rounded corners
    func generateSimpleQRCode(from content: String, padding: CGFloat = 20, cornerRadius: CGFloat = 30) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = content.data(using: .utf8) else { return nil }
        
        filter.message = data
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale up the QR code for better quality
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        let image = UIImage(cgImage: cgImage)
        
        // Add padding and apply corner radius
        let newSize = CGSize(width: image.size.width + padding * 2,
                            height: image.size.height + padding * 2)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { rendererContext in
            let rect = CGRect(origin: .zero, size: newSize)
            
            // Apply rounded corner clipping first
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            path.addClip()
            
            // Fill with white background (within the clipped area)
            UIColor.white.setFill()
            rendererContext.fill(rect)
            
            // Draw the QR code with padding
            let drawRect = CGRect(x: padding, y: padding,
                                width: image.size.width,
                                height: image.size.height)
            image.draw(in: drawRect)
        }
    }
    
    /// Generate a QR code with a logo in the center using the QRCode library
    func generateQRCodeWithLogo(
        from content: String,
        logo: CGImage,
        logoInset: Double = 8,
        dimension: Int = 600
    ) throws -> UIImage {
        let cgImage = try QRCode.build
            .text(content)
            .quietZonePixelCount(3)
            .background.cornerRadius(4)
            .errorCorrection(.high)  // High error correction needed for logo
            .onPixels.shape(QRCode.PixelShape.Squircle(insetFraction: 0.35))
            .eye.shape(QRCode.EyeShape.Squircle())
            .logo(logo, position: .circleCenter(inset: logoInset))
            .generate.image(dimension: dimension)
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Rounds an avatar image into a perfect circle
    func roundAvatarImage(_ image: UIImage) -> CGImage? {
        let size = min(image.size.width, image.size.height)
        let imageSize = CGSize(width: size, height: size)
        
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let roundedImage = renderer.image { context in
            // Create circular clipping path
            let rect = CGRect(origin: .zero, size: imageSize)
            UIBezierPath(ovalIn: rect).addClip()
            
            // Calculate draw rect to center the image
            let drawRect: CGRect
            if image.size.width > image.size.height {
                let offset = (image.size.width - image.size.height) / 2
                drawRect = CGRect(x: -offset, y: 0, width: image.size.width, height: image.size.height)
            } else {
                let offset = (image.size.height - image.size.width) / 2
                drawRect = CGRect(x: 0, y: -offset, width: image.size.width, height: image.size.height)
            }
            
            // Draw the image centered and clipped to circle
            image.draw(in: drawRect)
        }
        
        return roundedImage.cgImage
    }
}
