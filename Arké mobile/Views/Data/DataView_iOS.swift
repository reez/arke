//
//  DataView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct DataView_iOS: View {
    @Environment(WalletManager.self) private var manager
    var onNavigateToDetail: ((DataDetailItem_iOS) -> Void)? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                ArkBalanceView()
                
                OnchainBalanceView()
                
                VTXOListView_iOS(onSelectItem: { vtxo in
                    onNavigateToDetail?(.vtxo(vtxo))
                })
                
                UTXOListView_iOS(onSelectItem: { utxo in
                    onNavigateToDetail?(.utxo(utxo))
                })
                
                ConfigurationSectionView()
                
                ArkInfoSectionView()
                
                BlockHeightSectionView()
            }
        }
        .navigationTitle("X-Ray")
        .navigationBarTitleDisplayMode(.large)
    }
}
