//
//  TagsView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct TagsView_iOS: View {
    let onNavigateToActivity: (TagModel) -> Void
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        List {
            Text("Tags list coming soon")
                .foregroundStyle(.secondary)
            // Each row should be a NavigationLink with value: tag
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Add new tag
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
