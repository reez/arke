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
    @Binding var isLocked: Bool
    let onNavigateToSend: (String) -> Void
    let onNavigateToContactEditor: (String, String) -> Void
    let onPaymentInfoReceived: (ReceivedPaymentInfo) -> Void
    
    @Environment(WalletManager.self) private var manager
    @Query private var profiles: [UserProfile]
    @State private var qrImage: UIImage?
    @State private var previousVisibility: Bool = false
    @State private var currentPage: Int = 0
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
                    
                    // Swipeable pages
                    TabView(selection: $currentPage) {
                        // Page 1: BIP-21 QR Code
                        bip21Page(geometry: geometry)
                            .tag(0)
                        
                        // Page 2: Lightning Invoice (only in primary mode - requires ASP connection)
                        if !manager.isReadOnlyMode {
                            LightningInvoicePage(
                                screenWidth: geometry.size.width,
                                walletManager: manager,
                                onClose: {
                                    // Unlock and reset to first page with animation
                                    withAnimation(.smooth(duration: 0.3)) {
                                        isLocked = false
                                        currentPage = 0
                                    }
                                }
                            )
                            .tag(1)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .indexViewStyle(.page(backgroundDisplayMode: .never))
                    .safeAreaPadding(.bottom, 60)  // Push page indicators above dynamic island
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
            
            // Reset to first page when overlay becomes visible
            if newValue {
                currentPage = 0
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
        .onChange(of: currentPage) { _, newValue in
            // Lock overlay when on lightning page (page 1) to prevent tilt dismissal
            // Only applies in primary mode where lightning page exists
            isLocked = (newValue == 1 && !manager.isReadOnlyMode)
            
            // Only run proximity exchange on BIP-21 page (page 0)
            if isVisible {
                if newValue == 0 {
                    handleVisibilityChange(true)
                } else {
                    proximityManager.stopExchange()
                }
            }
        }
    }
    
    // MARK: - BIP-21 Page
    
    @ViewBuilder
    private func bip21Page(geometry: GeometryProxy) -> some View {
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
                    .tint(.white)
                    .scaleEffect(1.5)
                    .frame(width: qrCodeSize(for: geometry.size.width),
                           height: qrCodeSize(for: geometry.size.width))
            }
            
            ProximityStatusIndicator(proximityManager: proximityManager)
            
            // Proximity exchange permission button or status
            proximityControlView
        }
        .padding(24)
        .frame(width: cardWidth(for: geometry.size.width))
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
    @Previewable @State var isLocked = false
    
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        TiltShareOverlay_iOS(
            arkAddress: "ark1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            onchainAddress: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
            isVisible: true,
            isLocked: $isLocked,
            onNavigateToSend: { _ in },
            onNavigateToContactEditor: { _, _ in },
            onPaymentInfoReceived: { _ in }
        )
    }
}

#Preview("Hidden") {
    @Previewable @State var isLocked = false
    
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        TiltShareOverlay_iOS(
            arkAddress: "ark1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            onchainAddress: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
            isVisible: false,
            isLocked: $isLocked,
            onNavigateToSend: { _ in },
            onNavigateToContactEditor: { _, _ in },
            onPaymentInfoReceived: { _ in }
        )
    }
}
