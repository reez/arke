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
        qrImage = QRCodeGenerator.shared.generateSimpleQRCode(from: content)
    }
    
    private func generateSecondQRCode() {
        // Generate personalized QR code with user avatar or app logo
        qrImage2 = QRCodeGenerator.shared.generatePersonalizedQRCode(
            from: content,
            avatarData: userProfile?.avatarData
        )
    }
}
