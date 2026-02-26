//
//  OffboardingModalSuccessView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/19/25.
//

import SwiftUI
import ArkeUI

struct OffboardingModalSuccessView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            #if os(iOS)
            LoopingVideoPlayer_iOS.aspectFill(videoName: "coffee-clapping", videoExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(25)
                .clipped()
            #elseif os(macOS)
            LoopingVideoPlayer.aspectFill(videoName: "coffee-clapping", videoExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(15)
                .clipped()
            #endif
            
            VStack(spacing: 15) {
                VStack(spacing: 8) {
                    Text("Transfer Initiated")
                        .font(.system(.title, design: .serif))
                    
                    Text("Your coins are being transferred to your savings balance. This process may take a moment to complete.")
                        .font(.title3)
                        .foregroundColor(.arkeSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 40)
                }
            
                Button {
                    onContinue()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 27))
                        .foregroundStyle(Color.Arke.gold3)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(Color.Arke.gold)
            }
        }
        .padding()
    }
}

#Preview {
    OffboardingModalSuccessView {
        print("Continue tapped")
    }
    .frame(width: 400, height: 400)
}
