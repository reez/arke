//
//  SendModalView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/20/25.
//

import SwiftUI

struct SendModalView: View {
    let state: SendModalState
    let onClearModalState: () -> Void
    let onDismissEntireView: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        switch state {
        case .sending:
            SendModalSendingView()
        case .success:
            SendModalSuccessView {
                print("✅ [SendModalView] Success - clearing modal state and dismissing")
                onClearModalState()
                dismiss()
                // After successful payment, dismiss the entire SendView
                onDismissEntireView?()
            }
        case .error(let errorMessage):
            SendModalErrorView(errorMessage: errorMessage) {
                print("✅ [SendModalView] Error - clearing modal state")
                onClearModalState()
                dismiss()
                // Don't dismiss entire view on error - user might want to retry
            }
        }
    }
}

#Preview("Success") {
    SendModalView(state: .success, onClearModalState: {
        print("Preview: onClearModalState called")
    }, onDismissEntireView: {
        print("Preview: onDismissEntireView called")
    })
}
