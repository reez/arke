//
//  FirstUseView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct FirstUseView_iOS: View {
    let onCreateWallet: () -> Void
    let onImportWallet: () -> Void
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background video covering entire view
            LoopingVideoPlayer_iOS(videoName: "cover-animation", videoExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
            
            // Content overlaid at bottom
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text("Arké")
                        .font(.system(size: 80, design: .serif))
                        .fontWeight(.regular)
                        .foregroundStyle(Color.arkeGold)
                }
                
                VStack(spacing: 16) {
                    Button("Create new wallet") {
                        onCreateWallet()
                    }
                    .buttonStyle(ArkeButtonStyle(size: .large))
                    
                    Button("Import existing wallet") {
                        onImportWallet()
                    }
                    .buttonStyle(ArkeButtonStyle(size: .large, variant: .outline))
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
            .frame(maxWidth: .infinity)
        }
        .background(Color.arkeDark)
    }
}

#Preview {
    FirstUseView_iOS(
        onCreateWallet: {},
        onImportWallet: {}
    )
    .frame(width: 600, height: 700)
}
