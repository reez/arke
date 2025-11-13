//
//  OffboardingModalView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/17/25.
//

import SwiftUI

private enum OffboardingModalState {
    case form
    case offboarding
    case success
    case error(String)
}

struct OffboardingModalView: View {
    let manager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var state: OffboardingModalState = .form
    @State private var isLoadingVTXOs: Bool = false
    @State private var vtxos: [VTXOModel] = []
    @State private var selectedVTXOs: Set<String> = []
    
    var body: some View {
        switch state {
        case .form:
            OffboardingModalFormView(
                vtxos: vtxos,
                selectedVTXOs: $selectedVTXOs,
                isLoading: isLoadingVTXOs,
                onConfirm: {
                    Task {
                        await performOffboarding()
                    }
                },
                onCancel: {
                    dismiss()
                }
            )
            .onAppear {
                if vtxos.isEmpty && !isLoadingVTXOs {
                    Task {
                        await loadVTXOs()
                    }
                }
            }
        case .offboarding:
            OffboardingModalOffboardingView()
        case .success:
            OffboardingModalSuccessView {
                dismiss()
            }
        case .error(let errorMessage):
            OffboardingModalErrorView(errorMessage: errorMessage) {
                state = .form
            }
        }
    }
    
    @MainActor
    private func loadVTXOs() async {
        // Prevent multiple simultaneous loads
        guard !isLoadingVTXOs else { return }
        
        isLoadingVTXOs = true
        
        do {
            let loadedVTXOs = try await manager.getVTXOs()
            vtxos = loadedVTXOs
            print("DEBUG: Loaded \(vtxos.count) VTXOs: \(vtxos)")
        } catch {
            state = .error("Failed to load coins: \(error.localizedDescription)")
            vtxos = []
            print("DEBUG: Failed to load VTXOs - vtxos array is now empty")
        }
        
        isLoadingVTXOs = false
    }
    
    @MainActor
    private func performOffboarding() async {
        guard !selectedVTXOs.isEmpty else { return }
        
        state = .offboarding
        
        do {
            // Exit each selected VTXO
            for vtxoId in selectedVTXOs {
                _ = try await manager.exitVTXO(vtxoId: vtxoId)
            }
            
            // Start the exit process
            _ = try await manager.startExit()
            
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
