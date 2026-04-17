//
//  VTXOAutoRefreshSettingView.swift
//  Arké
//
//  Created by Assistant on 4/17/26.
//

import SwiftUI
import ArkeUI

struct VTXOAutoRefreshSettingView: View {
    @Environment(WalletManager.self) private var walletManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("VTXO Auto-Refresh")
                    .font(.system(size: 24, design: .serif))
                
                Text("Automatically refresh VTXOs when fees are free")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Toggle
            Toggle(isOn: Binding(
                get: { walletManager.isVTXOAutoRefreshEnabled },
                set: { walletManager.isVTXOAutoRefreshEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Auto-Refresh")
                        .font(.system(size: 15, weight: .medium))
                    
                    Text("The wallet will automatically refresh VTXOs when they enter the free refresh window, extending their lifespan at no cost.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            
            // Status Info
            if walletManager.isVTXORefreshServiceRunning {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(walletManager.isVTXOAutoRefreshEnabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(walletManager.isVTXOAutoRefreshEnabled ? "Service Active" : "Service Paused")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    if walletManager.vtxoAutoRefreshCount > 0 {
                        Text("Refreshed \(walletManager.vtxoAutoRefreshCount) VTXO\(walletManager.vtxoAutoRefreshCount == 1 ? "" : "s") this session")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
            
            // Help Text
            VStack(alignment: .leading, spacing: 8) {
                Text("How It Works")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                VStack(alignment: .leading, spacing: 6) {
                    helpRow(
                        icon: "clock.fill",
                        text: "Checks for VTXOs in the free refresh window every hour"
                    )
                    
                    helpRow(
                        icon: "dollarsign.circle.fill",
                        text: "Only refreshes when fees are completely free (0 sats)"
                    )
                    
                    helpRow(
                        icon: "arrow.triangle.2.circlepath",
                        text: "Extends VTXO lifespan automatically to prevent expiration"
                    )
                    
                    helpRow(
                        icon: "lock.fill",
                        text: "Only runs while the app is open in the foreground"
                    )
                }
                .padding(12)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    private func helpRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    VTXOAutoRefreshSettingView()
        .environment(WalletManager(useMock: true))
        .padding()
}
