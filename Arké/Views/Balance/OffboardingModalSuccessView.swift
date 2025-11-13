//
//  OffboardingModalSuccessView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/19/25.
//

import SwiftUI

struct OffboardingModalSuccessView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            LoopingVideoPlayer.aspectFill(videoName: "coffee-clapping", videoExtension: "mp4")
                .frame(maxWidth: .infinity, minHeight: 250)
            
            VStack(spacing: 15) {
                VStack(spacing: 8) {
                    Text("Transfer Initiated")
                        .font(.system(size: 24, design: .serif))
                    
                    Text("Your coins are being transferred to your Savings balance. This process may take some time to complete.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal)
                }
            
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(size: .medium)
            }
        }
        .padding(.bottom, 25)
    }
}

#Preview {
    OffboardingModalSuccessView {
        print("Continue tapped")
    }
    .frame(width: 400, height: 400)
}
