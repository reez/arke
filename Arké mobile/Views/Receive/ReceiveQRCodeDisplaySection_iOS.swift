//
//  ReceiveQRCodeDisplaySection_iOS.swift
//  Arké
//
//  Created by Christoph on 12/16/25.
//

import SwiftUI
import SwiftData
import QRCode

/// Displays a large QR code inline in the view
struct ReceiveQRCodeDisplaySection_iOS: View {
    let content: String
    let title: String
    
    @Query private var profiles: [UserProfile]
    @State private var qrImage: UIImage?
    @State private var qrImage2: UIImage?
    @State private var isShowingFullContent = false
    @State private var showingLogoVersion = true
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("receive_share_info")
                .font(.system(size: 24, design: .serif))
                .multilineTextAlignment(.center)
            
            /*
            Text(title)
                .font(.body)
                .multilineTextAlignment(.center)
            */
            
            Group {
                if showingLogoVersion {
                    if let qrImage2 = qrImage2 {
                        Image(uiImage: qrImage2)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 300, height: 300)
                    } else {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(width: 300, height: 300)
                    }
                } else {
                    if let qrImage = qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 300, height: 300)
                    } else {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(width: 300, height: 300)
                    }
                }
            }
            .transition(.scale.combined(with: .opacity))
            .onTapGesture {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.95)) {
                    showingLogoVersion.toggle()
                }
            }
            
            /*
            Button {
                isShowingFullContent = true
            } label: {
                Text("View Full Address")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderless)
            */
        }
        .padding(.horizontal, 20)
        //.padding(.vertical, 20)
        //.background(.ultraThinMaterial)
        //.cornerRadius(25)
        .task {
            generateQRCode()
            generateSecondQRCode()
        }
        .onChange(of: content) { _, _ in
            generateQRCode()
            generateSecondQRCode()
        }
        .sheet(isPresented: $isShowingFullContent) {
            NavigationStack {
                ScrollView {
                    Text(content)
                        .font(.title3)
                        .fontDesign(.monospaced)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .padding()
                }
                .navigationTitle("label_full_address")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("button_done") {
                            isShowingFullContent = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = content.data(using: .utf8) else { return }
        
        filter.message = data
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            // Scale up the QR code for better quality
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                let image = UIImage(cgImage: cgImage)
                
                // Add padding and apply corner radius
                let padding: CGFloat = 20 // 20 pixels at 10x scale = 2 points of padding
                let newSize = CGSize(width: image.size.width + padding * 2,
                                    height: image.size.height + padding * 2)
                
                let renderer = UIGraphicsImageRenderer(size: newSize)
                qrImage = renderer.image { rendererContext in
                    let rect = CGRect(origin: .zero, size: newSize)
                    
                    // Apply rounded corner clipping first
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: 30)
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
        }
    }
    
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
    
    private func generateSecondQRCode() {
        do {
            // Try to use user's avatar, fallback to app logo
            let logoImage: CGImage?
            if let avatarData = userProfile?.avatarData,
               let avatarUIImage = UIImage(data: avatarData) {
                // Round the avatar image first
                logoImage = roundAvatarImage(avatarUIImage)
            } else if let appLogo = UIImage(named: "arke-icon-round")?.cgImage {
                logoImage = appLogo
            } else {
                // No logo available, fallback to simple QR
                generateQRCode()
                return
            }
            
            guard let finalLogo = logoImage else {
                generateQRCode()
                return
            }
            
            // Use 8pt inset for both avatar and app logo
            let insetValue: Double = 8
            
            let cgImage = try QRCode.build
                .text(content)
                .quietZonePixelCount(3)
                .background.cornerRadius(4)
                .errorCorrection(.high)  // High error correction needed for logo
                .onPixels.shape(QRCode.PixelShape.Squircle(insetFraction: 0.35))
                .eye.shape(QRCode.EyeShape.Squircle())
                .logo(finalLogo, position: .circleCenter(inset: insetValue))
                .generate.image(dimension: 600)
            
            qrImage2 = UIImage(cgImage: cgImage)
        } catch {
            print("Error generating QR code: \(error)")
        }
    }
}
