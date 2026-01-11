//
//  ReceiveQRCodeDisplaySection_iOS.swift
//  Arké
//
//  Created by Christoph on 12/16/25.
//

import SwiftUI

/// Displays a large QR code inline in the view
struct ReceiveQRCodeDisplaySection_iOS: View {
    let content: String
    let title: String
    
    @State private var qrImage: UIImage?
    @State private var isShowingFullContent = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Share your payment info")
                .font(.system(size: 24, design: .serif))
                .multilineTextAlignment(.center)
            
            /*
            Text(title)
                .font(.body)
                .multilineTextAlignment(.center)
            */
            
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
        }
        .onChange(of: content) { _, _ in
            generateQRCode()
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
                .navigationTitle("Full Address")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
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
                qrImage = UIImage(cgImage: cgImage)
            }
        }
    }
}
