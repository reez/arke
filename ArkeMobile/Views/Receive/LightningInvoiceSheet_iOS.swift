//
//  LightningInvoiceSheet_iOS.swift
//  Arké
//
//  Created by Assistant on 5/27/26.
//

import SwiftUI
import SwiftData
import ArkeUI

/// Full-screen Lightning invoice QR sheet with tilt-based owner/recipient views
struct LightningInvoiceSheet_iOS: View {
    let invoice: String
    let amount: String
    let note: String?
    let arkAddress: String
    let onchainAddress: String
    let isDeviceUpsideDown: Bool
    let onClose: () -> Void
    
    @Query private var profiles: [UserProfile]
    @State private var qrImage: UIImage?
    @State private var showCopySuccess = false
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    private var formattedAmount: String {
        guard let sats = Int(amount) else { return amount }
        return BitcoinFormatter.shared.formatAmount(sats)
    }
    
    var body: some View {
        ZStack {
            // Background image
            Image("card-big")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Dark overlay (darker when upside down)
            Color.black.opacity(isDeviceUpsideDown ? 0.6 : 0.3)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: isDeviceUpsideDown)
            
            // Content
            ZStack {
                ownerView
                    .opacity(isDeviceUpsideDown ? 0 : 1)
                    .offset(y: isDeviceUpsideDown ? -50 : 0)
                
                recipientView
                    .rotationEffect(.degrees(180))
                    .opacity(isDeviceUpsideDown ? 1 : 0)
                    .offset(y: isDeviceUpsideDown ? 0 : 50)
            }
            .animation(.easeInOut(duration: 0.25), value: isDeviceUpsideDown)
        }
        .task {
            generateQRCode()
        }
    }
    
    // MARK: - Owner View (Normal Orientation)
    
    private var ownerView: some View {
        VStack(spacing: 20) {
            /*
            // Close button
            HStack {
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(.white)
                }
                .padding(4)
                .buttonStyle(.plain)
                .background(Color.black.opacity(0.15))
                .clipShape(Circle())
                .padding(.top, 50)
                .padding(.trailing, 30)
            }
            */
            
            Spacer()
            
            // QR Code
            VStack(spacing: 20) {
                Text("Share your Request")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                
                if let qrImage = qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 360, maxHeight: 360)
                        .background(.white)
                        .cornerRadius(20)
                        .shadow(radius: 10, x: 0, y: 5)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                        .frame(width: 320, height: 320)
                }
                
                VStack(spacing: 8) {
                    // Amount
                    Text(formattedAmount)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    // Note
                    if let note = note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 17))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Actions
            VStack(spacing: 16) {
                // Share button
                ShareLink(item: createBIP21URI()) {
                    Text("button_share")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.Arke.gold3)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.glassProminent)
                .tint(.Arke.gold)
                .controlSize(.large)
                .accessibilityLabel(String(localized: "accessibility_share_payment_request"))
                .accessibilityHint(String(localized: "accessibility_share_payment_hint"))
                
                Button {
                    onClose()
                } label: {
                    Text("Done")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .tint(Color.Arke.gold)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Recipient View (180° Rotated)
    
    private var recipientView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // QR Code (larger for scanning)
            VStack(spacing: 24) {
                // Scan to Pay message
                Text("Scan to Pay")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                
                if let qrImage = qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 360, maxHeight: 360)
                        .background(.white)
                        .cornerRadius(20)
                        .shadow(radius: 10, x: 0, y: 5)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                        .frame(width: 360, height: 360)
                }
                
                VStack(spacing: 8) {
                    // Amount
                    Text(formattedAmount)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    // Note
                    if let note = note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                
                if let name = userProfile?.name, !name.isEmpty {
                    HStack(spacing: 8) {
                        // Profile image if available
                        if let avatarData = userProfile?.avatarData,
                           let uiImage = UIImage(data: avatarData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                        }
                        
                        Text(name)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            
            Spacer()
        }
        .padding(24)
    }
    
    // MARK: - Helper Methods
    
    private func generateQRCode() {
        let bip21URI = createBIP21URI()
        do {
            qrImage = try QRCodeGenerator.shared.generateStyledQRCode(from: bip21URI)
        } catch {
            print("❌ [LightningInvoiceSheet] Failed to generate QR code: \(error)")
            // Fallback to simple QR generation if styled version fails
            qrImage = QRCodeGenerator.shared.generateSimpleQRCode(from: bip21URI)
        }
    }
    
    private func extractInvoiceString() -> String {
        // Parse JSON if needed (invoice might be wrapped in JSON)
        if let data = invoice.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let invoiceStr = json["invoice"] as? String {
            return invoiceStr
        }
        return invoice
    }
    
    private func createBIP21URI() -> String {
        let invoiceString = extractInvoiceString()
        let amountValue = amount.isEmpty ? nil : amount
        let noteValue = note?.isEmpty == false ? note : nil
        
        return BIP21URIHelper.createBIP21URI(
            arkAddress: arkAddress,
            onchainAddress: onchainAddress,
            lightningInvoice: invoiceString,
            amount: amountValue,
            message: noteValue
        )
    }
    
    private func copyInvoice() {
        let bip21URI = createBIP21URI()
        UIPasteboard.general.string = bip21URI
        
        // Show success feedback
        withAnimation {
            showCopySuccess = true
        }
        
        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopySuccess = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Owner View") {
    @Previewable @State var isUpsideDown = false
    
    LightningInvoiceSheet_iOS(
        invoice: "lnbc500000n1...",
        amount: "50000",
        note: "Coffee payment",
        arkAddress: "ark1testaddress123",
        onchainAddress: "tb1qtest123address",
        isDeviceUpsideDown: isUpsideDown,
        onClose: {}
    )
    .modelContainer(for: [UserProfile.self], inMemory: true)
}

#Preview("Recipient View") {
    @Previewable @State var isUpsideDown = true
    
    LightningInvoiceSheet_iOS(
        invoice: "lnbc500000n1...",
        amount: "50000",
        note: nil,
        arkAddress: "ark1testaddress123",
        onchainAddress: "tb1qtest123address",
        isDeviceUpsideDown: isUpsideDown,
        onClose: {}
    )
    .modelContainer(for: [UserProfile.self], inMemory: true)
}
