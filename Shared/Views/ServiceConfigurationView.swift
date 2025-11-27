//
//  ServiceConfigurationView.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/04/25.
//

import SwiftUI
import SwiftData

/// A view that configures services when the model context becomes available
struct ServiceConfigurationView<Content: View>: View {
    let content: Content
    @Environment(\.serviceContainer) private var serviceContainer
    @Environment(\.modelContext) private var modelContext
    @State private var hasConfiguredServices = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .task {
                guard !hasConfiguredServices else { return }
                
                // Configure services with the model context
                serviceContainer.configureServices(with: modelContext)
                hasConfiguredServices = true
            }
    }
}

extension View {
    /// Wraps the view to automatically configure services when model context is available
    func withServiceConfiguration() -> some View {
        ServiceConfigurationView {
            self
        }
    }
}
