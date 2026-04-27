//
//  ConnectionInfoSheet_iOS.swift
//  Arké
//
//  Created by Claude on 4/13/26.
//

import SwiftUI

struct ConnectionInfoSheet_iOS_Delete: View {
    @Environment(\.dismiss) private var dismiss
    
    let networkName: String
    let connectionStatus: ConnectionStatus
    
    private var hasArkConnection: Bool {
        connectionStatus.isConnected
    }
    
    private var hasGoodConnection: Bool {
        connectionStatus.quality == .excellent || connectionStatus.quality == .good
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Connection Status")
                        .font(.system(size: 30, design: .serif))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Ark Server Connection Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: hasArkConnection ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                .font(.system(size: 40))
                                .foregroundColor(hasArkConnection ? .green : .red)
                            
                            Text("Ark Server")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text(connectionStatus.statusMessage)
                            .font(.body)
                            .foregroundColor(hasArkConnection ? .secondary : .red)
                        
                        if let detailedMessage = connectionStatus.detailedMessage {
                            Text(detailedMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ConnectionInfoRow_Delete(
                                icon: hasArkConnection ? "checkmark.circle.fill" : "xmark.circle.fill",
                                iconColor: hasArkConnection ? .green : .red,
                                text: hasArkConnection ? "Connected to Ark server" : "No connection to Ark server"
                            )
                            
                            if hasArkConnection {
                                ConnectionInfoRow_Delete(
                                    icon: connectionQualityIcon,
                                    iconColor: connectionQualityColor,
                                    text: "Connection quality: \(connectionQualityText)"
                                )
                            }
                            
                            if connectionStatus.reconnectionAttempts > 0 {
                                ConnectionInfoRow_Delete(
                                    icon: "arrow.clockwise",
                                    iconColor: .orange,
                                    text: "Reconnection attempts: \(connectionStatus.reconnectionAttempts)"
                                )
                            }
                            
                            if let lastError = connectionStatus.lastError {
                                ConnectionInfoRow_Delete(
                                    icon: "exclamationmark.triangle.fill",
                                    iconColor: .red,
                                    text: lastError
                                )
                            }
                        }
                    }
                    
                    if !hasArkConnection || !hasGoodConnection {
                        Divider()
                        
                        // Troubleshooting Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                                
                                Text("Troubleshooting")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            
                            Text("If you're experiencing connection issues, try:")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ConnectionInfoRow_Delete(icon: "wifi", iconColor: .orange, text: "Check your internet connection")
                                ConnectionInfoRow_Delete(icon: "arrow.clockwise", iconColor: .orange, text: "Pull down to refresh")
                                ConnectionInfoRow_Delete(icon: "arrow.down.app", iconColor: .orange, text: "Restart the app")
                            }
                        }
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var connectionQualityIcon: String {
        switch connectionStatus.quality {
        case .excellent:
            return "wifi"
        case .good:
            return "wifi"
        case .poor:
            return "wifi.exclamationmark"
        case .disconnected:
            return "wifi.slash"
        }
    }
    
    private var connectionQualityColor: Color {
        switch connectionStatus.quality {
        case .excellent:
            return .green
        case .good:
            return .green
        case .poor:
            return .orange
        case .disconnected:
            return .red
        }
    }
    
    private var connectionQualityText: String {
        connectionStatus.quality.displayName
    }
}

struct ConnectionInfoRow_Delete: View {
    let icon: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
        }
    }
}

#Preview("Connected on Signet") {
    ConnectionInfoSheet_iOS_Delete(
        networkName: "Bitcoin Signet",
        connectionStatus: ConnectionStatus(
            isConnected: true,
            quality: .excellent,
            lastSuccessfulSync: Date().addingTimeInterval(-30),
            reconnectionAttempts: 0,
            lastError: nil
        )
    )
}
#Preview("Poor Connection") {
    ConnectionInfoSheet_iOS_Delete(
        networkName: "Bitcoin Mainnet",
        connectionStatus: ConnectionStatus(
            isConnected: true,
            quality: .poor,
            lastSuccessfulSync: Date().addingTimeInterval(-600),
            reconnectionAttempts: 2,
            lastError: nil
        )
    )
}

#Preview("Disconnected") {
    ConnectionInfoSheet_iOS_Delete(
        networkName: "Bitcoin Signet",
        connectionStatus: ConnectionStatus(
            isConnected: false,
            quality: .disconnected,
            lastSuccessfulSync: Date().addingTimeInterval(-3600),
            reconnectionAttempts: 5,
            lastError: "Failed to connect to server"
        )
    )
}

