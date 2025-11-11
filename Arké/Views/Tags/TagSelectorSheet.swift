//
//  TagSelectorSheet.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/30/25.
//

import SwiftUI

struct TagSelectorSheet: View {
    @Binding var selectedTagIds: Set<UUID>
    let onCreateNewTag: (TagModel) async -> Void
    
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingTagEditor = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Tags")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("New Tag") {
                    showingTagEditor = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                // Existing Tags Section
                if walletManager.hasTags {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(walletManager.activeTags) { tag in
                            TagChip_Selectable(
                                tag: tag,
                                isSelected: Binding(
                                    get: { selectedTagIds.contains(tag.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedTagIds.insert(tag.id)
                                        } else {
                                            selectedTagIds.remove(tag.id)
                                        }
                                    }
                                )
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingTagEditor) {
            TagEditor(
                onSave: { tag in
                    Task {
                        await onCreateNewTag(tag)
                    }
                    showingTagEditor = false
                },
                onCancel: {
                    showingTagEditor = false
                }
            )
            .environment(walletManager)
            .environment(walletManager.tagServiceForEnvironment)
            .frame(width: 500, height: 600)
        }
    }
}

#Preview {
    // Create a mock wallet manager for the preview
    @Previewable @State var selectedTagIds: Set<UUID> = []
    
    // Mock WalletManager for preview
    let mockWalletManager = WalletManager()
    
    TagSelectorSheet(
        selectedTagIds: $selectedTagIds,
        onCreateNewTag: { tag in
            print("Created new tag: \(tag.name)")
        }
    )
    .environment(mockWalletManager)
    .frame(width: 600, height: 700)
}
