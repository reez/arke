//
//  BoardingModalSuccessView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/19/25.
//

import SwiftUI

struct BoardingModalSuccessView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            #if os(iOS)
            LoopingVideoPlayer_iOS.aspectFill(videoName: "thumbs-up-animation", videoExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(25)
                .clipped()
            #elseif os(macOS)
            LoopingVideoPlayer.aspectFill(videoName: "thumbs-up-animation", videoExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(15)
                .clipped()
            #endif
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Transfer Initiated")
                        .font(.system(.title, design: .serif))
                    
                    Text("Your coins are being transferred to your payment balance on the Ark network and will be ready to use in a jiffy.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
            }
            
            Button {
                onContinue()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 27))
                    .foregroundStyle(Color.arkeDark)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Done")
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Color.arkeGold)
        }
        .padding()
    }
}

#Preview {
    BoardingModalSuccessView {
        print("Done tapped")
    }
    .frame(width: 400, height: 400)
}
