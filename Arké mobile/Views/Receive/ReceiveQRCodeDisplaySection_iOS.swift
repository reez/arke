//
//  ReceiveQRCodeDisplaySection_iOS.swift
//  Arké
//
//  Created by Christoph on 12/16/25.
//

import SwiftUI
import QRCode

/// Displays a large QR code inline in the view
struct ReceiveQRCodeDisplaySection_iOS: View {
    let content: String
    let title: String
    
    @State private var qrImage: UIImage?
    @State private var qrImage2: UIImage?
    @State private var isShowingFullContent = false
    @State private var showingLogoVersion = true
    
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
    
    private func generateSecondQRCode() {
        do {
            /*
            let red_color = CGColor(srgbRed: 0.41, green: 0.2, blue: 0, alpha: 1)
            let backgroundImage = UIImage(named: "arke-qr-background")?.cgImage

            var builder = try QRCode.build
                .text(content)
                .errorCorrection(.medium)
                .quietZonePixelCount(3)
                .background.cornerRadius(4)
                .eye.shape(QRCode.EyeShape.Squircle())
                .eye.backgroundColor(red_color)
                .onPixels.style(QRCode.FillStyle.Solid(1, 1, 1))
                .onPixels.shape(QRCode.PixelShape.Square(insetFraction: 0.5))
                .offPixels.style(QRCode.FillStyle.Solid(red_color))
                .offPixels.shape(QRCode.PixelShape.Square(insetFraction: 0.5))

            if let bgImage = backgroundImage {
                builder = builder.background.image(bgImage)
            }

            let qrCodeImage = try builder.generate.image(dimension: 600)
            qrImage2 = UIImage(cgImage: qrCodeImage)
            */
            
            guard let logoImage = UIImage(named: "arke-icon-round")?.cgImage else { return }
            let cgImage = try QRCode.build
                .text(content)
                .quietZonePixelCount(3)
                .background.cornerRadius(4)
                .errorCorrection(.high)  // Use high error correction when adding logos
                .onPixels.shape(QRCode.PixelShape.Squircle(insetFraction: 0.35))
                .eye.shape(QRCode.EyeShape.Squircle())
                .logo(logoImage, position: .circleCenter(inset: 8))
                .generate.image(dimension: 600)
            
            // Convert CGImage to UIImage
            qrImage2 = UIImage(cgImage: cgImage)
            
            /*
            let cgImage = try QRCode.build
                .text(content)
                .errorCorrection(.medium)
                .generate.image(dimension: 600)
            
            // Convert CGImage to UIImage
            qrImage2 = UIImage(cgImage: cgImage)
            */
        } catch {
            print("Error generating QR code: \(error)")
        }
    }
}
