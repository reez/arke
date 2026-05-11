//
//  VTXODetailView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/19/25.
//

import SwiftUI

struct VTXODetailView: View {
    let vtxo: VTXOModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Section
                VStack(spacing: 16) {
                    // VTXO Icon and Type
                    HStack {
                        Image(systemName: vtxo.state.iconName)
                            .font(.system(size: 40))
                            .foregroundColor(vtxo.state.iconColor)
                        
                        VStack(alignment: .leading) {
                            Text("label_vtxo")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(vtxo.state.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Amount
                    Text(vtxo.formattedAmount)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // State Badge
                    HStack {
                        Text(vtxo.state.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(vtxo.state.textColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(vtxo.state.backgroundColor)
                            .clipShape(Capsule())
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                // Developer Actions Section
                VTXODeveloperActionsView(vtxo: vtxo)
                
                Divider()
                
                // Details Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("balance_vtxo_details")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        // Outpoint (ID)
                        DetailRow(
                            title: "Outpoint",
                            value: vtxo.outpoint,
                            isCopyable: true
                        )
                        
                        // Transaction ID
                        DetailRow(
                            title: "Transaction ID",
                            value: vtxo.txid,
                            isCopyable: true
                        )
                        
                        // Output Index
                        DetailRow(
                            title: "Output Index",
                            value: String(vtxo.vout)
                        )
                        
                        // VTXO Kind
                        DetailRow(
                            title: "VTXO Kind",
                            value: vtxo.kind.displayName
                        )
                        
                        // State
                        DetailRow(
                            title: "State",
                            value: vtxo.state.displayName
                        )
                        
                        // Expiry Height
                        if vtxo.expiryHeight > 0 {
                            DetailRow(
                                title: "Expiry Height",
                                value: vtxo.expiryHeight.formatted()
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("balance_vtxo_details")
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
    }
}

#Preview {
    NavigationStack {
        VTXODetailView(
            vtxo: VTXOModel.mockVTXOs()[0]
        )
    }
    .environment(WalletManager(useMock: true))
}
