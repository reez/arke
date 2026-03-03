//
//  AddressDisplayView.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/21/25.
//

import SwiftUI

struct AddressDisplayView: View {
    @Environment(WalletManager.self) private var manager
    let selectedBalance: ReceiveBalanceType
    let amount: String
    let note: String
    
    var body: some View {
        VStack(spacing: 20) {
            addressContentView
                .id(selectedBalance)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9).combined(with: .offset(y: 50))),
                    removal: .opacity.combined(with: .scale(scale: 1.1))
                ))
        }
    }
    
    @ViewBuilder
    private var addressContentView: some View {
        switch selectedBalance {
        case .payments:
            paymentsAddressView
        case .savings:
            savingsAddressView
        case .paymentsAndSavings:
            combinedAddressesView
        case .lightning:
            lightningPlaceholderView
        }
    }
    
    @ViewBuilder
    private var paymentsAddressView: some View {
        if !manager.arkAddress.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                AddressCardExpandable(
                    address: manager.arkAddress,
                    shareContent: BIP21URIHelper.createBIP21URI(
                        arkAddress: manager.arkAddress,
                        amount: amount.isEmpty ? nil : amount,
                        label: nil,
                        message: note.isEmpty ? nil : note
                    ),
                    label: "Payments Address"
                )
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 20)
        } else {
            ProgressView()
                .scaleEffect(0.75)
                .padding()
        }
    }
    
    @ViewBuilder
    private var savingsAddressView: some View {
        if !manager.onchainAddress.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                AddressCardExpandable(
                    address: manager.onchainAddress,
                    shareContent: BIP21URIHelper.createBIP21URI(
                        onchainAddress: manager.onchainAddress,
                        amount: amount.isEmpty ? nil : amount,
                        label: nil,
                        message: note.isEmpty ? nil : note
                    ),
                    label: "Savings Address"
                )
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 20)
        } else {
            ProgressView("progress_loading_address")
        }
    }
    
    @ViewBuilder
    private var combinedAddressesView: some View {
        VStack(spacing: 20) {
            if !manager.arkAddress.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    AddressCardExpandable(
                        address: manager.arkAddress,
                        shareContent: BIP21URIHelper.createBIP21URI(
                            arkAddress: manager.arkAddress,
                            amount: amount.isEmpty ? nil : amount,
                            label: nil,
                            message: note.isEmpty ? nil : note
                        ),
                        label: "Payments Address"
                    )
                }
            } else {
                ProgressView(String(localized: "status_loading_address"))
            }
            
            Divider()
            
            if !manager.onchainAddress.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    AddressCardExpandable(
                        address: manager.onchainAddress,
                        shareContent: BIP21URIHelper.createBIP21URI(
                            onchainAddress: manager.onchainAddress,
                            amount: amount.isEmpty ? nil : amount,
                            label: nil,
                            message: note.isEmpty ? nil : note
                        ),
                        label: "Savings Address (fallback)"
                    )
                }
            } else {
                ProgressView(String(localized: "status_loading_address"))
            }
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 20)
    }
    
    @ViewBuilder
    private var lightningPlaceholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.circle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text("label_lightning_network")
                .font(.headline)
            
            Text(String(localized: "message_lightning_coming_soon"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 20)
    }
}

#Preview {
    @Previewable @State var mockManager = WalletManager(useMock: true)
    
    AddressDisplayView(
        selectedBalance: .payments,
        amount: "0.001",
        note: "Test payment"
    )
    .environment(mockManager)
    .frame(width: 500, height: 300)
    .task {
        // Initialize the mock manager and load addresses
        await mockManager.initialize()
    }
}
