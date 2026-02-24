//
//  SendModalSuccessView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/20/25.
//

import SwiftUI
import ArkeUI

struct SendModalSuccessView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            #if os(iOS)
            LoopingVideoPlayer_iOS.aspectFill(videoName: "puppy-thumbs-up", videoExtension: "mp4")
                .frame(maxWidth: .infinity, minHeight: 250)
            #elseif os(macOS)
            LoopingVideoPlayer.aspectFill(videoName: "puppy-thumbs-up", videoExtension: "mp4")
                .frame(maxWidth: .infinity, minHeight: 250)
            #endif
            
            VStack(spacing: 15) {
                VStack(spacing: 8) {
                    Text("Payment Sent")
                        .font(.system(size: 24, design: .serif))
                    
                    Text("It will be confirmed shortly.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal)
                }
                
                Button("Done") {
                    onContinue()
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(.bottom, 25)
    }
}

#Preview {
    SendModalSuccessView {
        print("Done tapped")
    }
    .frame(width: 400, height: 400)
}
