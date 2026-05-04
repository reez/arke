//
//  VTXORowView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import ArkeUI

struct VTXORowView: View {
    let vtxo: VTXOModel
    let isSelected: Bool
    let latestBlockHeight: Int?
    @Environment(WalletManager.self) private var walletManager
    
    private var blocksUntilExpiry: Int? {
        guard let latestBlockHeight = latestBlockHeight else { return nil }
        return vtxo.expiryHeight - latestBlockHeight
    }
    
    private var isExpired: Bool {
        guard let blocksUntilExpiry = blocksUntilExpiry else { return false }
        return blocksUntilExpiry <= 0
    }
    
    private var isNearExpiry: Bool {
        guard let blocksUntilExpiry = blocksUntilExpiry else { return false }
        // Check if expiry is within 24 hours based on block time (~10 minutes per block)
        let secondsPerBlock = 600 // 10 minutes
        let secondsUntilExpiry = blocksUntilExpiry * secondsPerBlock
        let hoursUntilExpiry = secondsUntilExpiry / 3600
        return blocksUntilExpiry > 0 && hoursUntilExpiry <= 24
    }
    
    private var expiryText: String {
        guard let blocksUntilExpiry = blocksUntilExpiry else {
            //print("🔍 VTXO Expiry: No blocksUntilExpiry - latestBlockHeight is nil")
            //print("   - expiryHeight: \(vtxo.expiryHeight)")
            return "Block \(vtxo.expiryHeight)"
        }
        
        // Use block time (~10 minutes per block) for expiry calculation
        let secondsPerBlock = 600 // 10 minutes
        let totalSeconds = abs(blocksUntilExpiry) * secondsPerBlock
        
        /*
        print("🔍 VTXO Expiry Calculation:")
        print("   - VTXO ID: \(vtxo.id)")
        print("   - expiryHeight: \(vtxo.expiryHeight)")
        print("   - latestBlockHeight: \(latestBlockHeight ?? -1)")
        print("   - blocksUntilExpiry: \(blocksUntilExpiry)")
        print("   - secondsPerBlock: \(secondsPerBlock)")
        print("   - totalSeconds: \(totalSeconds)")
        print("   - isExpired: \(isExpired)")
        print("   - formatted time: \(formatTimeInterval(totalSeconds))")
        */
        
        if isExpired {
            return "Expired \(formatTimeInterval(totalSeconds)) ago"
        } else if blocksUntilExpiry == 1 {
            return "Expires in ~\(formatTimeInterval(totalSeconds))"
        } else {
            return "Expires in ~\(formatTimeInterval(totalSeconds))"
        }
    }
    
    private func formatTimeInterval(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        
        // For very short durations, show "< 1m"
        if seconds < 60 {
            return "< 1m"
        }
        
        return formatter.string(from: TimeInterval(seconds)) ?? "< 1m"
    }
    
    private var expiryColor: Color {
        if isExpired {
            return .Arke.red
        } else if isNearExpiry {
            return .Arke.orange
        } else {
            return .secondary
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vtxo.formattedAmount)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                // VTXO State Badge
                HStack(spacing: 4) {
                    /*
                    Image(systemName: vtxo.state.iconName)
                        .font(.system(size: 10))
                        .foregroundColor(vtxo.state.iconColor)
                     */
                    
                    Text(vtxo.state.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(vtxo.state.textColor)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(expiryText)
                    .font(.body)
                    .foregroundStyle(expiryColor)
                    .lineLimit(1)
                
                Text(vtxo.shortTxid)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .cornerRadius(15)
    }
}

#Preview {
    VStack {
        // Show different VTXO states
        VTXORowView(
            vtxo: VTXOModel(
                id: "4f35af824858dd69802af664a2d1b03d2a49d60b7f66741ba3292de3b756d49a:0",
                amountSat: 1000,
                policyType: .pubkey,
                userPubkey: "0395fe00abc5cbb5b8949f70a0b9ff161ef4fed549323c598fee8d47c531b226d2",
                serverPubkey: "02f0f358c1b6173ddecec1ad06b42d3762f193e6ff98a3e112292aec21129f9f6b",
                expiryHeight: 274399,
                exitDelta: 12,
                chainAnchor: "e334ea46d851b90c173f4ce923f220a37baa4e0a52c5dfcb07f5c89902b79ef2:0",
                exitDepth: 1,
                arkoorDepth: 0,
                state: .spendable
            ),
            isSelected: false,
            latestBlockHeight: 274350 // 49 blocks until expiry
        )
        
        Divider()
            .padding(.horizontal, 12)
        
        VTXORowView(
            vtxo: VTXOModel(
                id: "abc123def456789012345678901234567890abcdef123456789012345678901234:1",
                amountSat: 25000,
                policyType: .pubkey,
                userPubkey: "03abc123def456789012345678901234567890abcdef123456789012345678901234",
                serverPubkey: "02def456abc123789012345678901234567890abcdef123456789012345678901234",
                expiryHeight: 274500,
                exitDelta: 10,
                chainAnchor: "def456abc123789012345678901234567890abcdef123456789012345678901234:0",
                exitDepth: 2,
                arkoorDepth: 1,
                state: .registeredBoard
            ),
            isSelected: true,
            latestBlockHeight: 274490 // 10 blocks until expiry (near expiry)
        )
        
        Divider()
            .padding(.horizontal, 12)
        
        VTXORowView(
            vtxo: VTXOModel(
                id: "def456abc123789012345678901234567890abcdef123456789012345678901234:2",
                amountSat: 5000,
                policyType: .pubkey,
                userPubkey: "02def456abc123789012345678901234567890abcdef123456789012345678901234",
                serverPubkey: "03abc123def456789012345678901234567890abcdef123456789012345678901234",
                expiryHeight: 274600,
                exitDelta: 8,
                chainAnchor: "abc123def456789012345678901234567890abcdef123456789012345678901234:1",
                exitDepth: 1,
                arkoorDepth: 2,
                state: .pending
            ),
            isSelected: false,
            latestBlockHeight: 274650 // Expired (-50 blocks)
        )
        
        Divider()
            .padding(.horizontal, 12)
        
        VTXORowView(
            vtxo: VTXOModel(
                id: "spent123def456789012345678901234567890abcdef123456789012345678901234:3",
                amountSat: 15000,
                policyType: .pubkey,
                userPubkey: "02spent123def456789012345678901234567890abcdef123456789012345678901234",
                serverPubkey: "03spent123def456789012345678901234567890abcdef123456789012345678901234",
                expiryHeight: 274700,
                exitDelta: 15,
                chainAnchor: "spent123def456789012345678901234567890abcdef123456789012345678901234:2",
                exitDepth: 3,
                arkoorDepth: 1,
                state: .spent
            ),
            isSelected: false,
            latestBlockHeight: 274500 // 200 blocks until expiry
        )
        
        Divider()
            .padding(.horizontal, 12)
        
        VTXORowView(
            vtxo: VTXOModel(
                id: "unreg123def456789012345678901234567890abcdef123456789012345678901234:4",
                amountSat: 8000,
                policyType: .pubkey,
                userPubkey: "02unreg123def456789012345678901234567890abcdef123456789012345678901234",
                serverPubkey: "03unreg123def456789012345678901234567890abcdef123456789012345678901234",
                expiryHeight: 274800,
                exitDelta: 20,
                chainAnchor: "unreg123def456789012345678901234567890abcdef123456789012345678901234:3",
                exitDepth: 2,
                arkoorDepth: 3,
                state: .unregisteredBoard
            ),
            isSelected: false,
            latestBlockHeight: nil // No block height available
        )
    }
    .padding()
}
