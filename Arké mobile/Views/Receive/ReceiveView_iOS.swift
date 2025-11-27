//
//  ReceiveView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiveView_iOS: View {
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("Receive")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Ark Address Section
                AddressSection(
                    title: "Ark Address",
                    subtitle: "For off-chain Ark payments",
                    address: manager.arkAddress
                )
                
                Divider()
                
                // Onchain Address Section
                AddressSection(
                    title: "Onchain Address",
                    subtitle: "For on-chain Bitcoin payments",
                    address: manager.onchainAddress
                )
            }
            .padding()
        }
    }
}

private struct AddressSection: View {
    let title: String
    let subtitle: String
    let address: String
    
    @State private var showCopiedConfirmation = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if !address.isEmpty {
                // QR Code
                Image(uiImage: generateQRCode(from: address))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 2)
                
                // Address Text
                Text(address)
                    .font(.system(.caption, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal)
                
                // Copy Button
                Button {
                    UIPasteboard.general.string = address
                    showCopiedConfirmation = true
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Hide confirmation after delay
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        showCopiedConfirmation = false
                    }
                } label: {
                    HStack {
                        Image(systemName: showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                        Text(showCopiedConfirmation ? "Copied!" : "Copy Address")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .animation(.easeInOut(duration: 0.2), value: showCopiedConfirmation)
            } else {
                Text("Address not available")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            // Scale up the QR code for better quality
            let scaleX = 200 / outputImage.extent.size.width
            let scaleY = 200 / outputImage.extent.size.height
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        // Fallback to a placeholder image
        return UIImage(systemName: "qrcode") ?? UIImage()
    }
}
