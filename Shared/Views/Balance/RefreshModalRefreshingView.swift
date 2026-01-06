//
//  RefreshModalRefreshingView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/24/25.
//

import SwiftUI

struct RefreshModalRefreshingView: View {
    var onCancel: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 25) {
            #if os(iOS)
            LoopingVideoPlayer_iOS.aspectFill(videoName: "poolside", videoExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(25)
                .clipped()
            #elseif os(macOS)
            LoopingVideoPlayer.aspectFill(videoName: "poolside", videoExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(15)
                .clipped()
            #endif
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Refreshing your balance")
                        .font(.system(.title, design: .serif))
                    
                    Text("Get excited for a fresh and new experience.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.arkeDark)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .tint(Color.arkeGold)
            }
        }
        .padding()
    }
}

#Preview {
    RefreshModalRefreshingView()
        .frame(width: 400, height: 400)
}
