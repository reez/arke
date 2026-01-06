//
//  OffboardingModalView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/17/25.
//

import SwiftUI

private enum OffboardingModalState: Hashable {
    case form
    case offboarding
    case success
    case error(String)
}

struct OffboardingModalView: View {
    let manager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var state: OffboardingModalState = .form
    
    var body: some View {
        ZStack {
            switch state {
            case .form:
                OffboardingModalFormView(
                    onchainAddress: manager.onchainAddress,
                    maximumAmount: manager.arkBalance?.spendableSat,
                    onConfirm: { amount in
                        Task {
                            await performOffboarding(amount: amount)
                        }
                    },
                    onCancel: {
                        dismiss()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case .offboarding:
                OffboardingModalOffboardingView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case .success:
                OffboardingModalSuccessView {
                    dismiss()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case .error(let errorMessage):
                OffboardingModalErrorView(errorMessage: errorMessage) {
                    state = .form
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    @MainActor
    private func performOffboarding(amount: Int) async {
        state = .offboarding
        
        do {
            let onchainAddress = manager.onchainAddress
            
            guard !onchainAddress.isEmpty else {
                state = .error("Unable to retrieve onchain address. Please try again.")
                return
            }
            
            // Send onchain to the user's own address
            _ = try await manager.sendToOnchain(to: onchainAddress, amount: amount)
            
            state = .success
        } catch {
            state = .error("Failed to transfer coins: \(error.localizedDescription)")
        }
    }
}


#Preview("Form") {
    OffboardingModalView(manager: WalletManager(useMock: true))
}

#Preview("Offboarding") {
    OffboardingModalOffboardingView()
}

#Preview("Success") {
    OffboardingModalSuccessView {
        print("Continue tapped")
    }
}

#Preview("Error") {
    OffboardingModalErrorView(errorMessage: "Network connection failed. Please check your internet connection and try again.") {
        print("Retry tapped")
    }
}
