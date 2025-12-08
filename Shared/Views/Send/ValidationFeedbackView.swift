//
//  ValidationFeedbackView.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/19/25.
//

import SwiftUI
import Combine

struct ValidationFeedbackView: View {
    let state: RecipientState
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            case .typing:
                TypingIndicatorView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            case .valid:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Valid address")
                        .font(.body)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            case .invalid(let error):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.75), value: state)
    }
}

#Preview("Idle") {
    ValidationFeedbackView(state: .idle)
        .padding()
}

#Preview("Typing") {
    ValidationFeedbackView(state: .typing)
        .padding()
}

#Preview("Valid") {
    ValidationFeedbackView(state: .valid)
        .padding()
}

#Preview("Invalid") {
    ValidationFeedbackView(state: .invalid("Invalid address format"))
        .padding()
}
