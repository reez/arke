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
    let onBack: (() -> Void)?
    let onContinue: (() -> Void)?
    let onSkip: (() -> Void)?
    
    @State private var showPlaylist = false
    @State private var currentVideoIndex = 0
    @State private var isMuted = false
    @State private var isPaused = false
    
    private let videos: [IntroVideo] = [
        IntroVideo(
            title: "Welcome",
            thumbnailName: "1-intro-v2-small-image",
            videoAssetName: "1-intro-v2-small",
            subtitles: [
                VideoSubtitle(startTime: 0.020, endTime: 1.520, text: "Hey, welcome to Arké."),
                VideoSubtitle(startTime: 2.420, endTime: 4.100, text: "You're about to try something new."),
                VideoSubtitle(startTime: 4.760, endTime: 7.060, text: "A bitcoin wallet built for real payments."),
                VideoSubtitle(startTime: 7.860, endTime: 10.200, text: "Fast, cheap, and fully yours."),
                VideoSubtitle(startTime: 11.260, endTime: 15.200, text: "Before you dive in, my friends are going to walk you through how things work.")
            ]
        ),
        IntroVideo(
            title: "You're early",
            thumbnailName: "2-testing-cherry-blossom-v2-small-image",
            videoAssetName: "2-testing-cherry-blossom-v2-small",
            subtitles: [
                VideoSubtitle(startTime: 0.020, endTime: 1.300, text: "First, a heads up."),
                VideoSubtitle(startTime: 1.900, endTime: 2.280, text: "You're early."),
                VideoSubtitle(startTime: 3.000, endTime: 4.200, text: "Arké is still in testing."),
                VideoSubtitle(startTime: 4.900, endTime: 6.320, text: "The Bitcoin in here isn't real."),
                VideoSubtitle(startTime: 6.660, endTime: 7.320, text: "It's play money."),
                VideoSubtitle(startTime: 8.080, endTime: 10.080, text: "That means you can try everything without risk."),
                VideoSubtitle(startTime: 10.780, endTime: 12.720, text: "It also means things might break sometimes."),
                VideoSubtitle(startTime: 13.460, endTime: 13.960, text: "That's fine."),
                VideoSubtitle(startTime: 14.500, endTime: 15.560, text: "That's what testing is for.")
            ]
        ),
        IntroVideo(
            title: "It's yours",
            thumbnailName: "3-ownership-v2-small-image",
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
            title: "Instant payments",
            thumbnailName: "4-speed-small-image",
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
            title: "Two balances",
            thumbnailName: "5-two-balances-v2-small-image",
            videoAssetName: "5-two-balances-v2-small",
            subtitles: [
                VideoSubtitle(startTime: 0.020, endTime: 3.780, text: "One thing to know, your wallet has two balances."),
                VideoSubtitle(startTime: 5.000, endTime: 6.520, text: "Savings is for holding."),
                VideoSubtitle(startTime: 7.460, endTime: 10.900, text: "Fully independent, nothing to rely on but yourself."),
                VideoSubtitle(startTime: 12.240, endTime: 14.380, text: "Spending is for everyday use."),
                VideoSubtitle(startTime: 15.060, endTime: 17.080, text: "Instant payments, tiny fees."),
                VideoSubtitle(startTime: 18.180, endTime: 21.500, text: "It uses a coordination server to make things fast."),
                VideoSubtitle(startTime: 22.400, endTime: 26.240, text: "But that server can never access your money or see your balance."),
                VideoSubtitle(startTime: 27.140, endTime: 30.280, text: "You can move funds between them whenever you like.")
            ]
        ),
        IntroVideo(
            title: "Get started",
            thumbnailName: "6-get-started-small-image",
            videoAssetName: "6-get-started-small",
            subtitles: [
                VideoSubtitle(startTime: 0.020, endTime: 1.440, text: "That's really all you need to know."),
                VideoSubtitle(startTime: 2.620, endTime: 7.800, text: "Once you're set up, grab some free test Bitcoin and try your first payment."),
                VideoSubtitle(startTime: 8.660, endTime: 9.460, text: "See how it feels."),
                VideoSubtitle(startTime: 10.340, endTime: 11.080, text: "Break things."),
                VideoSubtitle(startTime: 11.780, endTime: 12.820, text: "Let us know what's broken."),
                VideoSubtitle(startTime: 13.740, endTime: 15.240, text: "You're not just a user here."),
                VideoSubtitle(startTime: 15.940, endTime: 17.420, text: "You're helping us build this."),
                VideoSubtitle(startTime: 18.460, endTime: 18.720, text: "Ready?")
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
                    } else if let onContinue {
                        onContinue()
                    }
                }
            )
            .id(currentVideoIndex) // Force recreation when video changes
            .ignoresSafeArea()
            
            // Top toolbar overlay
            VStack {
                HStack {
                    if let onBack {
                        Button {
                            onBack()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20))
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.glass)
                        .colorScheme(.dark)
                        .tint(Color.arkeGold)
                        .accessibilityLabel("Back")
                    }
                    
                    Spacer()
                    
                    Button {
                        showPlaylist.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .colorScheme(.dark)
                    .tint(Color.arkeGold)
                    .accessibilityLabel("Video menu")
                    
                    Button {
                        isMuted.toggle()
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 20))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .colorScheme(.dark)
                    .tint(Color.arkeGold)
                    .accessibilityLabel(isMuted ? "Unmute audio" : "Mute audio")
                    
                    if let onSkip {
                        Button {
                            onSkip()
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 20))
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.glass)
                        .colorScheme(.dark)
                        .tint(Color.arkeGold)
                        .accessibilityLabel("Skip")
                    }
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
        onBack: {},
        onContinue: {},
        onSkip: nil
    )
}
