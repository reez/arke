//
//  RefreshModalFormView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/24/25.
//

import SwiftUI

struct RefreshModalFormView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            #if os(iOS)
            LoopingVideoPlayer_iOS.aspectFill(videoName: "poolside", videoExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(25)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 30, height: 30)
                    }
                    .accessibilityLabel("Close")
                    .buttonStyle(.bordered)
                    .clipShape(Circle())
                    .padding(.trailing, 8)
                    .padding(.top, 12)
                }
            #elseif os(macOS)
            LoopingVideoPlayer.aspectFill(videoName: "poolside", videoExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(15)
                .clipped()
            #endif
            
            /*
            Image("board") // Using same image as boarding for now
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: 250)
                .cornerRadius(25)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 30, height: 30)
                    }
                    .accessibilityLabel("Close")
                    .buttonStyle(.bordered)
                    .clipShape(Circle())
                    .padding(.trailing, 8)
                    .padding(.top, 12)
                }
            */
            
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("Refresh payments balance")
                        .font(.system(.title, design: .serif))
                    
                    Text("This is a regular maintenance task to keep your balance active for fast and low-fee payments.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal)
                }
            }
            
            Button {
                onConfirm()
            } label: {
                Text("Start")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.arkeDark)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Color.arkeGold)
        }
        .padding()
    }
}

#Preview {
    RefreshModalFormView(
        onConfirm: {
            print("Refreshing wallet")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
