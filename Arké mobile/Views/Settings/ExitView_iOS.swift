//
//  ExitView_iOS.swift
//  Arké
//
//  Created by Christoph on 1/7/26.
//

import SwiftUI

struct ExitView_iOS: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.up.forward.square.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding(.top, 40)
            
            Text("Unilateral Exit")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This feature is coming soon.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Exit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ExitView_iOS()
    }
}
