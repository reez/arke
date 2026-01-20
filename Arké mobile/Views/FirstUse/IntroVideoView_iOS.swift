//
//  IntroVideoView_iOS.swift
//  Arké
//
//  Created by Christoph on 01/20/26.
//

import SwiftUI

struct IntroVideo: Identifiable {
    let id = UUID()
    let title: String
    let thumbnailName: String
    let videoAssetName: String
    let subtitles: [VideoSubtitle]
}

struct IntroVideoView_iOS: View {
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    @State private var showPlaylist = false
    @State private var currentVideoIndex = 0
    @State private var isMuted = false
    @State private var isPaused = false
    
    private let videos: [IntroVideo] = [
        IntroVideo(
            title: "Getting Started",
            thumbnailName: "avatar-female-2",
            videoAssetName: "1-intro-small",
            subtitles: [
                VideoSubtitle(startTime: 0.020, endTime: 1.500, text: "Hey, welcome to Arké."),
                VideoSubtitle(startTime: 2.620, endTime: 7.100, text: "This is a Bitcoin wallet, but one that actually works for everyday payments."),
                VideoSubtitle(startTime: 8.220, endTime: 12.660, text: "Fast transfers, tiny fees, and you stay in control of your money."),
                VideoSubtitle(startTime: 13.320, endTime: 15.560, text: "Let's talk very briefly about how it works.")
            ]
        ),
        IntroVideo(
            title: "Welcome to Arké",
            thumbnailName: "avatar-female-1",
            videoAssetName: "2-testing-cherry-blossom-small",
            subtitles: [
                VideoSubtitle(startTime: 0.020, endTime: 1.280, text: "First, a heads up."),
                VideoSubtitle(startTime: 1.900, endTime: 2.300, text: "You're early."),
                VideoSubtitle(startTime: 3.140, endTime: 4.300, text: "Arké is still in testing."),
                VideoSubtitle(startTime: 5.040, endTime: 6.400, text: "The Bitcoin in here isn't real."),
                VideoSubtitle(startTime: 6.920, endTime: 7.460, text: "It's play money."),
                VideoSubtitle(startTime: 8.140, endTime: 10.020, text: "That means you can try everything without risk."),
                VideoSubtitle(startTime: 10.700, endTime: 12.520, text: "It also means things might break sometimes."),
                VideoSubtitle(startTime: 13.420, endTime: 13.940, text: "That's fine."),
                VideoSubtitle(startTime: 14.420, endTime: 15.580, text: "That's what testing is for.")
            ]
        ),
        IntroVideo(
            title: "Core Features",
            thumbnailName: "avatar-female-3",
            videoAssetName: "3-ownership-v2-small",
            subtitles: [
                VideoSubtitle(startTime: 0.020, endTime: 2.260, text: "This wallet belongs entirely to you."),
                VideoSubtitle(startTime: 2.850, endTime: 6.560, text: "No accounts, no logins, no company holding your funds."),
                VideoSubtitle(startTime: 7.360, endTime: 9.220, text: "You'll get a 12 word recovery phrase,"),
                VideoSubtitle(startTime: 9.670, endTime: 12.740, text: "and your wallet will back up data to iCloud automatically."),
                VideoSubtitle(startTime: 13.520, endTime: 15.260, text: "You need both to restore your wallet."),
                VideoSubtitle(startTime: 15.850, endTime: 19.840, text: "So keep your phrase somewhere safe and stay signed in to iCloud.")
            ]
        ),
        IntroVideo(
            title: "Advanced Techniques",
            thumbnailName: "avatar-female-4",
            videoAssetName: "4-speed-small",
            subtitles: [
                VideoSubtitle(startTime: 0.020, endTime: 2.720, text: "So why Arké instead of a regular Bitcoin wallet?"),
                VideoSubtitle(startTime: 4.100, endTime: 5.560, text: "Normally Bitcoin payments are slow."),
                VideoSubtitle(startTime: 6.600, endTime: 8.780, text: "You wait for confirmations, fees add up."),
                VideoSubtitle(startTime: 9.320, endTime: 10.660, text: "It's not great for grabbing coffee."),
                VideoSubtitle(startTime: 11.760, endTime: 12.620, text: "Arké fixes that."),
                VideoSubtitle(startTime: 13.520, endTime: 15.820, text: "Payments arrive in seconds, fees are almost nothing."),
                VideoSubtitle(startTime: 16.580, endTime: 18.400, text: "Same Bitcoin, just a better experience.")
            ]
        ),
        IntroVideo(
            title: "Tips & Tricks",
            thumbnailName: "avatar-male-1",
            videoAssetName: "puppy-idle",
            subtitles: [
                VideoSubtitle(startTime: 0.0, endTime: 2.5, text: "Pro tips to enhance your experience"),
                VideoSubtitle(startTime: 2.5, endTime: 5.5, text: "Work smarter, not harder")
            ]
        ),
        IntroVideo(
            title: "Community & Support",
            thumbnailName: "avatar-male-2",
            videoAssetName: "tai-chi",
            subtitles: [
                VideoSubtitle(startTime: 0.0, endTime: 3.0, text: "Join our community"),
                VideoSubtitle(startTime: 3.0, endTime: 6.0, text: "We're here to help you succeed")
            ]
        )
    ]
    
    var body: some View {
        ZStack {
            // Full screen video player
            IntroVideoPlayer_iOS(
                videoName: videos[currentVideoIndex].videoAssetName,
                videoExtension: "mp4",
                subtitles: videos[currentVideoIndex].subtitles,
                isMuted: $isMuted,
                isPaused: $isPaused,
                onVideoEnded: {
                    // Auto-advance to next video or call onContinue if last video
                    if currentVideoIndex < videos.count - 1 {
                        currentVideoIndex += 1
                    } else {
                        onContinue()
                    }
                }
            )
            .id(currentVideoIndex) // Force recreation when video changes
            .ignoresSafeArea()
            
            // Top toolbar overlay
            VStack {
                HStack {
                    Button {
                        showPlaylist.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .tint(Color.arkeGold)
                    .accessibilityLabel("Video menu")
                    
                    Spacer()
                    
                    Button {
                        isMuted.toggle()
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 20))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .tint(Color.arkeGold)
                    .accessibilityLabel(isMuted ? "Unmute audio" : "Mute audio")
                    
                    Button {
                        onSkip()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .tint(Color.arkeGold)
                    .accessibilityLabel("Skip")
                }
                .padding(.horizontal, 16)
                .padding(.top, safeAreaInsets.top + 8)
                .padding(.bottom, 8)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                Spacer()
            }
            
            // Playlist overlay
            if showPlaylist {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showPlaylist = false
                    }
                
                VStack(spacing: 0) {
                    // Video list
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                                VideoListItem(
                                    video: video,
                                    index: index,
                                    isCurrentlyPlaying: index == currentVideoIndex
                                ) {
                                    currentVideoIndex = index
                                    showPlaylist = false
                                }
                            }
                        }
                        .padding(16)
                    }
                    .background(Color.arkeDark.opacity(0.98))
                }
                .frame(maxWidth: 400)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .shadow(color: .black.opacity(0.5), radius: 20)
                .padding(.horizontal, 16)
                .padding(.vertical, safeAreaInsets.top + 60)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .background(Color.arkeDark)
        .ignoresSafeArea()
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPlaylist)
        .onChange(of: showPlaylist) { _, newValue in
            isPaused = newValue
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

struct VideoListItem: View {
    let video: IntroVideo
    let index: Int
    let isCurrentlyPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                // Thumbnail
                ZStack {
                    // Background image
                    Image(video.thumbnailName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    
                    // Overlay gradient for better icon visibility
                    RoundedRectangle(cornerRadius: 15)
                        .fill(
                            LinearGradient(
                                colors: [.black.opacity(0.4), .clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    // Play indicator or video number
                    if isCurrentlyPlaying {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.arkeGold)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                }
                
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    if isCurrentlyPlaying {
                        Text("Now Playing")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.arkeGold)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(isCurrentlyPlaying ? Color.arkeGold.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    IntroVideoView_iOS(
        onContinue: {},
        onSkip: {}
    )
}
