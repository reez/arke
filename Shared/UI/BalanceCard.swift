//
//  BalanceCard.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/17/25.
//

import SwiftUI
import Combine

struct BalanceCard: View {
    @Environment(WalletManager.self) private var walletManager
    
    let totalBalance: TotalBalanceModel?
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Your Balance")
                    #if os(iOS)
                    .font(.system(size: 24, weight: .semibold))
                    #else
                    .font(.system(size: 17, weight: .semibold))
                    #endif
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                    .opacity(isAnimating ? 0.7 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                    .onChange(of: walletManager.isRefreshing) { oldValue, newValue in
                        if newValue {
                            isAnimating = true
                        } else {
                            isAnimating = false
                        }
                    }
                
                Spacer()
                
                if let totalBalance = totalBalance {
                    BalanceRefreshTag()
                    
                    Text(BitcoinFormatter.shared.formatAmount(totalBalance.grandTotalSat))
                        #if os(iOS)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        #else
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        #endif
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                        .contentTransition(.numericText())
                        .animation(.smooth, value: totalBalance.grandTotalSat)
                } else {
                    // Empty space to maintain card height
                    Spacer()
                        .frame(height: 40) // Approximate height to match the text + tag
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .aspectRatio(3/2, contentMode: .fit)
        .background {
            RoundedRectangle(cornerRadius: 15)
                .overlay {
                    Image("card")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .clipped()
        }
        .cornerRadius(15)
    }
}

#Preview {
    @Previewable @State var balance = TotalBalanceModel.empty
    
    VStack(spacing: 20) {
        BalanceCard(totalBalance: balance)
            .frame(width: 250, height: 160)
        
        Button("Animate Balance") {
            let randomAmount = Int.random(in: 10000...9999999)
            balance = TotalBalanceModel(
                arkBalance: ArkBalanceModel(
                    spendableSat: randomAmount,
                    pendingLightningSendSat: 0,
                    pendingInRoundSat: 0,
                    pendingExitSat: 0,
                    pendingBoardSat: 0
                ),
                onchainBalance: OnchainBalanceModel(
                    totalSat: 0,
                    trustedSpendableSat: 0,
                    immatureSat: 0,
                    trustedPendingSat: 0,
                    untrustedPendingSat: 0,
                    confirmedSat: 0
                )
            )
        }
        .buttonStyle(.borderedProminent)
    }
    .environment(WalletManager(useMock: true))
    .padding(20)
}
