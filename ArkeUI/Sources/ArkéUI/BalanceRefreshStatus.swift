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
        self.onRefresh = onRefresh
    }
}

public struct BalanceRefreshStatus: View {
    let data: BalanceRefreshData
    
    public init(data: BalanceRefreshData) {
        self.data = data
    }
    
    public var body: some View {
        Group {
            if data.isLoading {
                loadingView
            } else {
                contentView
            }
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
        Text("Refreshing...")
            .font(.title3)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("Status").font(.callout).foregroundStyle(.secondary)
            Text(data.statusMessage).font(.title3).fontWeight(.bold)
            if let ago = data.expiredAgoString {
                Text("Expired \(ago) ago").font(.body).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var timesContent: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status").font(.callout).foregroundStyle(.secondary)
                Text(data.statusMessage).font(.title3).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if let expiry = data.timeUntilExpiry {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time until expiry").font(.callout).foregroundStyle(.secondary)
                    Text(expiry).font(.title3).fontWeight(.bold)
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
        showActionButton: false
    ))
    .padding()
}

#Preview("Warning") {
    BalanceRefreshStatus(data: BalanceRefreshData(
        urgencyColor: .yellow,
        statusMessage: "Recommended",
        timeUntilExpiry: "2d 3h",
        showActionButton: true
    ))
    .padding()
}

#Preview("Critical") {
    BalanceRefreshStatus(data: BalanceRefreshData(
        urgencyColor: .red,
        statusMessage: "Urgent",
        timeUntilExpiry: "12h 4m",
        showActionButton: true
    ))
    .padding()
}

#Preview("Expired") {
    BalanceRefreshStatus(data: BalanceRefreshData(
        urgencyColor: .red,
        statusMessage: "Critical",
        isExpired: true,
        expiredAgoString: "2h 15m",
        showActionButton: true
    ))
    .padding()
}

#Preview("Refreshing") {
    BalanceRefreshStatus(data: BalanceRefreshData(
        hasActiveRefresh: true,
        urgencyColor: .blue
    ))
    .padding()
}
