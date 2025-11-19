//
//  ValidationFeedbackView.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/19/25.
//

import SwiftUI
import Combine

struct TypingIndicatorView: View {
    @State private var animationPhase: Int = 0
    
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray.opacity(opacity(for: index)))
                    .frame(width: 8, height: 8)
            }
        }
        .onReceive(timer) { _ in
            animationPhase = (animationPhase + 1) % 3
        }
        .animation(.easeInOut(duration: 0.3), value: animationPhase)
    }
    
    private func opacity(for index: Int) -> Double {
        if index == animationPhase {
            return 0.8
        } else {
            return 0.3
        }
    }
}

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
