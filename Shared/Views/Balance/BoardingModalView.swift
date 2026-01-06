//
//  BoardingModalView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/17/25.
//

import SwiftUI

private enum BoardingModalState: Hashable {
    case form
    case boarding
    case success
    case error(String)
}

struct BoardingModalView: View {
    let manager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var state: BoardingModalState = .success
    
    var body: some View {
        ZStack {
            switch state {
            case .form:
                BoardingModalFormView(
                    minimumAmount: manager.arkInfo?.minBoardAmount,
                    onConfirm: { amount in
                        Task {
                            await performBoarding(amount: amount)
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
            case .boarding:
                BoardingModalBoardingView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case .success:
                BoardingModalSuccessView {
                    dismiss()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case .error(let errorMessage):
                BoardingModalErrorView(errorMessage: errorMessage) {
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
    private func performBoarding(amount: Int) async {
        state = .boarding
        
        do {
            try await manager.board(amount: amount)
            state = .success
        } catch {
            state = .error("Failed to board sats: \(error.localizedDescription)")
        }
    }
}

#Preview("Form") {
    BoardingModalView(manager: WalletManager(useMock: true))
}

#Preview("Boarding") {
    BoardingModalBoardingView()
}

#Preview("Success") {
    BoardingModalSuccessView {
        print("Done tapped")
    }
}

#Preview("Error") {
    BoardingModalErrorView(errorMessage: "Network connection failed. Please check your internet connection and try again.") {
        print("Retry tapped")
    }
}
