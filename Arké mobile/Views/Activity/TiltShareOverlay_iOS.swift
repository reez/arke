//
//  TiltShareOverlay_iOS.swift
//  Arké
//
//  Created by Christoph on 3/4/26.
//

import SwiftUI
import SwiftData
import QRCode
import ArkeUI

/// Playful overlay that slides in when device is tilted forward, showing payment QR code
struct TiltShareOverlay_iOS: View {
    let arkAddress: String
    let isVisible: Bool
    
    @Query private var profiles: [UserProfile]
    @State private var qrImage: UIImage?
    @State private var previousVisibility: Bool = false
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isVisible {
                    // Full-screen image background (upside down)
                    Image("tuscan-villa-portrait")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .rotationEffect(.degrees(180))
                        .clipped()
                        .ignoresSafeArea(.all)
                        .transition(.opacity)
                    
                    // QR code card
                    VStack(spacing: 25) {
                        // Header with optional profile photo and name
                        HStack(alignment: .center) {
                            if let name = userProfile?.name, !name.isEmpty {
                                Text(name)
                                    .font(.system(size: 36, weight: .semibold, design: .serif))
                                    .foregroundStyle(.white)
                            } else {
                                Text("Scan to pay")
                                    .font(.system(size: 36, weight: .semibold, design: .serif))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // QR Code - 80% of screen width
                        if let qrImage = qrImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: qrCodeSize(for: geometry.size.width),
                                       height: qrCodeSize(for: geometry.size.width))
                        } else {
                            ProgressView()
                                .scaleEffect(1.5)
                                .frame(width: qrCodeSize(for: geometry.size.width),
                                       height: qrCodeSize(for: geometry.size.width))
                        }
                        
                        /*
                        // Address label (truncated)
                        Text(truncatedAddress)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                         */
                    }
                    .padding(24)
                    .frame(width: cardWidth(for: geometry.size.width))
                    //.background(Color(uiColor: .systemBackground))
                    //.cornerRadius(25)
                    //.shadow(color: .black.opacity(0.3), radius: 30, y: 15)
                    .rotationEffect(.degrees(180))  // Flip upside down for person viewing
                    .scaleEffect(isVisible ? 1.0 : 0.95)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .offset(y: isVisible ? 0 : geometry.size.height)  // Slide from bottom
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea(.all)
            .animation(.smooth(duration: isVisible ? 0.4 : 0.3), value: isVisible)
        }
        .ignoresSafeArea(.all)
        .task {
            generateQRCode()
        }
        .onChange(of: arkAddress) { _, _ in
            generateQRCode()
        }
        .onChange(of: userProfile?.avatarData) { _, _ in
            generateQRCode()
        }
        .onChange(of: isVisible) { oldValue, newValue in
            // Trigger haptic feedback on state changes
            if oldValue != newValue {
                triggerHapticFeedback()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var truncatedAddress: String {
        guard arkAddress.count > 20 else { return arkAddress }
        let start = arkAddress.prefix(10)
        let end = arkAddress.suffix(10)
        return "\(start)...\(end)"
    }
    
    // Calculate QR code size as 80% of screen width (with max for larger devices)
    private func qrCodeSize(for screenWidth: CGFloat) -> CGFloat {
        let size = screenWidth * 0.8
        return min(size, 400)  // Cap at 400pt for larger screens
    }
    
    // Calculate card width to fit QR code + padding
    private func cardWidth(for screenWidth: CGFloat) -> CGFloat {
        return qrCodeSize(for: screenWidth) + 48  // QR size + 24pt padding on each side
    }
    
    // MARK: - QR Code Generation
    
    /// Rounds an avatar image into a perfect circle
    private func roundAvatarImage(_ image: UIImage) -> CGImage? {
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
    
    private func generateQRCode() {
        guard !arkAddress.isEmpty else { return }
        
        do {
            // Try to use user's avatar, fallback to app logo
            let logoImage: CGImage?
            let useAvatar: Bool
            if let avatarData = userProfile?.avatarData,
               let avatarUIImage = UIImage(data: avatarData) {
                // Round the avatar image first
                logoImage = roundAvatarImage(avatarUIImage)
                useAvatar = true
            } else if let appLogo = UIImage(named: "arke-icon-round")?.cgImage {
                logoImage = appLogo
                useAvatar = false
            } else {
                // No logo available, use simple QR
                generateSimpleQRCode()
                return
            }
            
            guard let finalLogo = logoImage else {
                generateSimpleQRCode()
                return
            }
            
            // Use no inset for avatar (full circle), 8pt inset for app logo
            let insetValue: Double = useAvatar ? 8 : 8
            
            let cgImage = try QRCode.build
                .text(arkAddress)
                .quietZonePixelCount(3)
                .background.cornerRadius(4)
                .errorCorrection(.high)  // High error correction needed for logo
                .onPixels.shape(QRCode.PixelShape.Squircle(insetFraction: 0.35))
                .eye.shape(QRCode.EyeShape.Squircle())
                .logo(finalLogo, position: .circleCenter(inset: insetValue))
                .generate.image(dimension: 600)
            
            qrImage = UIImage(cgImage: cgImage)
        } catch {
            print("❌ [TiltShareOverlay] Error generating QR code: \(error)")
            // Fallback to simple generation
            generateSimpleQRCode()
        }
    }
    
    private func generateSimpleQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = arkAddress.data(using: .utf8) else { return }
        
        filter.message = data
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            // Scale up the QR code for better quality
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                let image = UIImage(cgImage: cgImage)
                
                // Add white padding and corner radius
                let padding: CGFloat = 20
                let newSize = CGSize(width: image.size.width + padding * 2,
                                    height: image.size.height + padding * 2)
                
                let renderer = UIGraphicsImageRenderer(size: newSize)
                qrImage = renderer.image { rendererContext in
                    let rect = CGRect(origin: .zero, size: newSize)
                    
                    // Apply rounded corner clipping
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: 30)
                    path.addClip()
                    
                    // Fill with white background
                    UIColor.white.setFill()
                    rendererContext.fill(rect)
                    
                    // Draw the QR code with padding
                    let drawRect = CGRect(x: padding, y: padding,
                                        width: image.size.width,
                                        height: image.size.height)
                    image.draw(in: drawRect)
                }
            }
        }
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerHapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// MARK: - Preview

#Preview("Visible") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        TiltShareOverlay_iOS(
            arkAddress: "ark1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            isVisible: true
        )
    }
}

#Preview("Hidden") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        TiltShareOverlay_iOS(
            arkAddress: "ark1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            isVisible: false
        )
    }
}
