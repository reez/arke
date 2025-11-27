//
//  ActivityListView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct ActivityListView_iOS: View {
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        List {
            // Your activity list implementation
            // Each row should be a NavigationLink with value: transaction
            Text("Activity list coming soon")
                .foregroundStyle(.secondary)
        }
    }
}
