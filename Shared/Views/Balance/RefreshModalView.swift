//
//  RefreshModalView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/24/25.
//

import SwiftUI
import Bark

private enum RefreshModalState: Hashable {
    case form
    case success
    case error(String)
}

struct RefreshModalView: View {
    let manager: WalletManager
    var onRefreshComplete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var state: RefreshModalState = .form
    @State private var isLoading = false
    @State private var shouldDismiss = false
    @State private var amountToRefresh: Int?
    @State private var vtxoIdsToRefresh: [String] = []
    
    var body: some View {
        ZStack {
            switch state {
            case .form:
                RefreshModalFormView(
                    isLoading: isLoading,
                    amountToRefresh: amountToRefresh,
                    vtxoIdsToRefresh: vtxoIdsToRefresh,
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
        .task {
            await calculateAmountToRefresh()
        }
    }
    
    @MainActor
    private func calculateAmountToRefresh() async {
        do {
            let allVTXOs = try await manager.getVTXOs()
            
            guard let blockHeight = await manager.getEstimatedBlockHeight(),
                  let vtxoLifespan = manager.arkInfo?.vtxoExpiryDelta else {
                return
            }
            
            let vtxosToRefresh = RefreshUrgency.vtxosNeedingRefresh(
                from: allVTXOs,
                currentBlockHeight: blockHeight,
                vtxoLifespan: vtxoLifespan
            )
            
            amountToRefresh = vtxosToRefresh.reduce(0) { $0 + $1.amountSat }
            vtxoIdsToRefresh = vtxosToRefresh.map { $0.id }
        } catch {
            print("Failed to calculate amount to refresh: \(error)")
        }
    }
    
    @MainActor
    private func performRefresh() async {
        let startTime = Date()
        print("🔄 [RefreshModal] Starting refresh at \(startTime)")
        
        isLoading = true
        
        do {
            // Get all VTXOs
            let allVTXOs = try await manager.getVTXOs()
            
            // Filter to only VTXOs that need refreshing based on urgency
            guard let blockHeight = await manager.getEstimatedBlockHeight(),
                  let vtxoLifespan = manager.arkInfo?.vtxoExpiryDelta else {
                throw NSError(domain: "RefreshModal", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to determine block height or VTXO lifespan"
                ])
            }
            
            let vtxosToRefresh = RefreshUrgency.vtxosNeedingRefresh(
                from: allVTXOs,
                currentBlockHeight: blockHeight,
                vtxoLifespan: vtxoLifespan
            )
            
            let vtxoIds = vtxosToRefresh.map { $0.id }
            print("🔄 [RefreshModal] Found \(vtxoIds.count) VTXOs (out of \(allVTXOs.count) total) that need refreshing")
            
            // Refresh VTXOs using delegated mode (non-blocking)
            let roundState = try manager.refreshVtxosDelegated(vtxoIds: vtxoIds)
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            if let roundState = roundState {
                // Refresh was scheduled
                let ongoingText = roundState.ongoing ? " (ongoing)" : ""
                print("✅ [RefreshModal] Refresh completed in \(String(format: "%.2f", duration))s, scheduled in round #\(roundState.id)\(ongoingText)")
            } else {
                // No refresh was needed
                print("✅ [RefreshModal] Refresh completed in \(String(format: "%.2f", duration))s, VTXOs are already fresh")
            }
            
            isLoading = false
            state = .success
        } catch {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            print("❌ [RefreshModal] Refresh failed after \(String(format: "%.2f", duration))s: \(error.localizedDescription)")
            isLoading = false
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
