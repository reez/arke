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
            LoopingVideoPlayer.aspectFill(videoName: "poolside", videoExtension: "mp4")
                .frame(maxWidth: .infinity, minHeight: 250)
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Refreshing your balance")
                        .font(.system(size: 24, design: .serif))
                    
                    Text("Get excited for a fresh and new experience.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal)
                }
                
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 25)
    }
}

#Preview {
    RefreshModalRefreshingView()
        .frame(width: 400, height: 400)
}
