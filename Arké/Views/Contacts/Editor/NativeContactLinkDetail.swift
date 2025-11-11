//
//  NativeContactLinkDetail.swift
//  Arké
//
//  Created by Christoph on 11/11/25.
//

import SwiftUI

/// Detailed view showing native contact link status with refresh option
struct NativeContactLinkDetail: View {
    let contact: ContactModel
    let onRefresh: () -> Void
    let onUnlink: () -> Void
    
    @State private var isRefreshing = false
    
    var body: some View {
        if contact.isLinkedToNativeContact {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "link.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Linked to Contacts")
                            .font(.headline)
                        
                        if let lastSynced = contact.lastSyncedFromNative {
                            Text("Last synced \(lastSynced, formatter: relativeDateFormatter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        isRefreshing = true
                        onRefresh()
                        // Reset after a delay
                        Task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            isRefreshing = false
                        }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .disabled(isRefreshing)
                    
                    Button(role: .destructive, action: onUnlink) {
                        Label("Unlink", systemImage: "link.badge.xmark")
                            .font(.subheadline)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }
}

#Preview("Detail View") {
    NativeContactLinkDetail(
        contact: ContactModel(
            cachedName: "John Doe",
            nativeContactID: "12345",
            lastSyncedFromNative: Date().addingTimeInterval(-3600)
        ),
        onRefresh: {
            print("Refresh tapped")
        },
        onUnlink: {
            print("Unlink tapped")
        }
    )
    .padding()
    .frame(width: 400)
}
