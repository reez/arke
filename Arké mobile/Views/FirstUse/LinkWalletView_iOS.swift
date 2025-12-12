//
//  LinkWalletView_iOS.swift
//  Ark wallet prototype
//
//  Created by Christoph on 12/01/25.
//

import SwiftUI
import Combine
import Foundation
import AVFoundation

struct LinkWalletView_iOS: View {
    let onBack: () -> Void
    let onWalletLinked: () -> Void
    
    @Environment(WalletManager.self) private var walletManager
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLinking = false
    @State private var cameraPermissionGranted = false
    @State private var scannedRecoveryPhrase: String?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 30) {
                    HStack {
                        Button {
                            onBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .tint(Color.arkeGold)
                        .accessibilityLabel("Back")
                        
                        Spacer()
                    }
                    .padding(.top, 10)
                    
                    VStack(spacing: 8) {
                        Text("Link Wallet")
                            .font(.system(size: 36, design: .serif))
                            .foregroundStyle(Color.arkeGold)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Connect your existing wallet to this app.")
                            .font(.system(size: 21))
                            .lineSpacing(4)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // QR Scanner Section
                    VStack(spacing: 16) {
                        Text("Scan Recovery Phrase QR Code")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                        
                        if cameraPermissionGranted {
                            QRCodeScannerView { qrContent in
                                handleScannedQR(qrContent)
                            }
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.arkeGold, lineWidth: 2)
                            )
                            .overlay {
                                // Scanning target overlay
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.arkeGold.opacity(0.8), lineWidth: 3)
                                    .frame(width: 200, height: 200)
                            }
                            
                            if scannedRecoveryPhrase != nil {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Recovery phrase detected")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.2))
                                .clipShape(Capsule())
                            }
                            
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(Color.arkeGold.opacity(0.5))
                                
                                Text("Camera access required to scan QR codes")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                
                                Button {
                                    requestCameraPermission()
                                } label: {
                                    Text("Enable Camera")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.arkeDark)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color.arkeGold)
                                        .clipShape(Capsule())
                                }
                            }
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    if scannedRecoveryPhrase != nil {
                        Button {
                            Task {
                                await linkWallet()
                            }
                        } label: {
                            HStack {
                                if isLinking {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Link Wallet")
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundStyle(Color.arkeDark)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 20)
                                }
                            }
                            .foregroundStyle(Color.arkeDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.arkeGold)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .tint(Color.arkeGold)
                        .disabled(isLinking)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, safeAreaInsets.top)
                .padding(.bottom, safeAreaInsets.bottom)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.arkeDark)
        .ignoresSafeArea()
        .task {
            await checkCameraPermission()
        }
        .alert("Link Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func checkCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            cameraPermissionGranted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            cameraPermissionGranted = false
        }
    }
    
    private func requestCameraPermission() {
        Task {
            await checkCameraPermission()
        }
    }
    
    private func handleScannedQR(_ content: String) {
        // Validate that this looks like a recovery phrase
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // Basic validation - recovery phrases are typically 12 or 24 words
        guard words.count == 12 || words.count == 24 else {
            showError("Invalid recovery phrase format. Expected 12 or 24 words.")
            return
        }
        
        // Store the scanned phrase
        scannedRecoveryPhrase = content
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func linkWallet() async {
        guard let recoveryPhrase = scannedRecoveryPhrase else {
            showError("No recovery phrase scanned")
            return
        }
        
        isLinking = true
        defer { isLinking = false }
        
        do {
            // Use WalletManager to import the wallet
            let result = try await walletManager.importWallet(mnemonic: recoveryPhrase)
            print("✅ Wallet linked successfully: \(result)")
            
            // Clear the recovery phrase from memory for security
            scannedRecoveryPhrase = nil
            
            // Success - call the completion handler
            onWalletLinked()
            
        } catch {
            showError("Failed to link wallet: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - QR Code Scanner View

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onQRCodeDetected: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let controller = QRCodeScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onQRCodeDetected: onQRCodeDetected)
    }
    
    class Coordinator: NSObject, QRCodeScannerDelegate {
        let onQRCodeDetected: (String) -> Void
        private var hasScanned = false
        
        init(onQRCodeDetected: @escaping (String) -> Void) {
            self.onQRCodeDetected = onQRCodeDetected
        }
        
        func didDetectQRCode(_ code: String) {
            // Only process the first scan to avoid multiple triggers
            guard !hasScanned else { return }
            hasScanned = true
            
            onQRCodeDetected(code)
            
            // Reset after a delay to allow re-scanning if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.hasScanned = false
            }
        }
    }
}

// MARK: - QR Code Scanner View Controller

protocol QRCodeScannerDelegate: AnyObject {
    func didDetectQRCode(_ code: String)
}

class QRCodeScannerViewController: UIViewController {
    weak var delegate: QRCodeScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let captureSession = captureSession, !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let captureSession = captureSession, captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
            }
        }
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Error creating video input: \(error)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRCodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           metadataObject.type == .qr,
           let stringValue = metadataObject.stringValue {
            delegate?.didDetectQRCode(stringValue)
        }
    }
}

#Preview {
    LinkWalletView_iOS(
        onBack: {},
        onWalletLinked: {}
    )
    .environment(WalletManager(useMock: true))
    .frame(width: 600, height: 700)
}
