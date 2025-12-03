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
        ScrollView {
            VStack(spacing: 30) {
                ArkBalanceView()
                
                OnchainBalanceView()
                
                ConfigurationSectionView()
                
                ArkInfoSectionView()
                
                BlockHeightSectionView()
            }
        }
    }
}
