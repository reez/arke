//
//  QRScannerView_iOS.swift
//  Arké
//
//  Created by Assistant on 12/12/25.
//

import SwiftUI
import AVFoundation
import Combine

/// QR Scanner view for scanning Bitcoin addresses and BIP-21 URIs
struct QRScannerView_iOS: View {
    let onCodeScanned: (String) -> Void
    
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: cameraManager.captureSession)
                .ignoresSafeArea()
            
            // Permission denied overlay
            if cameraManager.permissionDenied {
                permissionDeniedView
            }
            
            // Scanning reticle overlay
            if !cameraManager.permissionDenied {
                scanningOverlay
            }
        }
        .onAppear {
            print("📷 [QRScannerView] View appeared - starting camera")
            cameraManager.checkPermissionsAndStartSession()
            cameraManager.onCodeDetected = onCodeScanned
        }
        .onDisappear {
            print("📷 [QRScannerView] View disappeared - stopping camera")
            cameraManager.stopSession()
        }
    }
    
    @ViewBuilder
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundStyle(.white)
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text("Please enable camera access in Settings to scan QR codes")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Button {
                    UIApplication.shared.open(settingsURL)
                } label: {
                    Text("Open Settings")
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.9))
    }
    
    @ViewBuilder
    private var scanningOverlay: some View {
        VStack {
            Spacer()
            
            // Scanning frame
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white, lineWidth: 3)
                .frame(width: 250, height: 250)
            
            Spacer()
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame when view size changes
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Camera Manager

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var permissionDenied = false
    
    let captureSession = AVCaptureSession()
    var onCodeDetected: ((String) -> Void)?
    
    private var hasScanned = false
    
    func checkPermissionsAndStartSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📷 [CameraManager] Checking permissions - status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("📷 [CameraManager] Already authorized - starting session")
            // If session is already configured, just restart it
            if !captureSession.inputs.isEmpty && !captureSession.outputs.isEmpty {
                print("📷 [CameraManager] Session already configured - restarting")
                startSession()
            } else {
                print("📷 [CameraManager] Setting up session for first time")
                setupCaptureSession()
            }
        case .notDetermined:
            print("📷 [CameraManager] Permission not determined - requesting access")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    print("📷 [CameraManager] Permission response - granted: \(granted)")
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            print("📷 [CameraManager] Permission denied or restricted")
            permissionDenied = true
        @unknown default:
            print("📷 [CameraManager] Unknown permission status")
            permissionDenied = true
        }
    }
    
    private func setupCaptureSession() {
        print("📷 [CameraManager] Setting up capture session...")
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ [CameraManager] No video capture device available")
            return
        }
        
        print("📷 [CameraManager] Video capture device found: \(videoCaptureDevice.localizedName)")
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            print("📷 [CameraManager] Video input created successfully")
        } catch {
            print("❌ [CameraManager] Error creating video input: \(error)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            print("✅ [CameraManager] Video input added to session")
        } else {
            print("❌ [CameraManager] Cannot add video input to session")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            print("✅ [CameraManager] Metadata output added to session")
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
            print("✅ [CameraManager] Metadata delegate set - listening for QR codes")
        } else {
            print("❌ [CameraManager] Cannot add metadata output to session")
            return
        }
        
        startSession()
    }
    
    func startSession() {
        print("📷 [CameraManager] Starting session - isRunning: \(captureSession.isRunning)")
        guard !captureSession.isRunning else {
            print("⏭️ [CameraManager] Session already running")
            return
        }
        
        Task {
            captureSession.startRunning()
            print("✅ [CameraManager] Session started - isRunning: \(captureSession.isRunning)")
        }
    }
    
    func stopSession() {
        print("📷 [CameraManager] Stopping session - isRunning: \(captureSession.isRunning)")
        if captureSession.isRunning {
            Task {
                captureSession.stopRunning()
                print("✅ [CameraManager] Session stopped")
            }
        }
        hasScanned = false
        print("📷 [CameraManager] hasScanned reset to false")
    }
}

// MARK: - Metadata Output Delegate

extension CameraManager: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        print("📷 [CameraManager] metadataOutput called - objects count: \(metadataObjects.count)")
        
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            print("📷 [CameraManager] No valid QR code found in metadata")
            return
        }
        
        print("🎯 [CameraManager] QR code detected: '\(stringValue)'")
        
        Task { @MainActor in
            print("📷 [CameraManager] Processing on MainActor - hasScanned: \(hasScanned)")
            
            // Only process the first scan, ignore subsequent detections
            guard !hasScanned else {
                print("⏭️ [CameraManager] Already scanned, ignoring")
                return
            }
            hasScanned = true
            print("✅ [CameraManager] First scan - setting hasScanned = true")
            
            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            print("✅ [CameraManager] Haptic feedback triggered")
            
            // Call the completion handler
            print("📤 [CameraManager] Calling onCodeDetected with: '\(stringValue)'")
            onCodeDetected?(stringValue)
        }
    }
}

// MARK: - Preview

#Preview {
    QRScannerView_iOS { code in
        print("Scanned: \(code)")
    }
}
