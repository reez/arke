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
    var onRefreshComplete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var state: RefreshModalState = .form
    @State private var shouldDismiss = false
    
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
                    print("DEBUG: RefreshModalSuccessView onDone called")
                    onRefreshComplete?()
                    print("DEBUG: About to call dismiss")
                    shouldDismiss = true
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
        .onChange(of: shouldDismiss) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }
    
    @MainActor
    private func performRefresh() async {
        let startTime = Date()
        print("🔄 [RefreshModal] Starting refresh at \(startTime)")
        
        state = .refreshing
        
        // Give SwiftUI time to render the refreshing state
        try? await Task.sleep(for: .milliseconds(300))
        
        do {
            // Get all VTXOs and extract their IDs
            let vtxos = try await manager.getVTXOs()
            let vtxoIds = vtxos.map { $0.id }
            print("🔄 [RefreshModal] Found \(vtxoIds.count) VTXOs to refresh")
            
            // Refresh all VTXOs
            let nextRefreshHeight = try await manager.refreshVTXOs(vtxo_ids: vtxoIds)
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            print("✅ [RefreshModal] Refresh completed in \(String(format: "%.2f", duration))s, next refresh at block height: \(nextRefreshHeight)")
            
            state = .success
        } catch {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            print("❌ [RefreshModal] Refresh failed after \(String(format: "%.2f", duration))s: \(error.localizedDescription)")
            state = .error("Failed to schedule maintenance refresh: \(error.localizedDescription)")
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
