//
//  AvatarPickerSheet.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/04/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AvatarPickerSheet: View {
    @Binding var selectedAvatarData: Data?
    @Environment(\.dismiss) private var dismiss
    
    @State private var isShowingFilePicker = false
    @State private var errorMessage: String?
    
    // Pre-defined avatar options
    private let systemAvatars = [
        "person.circle.fill",
        "person.2.circle.fill", 
        "person.3.circle.fill",
        "figure.wave.circle.fill",
        "figure.stand.circle.fill",
        "briefcase.circle.fill",
        "building.2.circle.fill",
        "star.circle.fill"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Avatar Preview
                    currentAvatarPreview
                    
                    // System Avatars
                    systemAvatarSection
                    
                    // Custom Avatar Options
                    customAvatarSection
                    
                    // Error Display
                    if let errorMessage = errorMessage {
                        errorSection(errorMessage)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Avatar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var currentAvatarPreview: some View {
        VStack(spacing: 12) {
            Text("Current Avatar")
                .font(.headline)
            
            Group {
                if let avatarData = selectedAvatarData,
                   let nsImage = NSImage(data: avatarData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            )
            
            if selectedAvatarData != nil {
                Button("Remove Avatar") {
                    selectedAvatarData = nil
                    errorMessage = nil
                }
                .foregroundColor(.red)
                .font(.caption)
            }
        }
    }
    
    @ViewBuilder
    private var systemAvatarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Avatars")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                ForEach(systemAvatars, id: \.self) { systemName in
                    Button {
                        createSystemAvatar(systemName: systemName)
                    } label: {
                        Image(systemName: systemName)
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                            .frame(width: 60, height: 60)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    @ViewBuilder
    private var customAvatarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Avatar")
                .font(.headline)
            
            Button {
                isShowingFilePicker = true
                errorMessage = nil
            } label: {
                HStack {
                    Image(systemName: "photo")
                        .font(.title2)
                    
                    Text("Choose from Photos...")
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func errorSection(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundColor(.red)
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Actions
    
    private func createSystemAvatar(systemName: String) {
        // Create an image from the system symbol and convert to Data
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 60, weight: .regular))
        
        if let image = image {
            // Create a bitmap representation
            let size = NSSize(width: 120, height: 120)
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                        pixelsWide: Int(size.width),
                                        pixelsHigh: Int(size.height),
                                        bitsPerSample: 8,
                                        samplesPerPixel: 4,
                                        hasAlpha: true,
                                        isPlanar: false,
                                        colorSpaceName: .calibratedRGB,
                                        bytesPerRow: 0,
                                        bitsPerPixel: 0)
            
            if let bitmap = bitmap {
                let context = NSGraphicsContext(bitmapImageRep: bitmap)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                
                // Draw the symbol with a blue color
                NSColor.systemBlue.setFill()
                let rect = NSRect(origin: .zero, size: size)
                rect.fill()
                
                // Draw the symbol
                image.draw(in: rect)
                
                NSGraphicsContext.restoreGraphicsState()
                
                selectedAvatarData = bitmap.representation(using: .png, properties: [:])
                errorMessage = nil
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                
                // Validate image size (limit to 2MB)
                if data.count > 2_000_000 {
                    errorMessage = "Image file is too large. Please choose an image under 2MB."
                    return
                }
                
                // Validate that it's actually an image
                guard let nsImage = NSImage(data: data) else {
                    errorMessage = "Selected file is not a valid image."
                    return
                }
                
                // Resize if needed (max 300x300)
                let resizedData = resizeImage(nsImage, maxSize: 300)
                selectedAvatarData = resizedData
                errorMessage = nil
                
            } catch {
                errorMessage = "Failed to load image: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            errorMessage = "Failed to select image: \(error.localizedDescription)"
        }
    }
    
    private func resizeImage(_ image: NSImage, maxSize: CGFloat) -> Data? {
        let originalSize = image.size
        let scale = min(maxSize / originalSize.width, maxSize / originalSize.height)
        
        // Don't upscale
        let scaleFactor = min(scale, 1.0)
        let newSize = NSSize(
            width: originalSize.width * scaleFactor,
            height: originalSize.height * scaleFactor
        )
        
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                    pixelsWide: Int(newSize.width),
                                    pixelsHigh: Int(newSize.height),
                                    bitsPerSample: 8,
                                    samplesPerPixel: 4,
                                    hasAlpha: true,
                                    isPlanar: false,
                                    colorSpaceName: .calibratedRGB,
                                    bytesPerRow: 0,
                                    bitsPerPixel: 0)
        
        guard let bitmap = bitmap else { return nil }
        
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        
        image.draw(in: NSRect(origin: .zero, size: newSize))
        
        NSGraphicsContext.restoreGraphicsState()
        
        return bitmap.representation(using: .png, properties: [:])
    }
}

#Preview {
    AvatarPickerSheet(selectedAvatarData: .constant(nil))
}