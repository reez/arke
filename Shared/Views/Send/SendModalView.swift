//
//  SendModalView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/20/25.
//

import SwiftUI
import ArkeUI

struct SendModalView: View {
    let onDismissEntireView: (() -> Void)?
    let performSend: () async throws -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var state: SendModalState = .sending
    @State private var sendStartTime: Date?
    
    private let minimumSendingDuration: TimeInterval = 0.8 // 800ms minimum
    
    var body: some View {
        ZStack {
            switch state {
            case .sending:
                SendModalSendingView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case .success:
                SendModalSuccessView {
                    print("✅ [SendModalView] Success - dismissing")
                    dismiss()
                    // After successful payment, dismiss the entire SendView
                    onDismissEntireView?()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case .error(let errorMessage):
                LargeErrorView(
                    title: "error_payment_failed",
                    errorMessage: errorMessage,
                    image: nil,
                    systemImage: "xmark.circle.fill",
                    systemImageColor: Color.Arke.blue,
                    onDismiss: {
                        print("✅ [SendModalView] Error - dismissing")
                        dismiss()
                        // Don't dismiss entire view on error - user might want to retry
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state)
        .frame(maxHeight: .infinity, alignment: .top)
        .task {
            await executeSend()
        }
    }
    
    @MainActor
    private func executeSend() async {
        sendStartTime = Date()
        
        do {
            try await performSend()
            
            // Ensure minimum display time for "sending" state
            await enforceMinimumSendingDuration()
            
            state = .success
        } catch {
            // Ensure minimum display time for "sending" state
            await enforceMinimumSendingDuration()
            
            state = .error(error.localizedDescription)
        }
    }
    
    @MainActor
    private func enforceMinimumSendingDuration() async {
        guard let startTime = sendStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = minimumSendingDuration - elapsed
        
        if remaining > 0 {
            try? await Task.sleep(for: .milliseconds(Int(remaining * 1000)))
        }
    }
}

#Preview("Success Flow") {
    SendModalView(
        onDismissEntireView: {
            print("Preview: onDismissEntireView called")
        },
        performSend: {
            // Simulate instant success
            print("Preview: Sending...")
        }
    )
}
#Preview("Error Flow") {
    SendModalView(
        onDismissEntireView: {
            print("Preview: onDismissEntireView called")
        },
        performSend: {
            // Simulate error
            throw NSError(domain: "PreviewError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network connection failed"])
        }
    )
}

