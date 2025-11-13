//
//  BoardingModalView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/17/25.
//

import SwiftUI

private enum BoardingModalState {
    case form
    case boarding
    case success
    case error(String)
}

struct BoardingModalView: View {
    let manager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var state: BoardingModalState = .form
    
    var body: some View {
        switch state {
        case .form:
            BoardingModalFormView(
                onConfirm: { amount in
                    Task {
                        await performBoarding(amount: amount)
                    }
                },
                onCancel: {
                    dismiss()
                }
            )
        case .boarding:
            BoardingModalBoardingView()
        case .success:
            BoardingModalSuccessView {
                dismiss()
            }
        case .error(let errorMessage):
            BoardingModalErrorView(errorMessage: errorMessage) {
                state = .form
            }
        }
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
