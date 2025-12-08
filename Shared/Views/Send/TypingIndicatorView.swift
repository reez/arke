//
//  TypingIndicatorView.swift
//  Arké
//
//  Created by Christoph on 12/8/25.
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
