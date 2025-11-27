//
//  UTXODetailView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct UTXODetailView_iOS: View {
    let utxo: UTXOModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("UTXO Detail")
                    .font(.largeTitle)
                
                Text("UTXO ID: \(utxo.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Implement your UTXO detail UI here
            }
            .padding()
        }
        .navigationTitle("UTXO")
        .navigationBarTitleDisplayMode(.inline)
    }
}
