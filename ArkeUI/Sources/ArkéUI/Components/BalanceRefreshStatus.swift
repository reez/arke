//
//  BalanceRefreshStatus.swift
//  ArkéUI
//
//  Created by Christoph on 2/23/26.
//

import SwiftUI

public struct BalanceRefreshData {
    public var isLoading: Bool
    public var hasActiveRefresh: Bool
    public var urgencyColor: Color
    public var statusMessage: String
    public var timeUntilExpiry: String?
    public var isExpired: Bool
    public var expiredAgoString: String?
    public var showActionButton: Bool
    public var nextRoundStartTime: UInt64?
    public var onRefresh: (() async -> Void)?

    public init(
        isLoading: Bool = false,
        hasActiveRefresh: Bool = false,
        urgencyColor: Color = .gray,
        statusMessage: String = "",
        timeUntilExpiry: String? = nil,
        isExpired: Bool = false,
        expiredAgoString: String? = nil,
        showActionButton: Bool = false,
        nextRoundStartTime: UInt64? = nil,
        onRefresh: (() async -> Void)? = nil
    ) {
        self.isLoading = isLoading
        self.hasActiveRefresh = hasActiveRefresh
        self.urgencyColor = urgencyColor
        self.statusMessage = statusMessage
        self.timeUntilExpiry = timeUntilExpiry
        self.isExpired = isExpired
        self.expiredAgoString = expiredAgoString
        self.showActionButton = showActionButton
        self.nextRoundStartTime = nextRoundStartTime
        self.onRefresh = onRefresh
    }
}

public struct BalanceRefreshStatus: View {
    let data: BalanceRefreshData
    @State private var currentTime = Date()

    public init(data: BalanceRefreshData) {
        self.data = data
    }

    private var timeUntilNextRound: String? {
        guard let nextRoundTimestamp = data.nextRoundStartTime else {
            return nil
        }

        let currentTimeValue = UInt64(currentTime.timeIntervalSince1970)

        guard nextRoundTimestamp > currentTimeValue else {
            return nil  // Round has passed
        }

        let secondsUntilRound = Int(nextRoundTimestamp - currentTimeValue)
        return formatTimeInterval(secondsUntilRound)
    }

    private func formatTimeInterval(_ seconds: Int) -> String {
        if seconds < 60 { return "< 1m" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(seconds)) ?? "< 1m"
    }

    public var body: some View {
        Group {
            if data.isLoading {
                loadingView
            } else {
                contentView
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Date()
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise")
                .font(.title3)
                .foregroundColor(.gray)
                .frame(width: 32, height: 32)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Payments balance refresh")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text("Loading...")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            ProgressView().controlSize(.small)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 15)
        .background(.gray.opacity(0.1))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(data.urgencyColor)
                    .cornerRadius(8)
                
                Text("Payments balance refresh")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 15)
            .padding(.top, 15)
            .padding(.bottom, 15)
            
            if data.hasActiveRefresh {
                refreshingContent
            } else if data.statusMessage.isEmpty {
                emptyStateContent
            } else {
                timeDisplayContent
            }
        }
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private var refreshingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Refreshing...")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let nextRound = timeUntilNextRound {
                HStack(alignment: .center, spacing: 4) {
                    Text("Next round").font(.body).foregroundStyle(.secondary)
                    Spacer()
                    Text(nextRound).font(.body).fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 15)
    }
    
    @ViewBuilder
    private var emptyStateContent: some View {
        Text("Not needed for empty balance")
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 15)
            .padding(.bottom, 15)
    }
    
    @ViewBuilder
    private var timeDisplayContent: some View {
        VStack(spacing: 15) {
            if data.isExpired {
                expiredContent
            } else {
                timesContent
            }
            
            if data.showActionButton {
                Button {
                    Task { await data.onRefresh?() }
                } label: {
                    Text("Start")
                        .font(.system(size: 21, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.regular)
                .buttonStyle(.glassProminent)
                .tint(.yellow)
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 15)
    }
    
    @ViewBuilder
    private var expiredContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                Text("Status").font(.body).foregroundStyle(.secondary)
                Spacer()
                Text(data.statusMessage).font(.body).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if let ago = data.expiredAgoString {
                HStack(alignment: .center, spacing: 4) {
                    Text("Expired").font(.body).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(ago) ago").font(.body).fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let nextRound = timeUntilNextRound {
                HStack(alignment: .center, spacing: 4) {
                    Text("Next round").font(.body).foregroundStyle(.secondary)
                    Spacer()
                    Text(nextRound).font(.body).fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var timesContent: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 4) {
                Text("Status").font(.body).foregroundStyle(.secondary)
                Spacer()
                Text(data.statusMessage).font(.body).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let expiry = data.timeUntilExpiry {
                HStack(alignment: .center, spacing: 4) {
                    Text("Time until expiry").font(.body).foregroundStyle(.secondary)
                    Spacer()
                    Text(expiry).font(.body).fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let nextRound = timeUntilNextRound {
                HStack(alignment: .center, spacing: 4) {
                    Text("Next round").font(.body).foregroundStyle(.secondary)
                    Spacer()
                    Text(nextRound).font(.body).fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Previews

#Preview("Loading") {
    BalanceRefreshStatus(data: BalanceRefreshData(isLoading: true))
        .padding()
}

#Preview("Empty balance") {
    BalanceRefreshStatus(data: BalanceRefreshData(
        urgencyColor: .gray,
        statusMessage: ""
    ))
    .padding()
}

#Preview("Safe") {
    BalanceRefreshStatus(data: BalanceRefreshData(
        urgencyColor: .green,
        statusMessage: "Not needed",
        timeUntilExpiry: "10d 4h",
        showActionButton: false,
        nextRoundStartTime: UInt64(Date().timeIntervalSince1970) + 3600 // 1 hour from now
    ))
    .padding()
}

#Preview("Warning") {
    BalanceRefreshStatus(data: BalanceRefreshData(
        urgencyColor: .yellow,
        statusMessage: "Recommended",
        timeUntilExpiry: "2d 3h",
        showActionButton: true,
        nextRoundStartTime: UInt64(Date().timeIntervalSince1970) + 1800 // 30 minutes from now
    ))
    .padding()
}

#Preview("Critical") {
    BalanceRefreshStatus(data: BalanceRefreshData(
        urgencyColor: .red,
        statusMessage: "Urgent",
        timeUntilExpiry: "12h 4m",
        showActionButton: true,
        nextRoundStartTime: UInt64(Date().timeIntervalSince1970) + 300 // 5 minutes from now
    ))
    .padding()
}

#Preview("Expired") {
    BalanceRefreshStatus(data: BalanceRefreshData(
        urgencyColor: .red,
        statusMessage: "Critical",
        isExpired: true,
        expiredAgoString: "2h 15m",
        showActionButton: true,
        nextRoundStartTime: UInt64(Date().timeIntervalSince1970) + 300 // 5 minutes from now
    ))
    .padding()
}

#Preview("Refreshing") {
    BalanceRefreshStatus(data: BalanceRefreshData(
        hasActiveRefresh: true,
        urgencyColor: .blue,
        nextRoundStartTime: UInt64(Date().timeIntervalSince1970) + 300 // 5 minutes from now
    ))
    .padding()
}
