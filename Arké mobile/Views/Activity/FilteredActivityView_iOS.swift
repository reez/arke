//
//  FilteredActivityView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct FilteredActivityView_iOS: View {
    let tag: TagModel
    
    var body: some View {
        List {
            // Filtered activity implementation
            Text("Filtered activity coming soon")
                .foregroundStyle(.secondary)
        }
        .navigationTitle(tag.name)
    }
}
