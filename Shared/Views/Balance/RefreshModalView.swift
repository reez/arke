//
//  RefreshModalView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/24/25.
//

import SwiftUI

private enum RefreshModalState {
    case form
    case refreshing
    case success
    case error(String)
}

struct RefreshModalView: View {
    let manager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var state: RefreshModalState = .form
    
    var body: some View {
        NavigationStack {
            switch state {
            case .form:
                RefreshModalFormView(
                    onConfirm: {
                        Task {
                            await performRefresh()
                        }
                    },
                    onCancel: {
                        dismiss()
                    }
                )
            case .refreshing:
                RefreshModalRefreshingView(onCancel: {
                    dismiss()
                })
            case .success:
                RefreshModalSuccessView {
                    dismiss()
                }
            case .error(let errorMessage):
                RefreshModalErrorView(errorMessage: errorMessage) {
                    state = .form
                }
            }
        }
    }
    
    @MainActor
    private func performRefresh() async {
        state = .refreshing
        
        do {
            // Refresh all VTXOs
            _ = try await manager.refreshVTXOs()
            
            state = .success
        } catch {
            state = .error("Failed to refresh VTXOs: \(error.localizedDescription)")
        }
    }
}

#Preview("Form") {
    RefreshModalView(manager: WalletManager(useMock: true))
}

#Preview("Refreshing") {
    RefreshModalRefreshingView()
}

#Preview("Success") {
    RefreshModalSuccessView {
        print("Done tapped")
    }
}

#Preview("Error") {
    RefreshModalErrorView(errorMessage: "Network connection failed. Please check your internet connection and try again.") {
        print("Retry tapped")
    }
}
