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
    let onchainAddress: String
    let isVisible: Bool
    let onNavigateToSend: (String) -> Void
    let onNavigateToContactEditor: (String, String) -> Void
    let onPaymentInfoReceived: (ReceivedPaymentInfo) -> Void
    
    @Query private var profiles: [UserProfile]
    @State private var qrImage: UIImage?
    @State private var previousVisibility: Bool = false
    @StateObject private var proximityManager = ProximityExchangeManager()
    
    @AppStorage(UserDefaults.proximityPermissionKey) private var hasGrantedProximityPermission: Bool = false
    
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
                        
                        // Proximity exchange permission button or status
                        proximityControlView
                        
                        // Test button for simulating received payment info
                        #if DEBUG
                        //testButton
                        #endif
                        
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
        .onChange(of: onchainAddress) { _, _ in
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
            
            // Start/stop proximity exchange based on visibility
            handleVisibilityChange(newValue)
        }
        .onChange(of: proximityManager.receivedPaymentInfo) { _, newValue in
            // Notify parent when payment info is received
            if let paymentInfo = newValue {
                onPaymentInfoReceived(paymentInfo)
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
    
    /// Gets the user's profile name for use in BIP21 URI labels
    private var userProfileName: String? {
        guard let name = userProfile?.name else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        return trimmedName.isEmpty ? nil : trimmedName
    }
    
    private func generateQRCode() {
        guard !arkAddress.isEmpty else { return }
        
        // Create BIP-21 URI with both ark and onchain addresses
        let bip21URI = BIP21URIHelper.createBIP21URI(
            arkAddress: arkAddress,
            onchainAddress: onchainAddress.isEmpty ? nil : onchainAddress,
            label: userProfileName
        )
        
        print("[TiltShareOverlay] Generated BIP21 URI for QR code: \(bip21URI)")
        
        // Generate personalized QR code with user avatar or app logo
        qrImage = QRCodeGenerator.shared.generatePersonalizedQRCode(
            from: bip21URI,
            avatarData: userProfile?.avatarData
        )
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerHapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    // MARK: - Proximity Exchange
    
    private func handleVisibilityChange(_ visible: Bool) {
        if visible {
            guard !arkAddress.isEmpty else { return }
            
            let bip21URI = BIP21URIHelper.createBIP21URI(
                arkAddress: arkAddress,
                onchainAddress: onchainAddress.isEmpty ? nil : onchainAddress,
                label: userProfileName
            )
            
            print("[TiltShareOverlay] Generated BIP21 URI for proximity exchange: \(bip21URI)")
            
            if hasGrantedProximityPermission {
                // User has previously granted permission, start immediately
                proximityManager.startExchange(bip21URI: bip21URI, avatarData: userProfile?.avatarData)
            } else {
                // First time, show permission button
                proximityManager.showPermissionPrompt(bip21URI: bip21URI, avatarData: userProfile?.avatarData)
            }
        } else {
            // Stop proximity exchange when overlay is hidden
            proximityManager.stopExchange()
        }
    }
    
    private func enableProximitySharing() {
        guard !arkAddress.isEmpty else { return }
        
        let bip21URI = BIP21URIHelper.createBIP21URI(
            arkAddress: arkAddress,
            onchainAddress: onchainAddress.isEmpty ? nil : onchainAddress,
            label: userProfileName
        )
        
        print("[TiltShareOverlay] Enabling proximity sharing with BIP21 URI: \(bip21URI)")
        
        // Mark permission as granted (assuming user will grant it when dialog appears)
        hasGrantedProximityPermission = true
        
        proximityManager.startExchange(bip21URI: bip21URI, avatarData: userProfile?.avatarData)
    }
    
    // MARK: - Test Button
    
    #if DEBUG
    @ViewBuilder
    private var testButton: some View {
        Button {
            // Simulate receiving payment info using actual view data
            let testBIP21URI = BIP21URIHelper.createBIP21URI(
                arkAddress: arkAddress,
                onchainAddress: onchainAddress.isEmpty ? nil : onchainAddress,
                label: userProfileName
            )
            
            print("[TiltShareOverlay] Test button uses BIP21 URI: \(testBIP21URI)")
            
            proximityManager.receivedPaymentInfo = ReceivedPaymentInfo(
                bip21URI: testBIP21URI,
                avatarData: userProfile?.avatarData
            )
            
            // Trigger haptic feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "testtube.2")
                    .font(.caption2)
                Text("Test Receive")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.7))
            .cornerRadius(15)
        }
    }
    #endif
    
    @ViewBuilder
    private var proximityControlView: some View {
        if case .awaitingPermission = proximityManager.state {
            Button {
                enableProximitySharing()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wave.3.right")
                    Text("button_enable_proximity_sharing", bundle: .main)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.Arke.blue.opacity(0.8))
                .cornerRadius(25)
            }
        }
    }
}

// MARK: - Preview

#Preview("Visible") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        TiltShareOverlay_iOS(
            arkAddress: "ark1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            onchainAddress: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
            isVisible: true,
            onNavigateToSend: { _ in },
            onNavigateToContactEditor: { _, _ in },
            onPaymentInfoReceived: { _ in }
        )
    }
}

#Preview("Hidden") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        TiltShareOverlay_iOS(
            arkAddress: "ark1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            onchainAddress: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
            isVisible: false,
            onNavigateToSend: { _ in },
            onNavigateToContactEditor: { _, _ in },
            onPaymentInfoReceived: { _ in }
        )
    }
}
