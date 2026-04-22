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
    

    
    private func generateQRCode() {
        guard !arkAddress.isEmpty else { return }
        
        do {
            // Try to use user's avatar, fallback to app logo
            let logoImage: CGImage?
            if let avatarData = userProfile?.avatarData,
               let avatarUIImage = UIImage(data: avatarData) {
                // Round the avatar image first
                logoImage = QRCodeGenerator.shared.roundAvatarImage(avatarUIImage)
            } else if let appLogo = UIImage(named: "arke-icon-round")?.cgImage {
                logoImage = appLogo
            } else {
                // No logo available, use simple QR
                generateSimpleQRCode()
                return
            }
            
            guard let finalLogo = logoImage else {
                generateSimpleQRCode()
                return
            }
            
            // Use 8pt inset for both avatar and app logo
            let insetValue: Double = 8
            
            qrImage = try QRCodeGenerator.shared.generateQRCodeWithLogo(
                from: arkAddress,
                logo: finalLogo,
                logoInset: insetValue,
                dimension: 600
            )
        } catch {
            print("❌ [TiltShareOverlay] Error generating QR code: \(error)")
            // Fallback to simple generation
            generateSimpleQRCode()
        }
    }
    
    private func generateSimpleQRCode() {
        qrImage = QRCodeGenerator.shared.generateSimpleQRCode(from: arkAddress)
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
