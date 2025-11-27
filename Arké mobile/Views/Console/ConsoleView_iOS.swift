//
//  ConsoleView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct ConsoleView_iOS: View {
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Console View")
                    .font(.largeTitle)
                Text("Implement your console/debug view here")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
