//
//  ArkInfoSectionView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/20/25.
//

import SwiftUI
import ArkeUI

struct ArkInfoSectionView: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var arkInfoData: ArkInfoModel?
    @State private var isLoadingArkInfo = false
    @State private var error: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("data_ark_info")
                    .font(.system(size: 24, design: .serif))
                
                Spacer()
                
                Button {
                    Task {
                        await loadArkInfoData()
                    }
                } label: {
                    if isLoadingArkInfo {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLoadingArkInfo)
            }
            
            if isLoadingArkInfo {
                SkeletonLoader(
                    itemCount: 1,
                    itemHeight: 100,
                    spacing: 15,
                    cornerRadius: 15
                )
            } else if arkInfoData == nil && !isLoadingArkInfo {
                VStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("data_no_ark_info")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else if let arkInfoData = arkInfoData {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network: \(arkInfoData.network.uppercased())")
                    Text("Server: \(arkInfoData.serverPubkeyShort)")
                    Text("Round Interval: \(arkInfoData.roundInterval)")
                    Text("Round Nonces: \(arkInfoData.nbRoundNonces)")
                    if let maxVtxoAmountBTC = arkInfoData.maxVtxoAmountBTC {
                        Text("Max VTXO Amount: \(maxVtxoAmountBTC.formatted(.number.precision(.fractionLength(8)))) BTC")
                    } else {
                        Text("data_max_vtxo_not_set")
                    }
                    Text("Min Board Amount: \(arkInfoData.minBoardAmountBTC.formatted(.number.precision(.fractionLength(8)))) BTC")
                    Text("VTXO Exit Delta: \(arkInfoData.vtxoExitDelta) blocks")
                    Text("VTXO Expiry Delta: \(arkInfoData.vtxoExpiryDelta) blocks")
                    Text("HTLC Send Expiry Delta: \(arkInfoData.htlcSendExpiryDelta) blocks")
                    Text("HTLC Expiry Delta: \(arkInfoData.htlcExpiryDelta) blocks")
                    Text("Max User Invoice CLTV Delta: \(arkInfoData.maxUserInvoiceCltvDelta) blocks")
                    Text("Board Confirmations: \(arkInfoData.requiredBoardConfirmations)")
                    Text("Offboard Feerate: \(arkInfoData.offboardFeerate) sat/vB")
                    Text("LN Receive Anti-DoS: \(arkInfoData.lnReceiveAntiDosRequired ? "Required" : "Not Required")")
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let error = error {
                ErrorView(errorMessage: error)
            }
        }
        .padding(.horizontal, 30)
        .task {
            await loadArkInfoData()
        }
    }
    
    private func loadArkInfoData() async {
        isLoadingArkInfo = true
        error = nil
        
        print("loadArkInfoData")
        
        do {
            arkInfoData = try await walletManager.getArkInfo()
            print("arkInfoData: \(String(describing: arkInfoData))")
        } catch {
            self.error = error.localizedDescription
            arkInfoData = nil
        }
        
        isLoadingArkInfo = false
    }
}

#Preview {
    NavigationStack {
        ArkInfoSectionView()
            .environment(WalletManager(useMock: true))
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
            .frame(width: 350, height: 350)
    }
}
