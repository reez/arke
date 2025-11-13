//
//  BoardingModalErrorView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/12/25.
//

import SwiftUI

struct BoardingModalErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                // Large red X icon
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                VStack(spacing: 8) {
                    Text("Boarding Failed")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

#Preview {
    BoardingModalErrorView(errorMessage: "Network connection failed. Please check your internet connection and try again.") {
        print("Retry tapped")
    }
    .frame(width: 400, height: 400)
}
