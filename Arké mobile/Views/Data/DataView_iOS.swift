//
//  DataView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct DataView_iOS: View {
    let onSelectItem: (DataDetailItem_iOS) -> Void
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        List {
            Section("VTXOs") {
                Text("VTXOs list coming soon")
                    .foregroundStyle(.secondary)
                // Each row should be a NavigationLink with value: DataDetailItem_iOS.vtxo
            }
            
            Section("UTXOs") {
                Text("UTXOs list coming soon")
                    .foregroundStyle(.secondary)
                // Each row should be a NavigationLink with value: DataDetailItem_iOS.utxo
            }
        }
    }
}
