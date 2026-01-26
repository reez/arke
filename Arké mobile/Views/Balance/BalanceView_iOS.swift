//
//  BalanceView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct BalanceView_iOS: View {
    @Environment(WalletManager.self) private var manager
    @State private var showingBoardingModal = false
    @State private var showingOffboardingModal = false
    @State private var showingRefreshModal = false
    
    private var canBoard: Bool {
        guard let onchainBalance = manager.onchainBalance else { return false }
        return onchainBalance.spendableSat > 0
    }
    
    private var canOffboard: Bool {
        guard let arkBalance = manager.arkBalance else { return false }
        return arkBalance.spendableSat > 0
    }
    
    var body: some View {
        ScrollView {
            // Detailed Breakdowns
            VStack(spacing: 20) {
                // Ark Balance
                if let arkBalance = manager.arkBalance {
                    BalanceDetailCard(
                        title: "Payments balance",
                        description: "Fast & low fees · Ark network",
                        spendable: arkBalance.spendableSat,
                        pending: arkBalance.totalPendingSat,
                        total: arkBalance.totalSat,
                        color: .blue,
                        imageName: "wallet"
                    )
                }
                
                // Board Button
                HStack {
                    Button(action: {
                        showingBoardingModal = true
                    }) {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(ArkeIconButtonStyle())
                    .disabled(!canBoard)
                    .help(canBoard ? "Move funds to payments" : "No funds available in savings to move to payments")
                    
                    Button(action: {
                        showingOffboardingModal = true
                    }) {
                        Image(systemName: "arrow.down")
                    }
                    .buttonStyle(ArkeIconButtonStyle())
                    .disabled(!canOffboard)
                    .help(canOffboard ? "Move funds to savings" : "No funds available in payments to move to savings")
                }
                .frame(maxWidth: 100)
                
                // Onchain Balance
                if let onchainBalance = manager.onchainBalance {
                    BalanceDetailCard(
                        title: "Savings balance",
                        description: "Best security · Bitcoin network",
                        spendable: onchainBalance.spendableSat,
                        pending: onchainBalance.pendingSat,
                        total: onchainBalance.totalSat,
                        color: .orange,
                        imageName: "safe"
                    )
                }
                
                Divider()
                    .padding(.top, 15)
                
                BalanceRefreshStatus(onRefresh: {
                    showingRefreshModal = true
                })
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 15)
            }
            .padding(.horizontal)
            .padding(.top, 20)
        }
        .refreshable {
            await manager.refresh()
        }
        .sheet(isPresented: $showingBoardingModal) {
            BoardingModalView(manager: manager)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingOffboardingModal) {
            OffboardingModalView(manager: manager)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingRefreshModal) {
            RefreshModalView(manager: manager) {
                Task {
                    await manager.refresh()
                }
            }
            .presentationDetents([.large])
        }
        .task {
            do {
                try await manager.sync()
                _ = try await manager.getArkBalance()
            } catch {
                print("Failed to sync or get balance: \(error)")
            }
        }
    }
}
