//
//  OffboardingModalOffboardingView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/12/25.
//

import SwiftUI

struct OffboardingModalOffboardingView: View {
    var body: some View {
        VStack(spacing: 25) {
            LoopingVideoPlayer.aspectFill(videoName: "coffee", videoExtension: "mp4")
                .frame(maxWidth: .infinity, minHeight: 250)
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Preparing Transfer")
                        .font(.system(size: 24, design: .serif))
                    
                    Text("This may take a moment.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.bottom, 25)
    }
}

#Preview {
    OffboardingModalOffboardingView()
        .frame(width: 400, height: 400)
}
