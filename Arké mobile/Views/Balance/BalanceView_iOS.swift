//
//  BalanceView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
import ArkeUI

struct BalanceView_iOS: View {
    @Environment(WalletManager.self) private var manager
    @State private var showingBoardingModal = false
    @State private var showingOffboardingModal = false
    @State private var showingRefreshModal = false
    @State private var showingBalanceInfo = false
    @State private var refreshStatusReloadTrigger = 0
    
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
                        title: "Payments\nBalance",
                        description: "Fast, low-fee payments.\nMaintenance fees.",
                        spendable: arkBalance.spendableSat,
                        pending: arkBalance.totalPendingSat,
                        total: arkBalance.totalSat,
                        color: .Arke.blue,
                        imageName: "wallet",
                        pendingItems: [
                            (label: "Pending Lightning send", amount: arkBalance.pendingLightningSendSat),
                            (label: "Pending in round", amount: arkBalance.pendingInRoundSat),
                            (label: "Pending board", amount: arkBalance.pendingBoardSat),
                            (label: "Pending exit", amount: arkBalance.pendingExitSat)
                        ]
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
                        title: "Savings\nBalance",
                        description: "Slow, high-fee payments.\nNo maintenance fees.",
                        spendable: onchainBalance.spendableSat,
                        pending: onchainBalance.pendingSat,
                        total: onchainBalance.totalSat,
                        color: .orange,
                        imageName: "safe",
                        pendingItems: nil
                    )
                }
                
                BalanceRefreshStatusContainer(
                    onRefresh: {
                        showingRefreshModal = true
                    },
                    reloadTrigger: refreshStatusReloadTrigger
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 15)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 20)
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
        .onChange(of: showingRefreshModal) { _, isShowing in
            if !isShowing {
                // Sheet was dismissed, reload status
                refreshStatusReloadTrigger += 1
            }
        }
        .sheet(isPresented: $showingBalanceInfo) {
            BalanceInfoSheet()
                .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingBalanceInfo = true
                }) {
                    Image(systemName: "info.circle")
                }
            }
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
