//
//  RefreshModalSuccessView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/24/25.
//

import SwiftUI

struct RefreshModalSuccessView: View {
    let onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            LoopingVideoPlayer.aspectFill(videoName: "poolside-pose", videoExtension: "mp4")
                .frame(maxWidth: .infinity, minHeight: 250)
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Refresh complete")
                        .font(.system(size: 24, design: .serif))
                    
                    Text("Your spending balance has been successfully updated.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 40)
                }
            
                Button("Done") {
                    onDone()
                }
                .buttonStyle(size: .medium)
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }
}

#Preview {
    RefreshModalSuccessView {
        print("Done tapped")
    }
}
