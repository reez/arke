//
//  WalletActiveElsewhereView.swift
//  Arké
//
//  Created by Claude on 2026-05-07.
//

import SwiftUI
import ArkeUI

struct WalletActiveElsewhereView: View {
    let primaryDeviceName: String
    let onMigrateToThisDevice: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            VStack {
                // Left column - Big video
                LoopingVideoPlayer(videoName: "cover-animation", videoExtension: "mp4")
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            .frame(maxWidth: .infinity)
            
            // Right column - Content
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "lock.desktopcomputer")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.Arke.gold)
                    
                    Text("Wallet Active on Another Device")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Your wallet is currently active on **\(primaryDeviceName)**. Only one device can be active at a time.")
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.top, 8)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button("Make This Device Active") {
                        onMigrateToThisDevice()
                    }
                    .buttonStyle(ArkeButtonStyle(size: .large))
                    
                    Text("This will deactivate your wallet on \(primaryDeviceName)")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
            .frame(maxWidth: .infinity)
        }
        .background(Color.Arke.gold3)
    }
}

#Preview {
    WalletActiveElsewhereView(
        primaryDeviceName: "Christoph's MacBook Pro",
        onMigrateToThisDevice: {}
    )
    .frame(width: 600, height: 700)
}
