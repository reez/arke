//
//  VTXODetailView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct VTXODetailView_iOS: View {
    let vtxo: VTXOModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("VTXO Detail")
                    .font(.largeTitle)
                
                Text("VTXO ID: \(vtxo.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Implement your VTXO detail UI here
            }
            .padding()
        }
        .navigationTitle("VTXO")
        .navigationBarTitleDisplayMode(.inline)
    }
}
