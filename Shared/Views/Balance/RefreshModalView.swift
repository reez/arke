//
//  RefreshModalView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/24/25.
//

import SwiftUI

private enum RefreshModalState: Hashable {
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
        ZStack {
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
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case .refreshing:
                RefreshModalRefreshingView(onCancel: {
                    dismiss()
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case .success:
                RefreshModalSuccessView {
                    dismiss()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case .error(let errorMessage):
                RefreshModalErrorView(errorMessage: errorMessage) {
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
    private func performRefresh() async {
        state = .refreshing
        
        // Give SwiftUI time to render the refreshing state
        try? await Task.sleep(for: .milliseconds(300))
        
        do {
            // Refresh all VTXOs
            _ = try await manager.refreshVTXOs()
            //try? await Task.sleep(for: .milliseconds(5000))
            
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
