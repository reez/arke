//
//  TagEditorMacOSExample.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/30/25.
//

import SwiftUI

// MARK: - macOS Tag Management Example

struct TagsView: View {
    @Environment(WalletManager.self) private var walletManager
    
    let onNavigateToActivity: ((TagModel) -> Void)?
    
    @State private var showingNewTagEditor = false
    @State private var editingTag: TagModel?
    @State private var tagStatistics: [TagStatistic] = []
    
    init(onNavigateToActivity: ((TagModel) -> Void)? = nil) {
        self.onNavigateToActivity = onNavigateToActivity
    }
    
    // MARK: - Computed Properties
    
    /// The largest positive net amount across all tags (received - sent)
    private var largestPositiveAmount: Int {
        tagStatistics.map(\.totalAmount).filter { $0 > 0 }.max() ?? 0
    }
    
    /// The largest negative net amount across all tags (received - sent)
    private var largestNegativeAmount: Int {
        tagStatistics.map(\.totalAmount).filter { $0 < 0 }.min() ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Content
                if walletManager.hasTags {
                    // TagsGraph()
                    tagsSection
                } else {
                    emptyStateView
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 30)
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Tag") {
                        showingNewTagEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        // Sheet presentation for new tag
        .sheet(isPresented: $showingNewTagEditor) {
            TagEditor(
                onSave: { tag in
                    Task {
                        await createNewTag(tag)
                    }
                    showingNewTagEditor = false
                },
                onCancel: {
                    showingNewTagEditor = false
                }
            )
            .environment(walletManager)
            .environment(walletManager.tagServiceForEnvironment)
            .frame(width: 500, height: 600)
        }
        // Sheet presentation for editing tag using item-based approach
        .sheet(item: $editingTag) { tag in
            print("🔧 TagsView: Creating TagEditor sheet with tag: \(tag.name) (ID: \(tag.id))")
            return TagEditor(
                editingTag: tag,
                onSave: { updatedTag in
                    print("🔧 TagsView: TagEditor onSave called with tag: \(updatedTag.name) (ID: \(updatedTag.id))")
                    Task {
                        await updateTag(updatedTag)
                    }
                    editingTag = nil
                },
                onCancel: {
                    print("🔧 TagsView: TagEditor onCancel called")
                    editingTag = nil
                }
            )
            .environment(walletManager)
            .environment(walletManager.tagServiceForEnvironment)
            .frame(width: 500, height: 600)
            .onAppear {
                print("🔧 TagsView: TagEditor sheet appeared with tag: \(tag.name) (ID: \(tag.id))")
            }
        }
        .task {
            // Create default tags if needed and load statistics
            if walletManager.hasTags == false {
                await walletManager.createDefaultTagsIfNeeded()
            }
            await loadTagStatistics()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var tagsSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(sortedTagsWithStatistics, id: \.tag.id) { item in
                TagCard(
                    tag: item.tag,
                    tagStatistic: item.statistic,
                    onEdit: {
                        print("🔧 TagsView: Edit button pressed for tag: \(item.tag.name) (ID: \(item.tag.id))")
                        editingTag = item.tag
                        print("🔧 TagsView: Set editingTag to: \(editingTag?.name ?? "nil") (ID: \(editingTag?.id.uuidString ?? "nil"))")
                    },
                    onDelete: {
                        Task {
                            await deleteTag(item.tag)
                        }
                    },
                    onTransactionCountTap: onNavigateToActivity,
                    largestPositiveAmount: largestPositiveAmount,
                    largestNegativeAmount: largestNegativeAmount
                )
                
                if item.tag.id != sortedTagsWithStatistics.last?.tag.id {
                    Divider()
                }
            }
        }
    }
    
    /// Tags paired with their statistics, sorted by net amount (highest to lowest)
    /// Tags with 0 transactions are placed at the bottom
    private var sortedTagsWithStatistics: [(tag: TagModel, statistic: TagStatistic)] {
        walletManager.activeTags
            .compactMap { tag in
                guard let statistic = tagStatistics.first(where: { $0.tagId == tag.id }) else {
                    return nil
                }
                return (tag, statistic)
            }
            .sorted { item1, item2 in
                // Tags with 0 transactions go to the bottom
                let hasTransactions1 = item1.statistic.transactionCount > 0
                let hasTransactions2 = item2.statistic.transactionCount > 0
                
                if hasTransactions1 != hasTransactions2 {
                    // One has transactions, the other doesn't - prioritize the one with transactions
                    return hasTransactions1
                }
                
                // Both have transactions (or both don't) - sort by net amount
                return item1.statistic.totalAmount > item2.statistic.totalAmount
            }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tag.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text("No Tags Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create tags to organize and categorize your transactions")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Button("Create Your First Tag") {
                showingNewTagEditor = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: 400)
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func createNewTag(_ tag: TagModel) async {
        do {
            let createdTag = try await walletManager.createTag(tag)
            print("✅ Successfully created tag: \(createdTag.name)")
            // Refresh statistics after creating tag
            await loadTagStatistics()
        } catch {
            print("❌ Failed to create tag: \(error)")
        }
    }
    
    private func updateTag(_ tag: TagModel) async {
        do {
            try await walletManager.updateTag(tag)
            print("✅ Successfully updated tag: \(tag.name)")
            // Refresh statistics after updating tag
            await loadTagStatistics()
        } catch {
            print("❌ Failed to update tag: \(error)")
        }
    }
    
    private func deleteTag(_ tag: TagModel) async {
        do {
            try await walletManager.deleteTag(tag.id)
            print("✅ Successfully deleted tag: \(tag.name)")
            // Refresh statistics after deleting tag
            await loadTagStatistics()
        } catch {
            print("❌ Failed to delete tag: \(error)")
        }
    }
    
    private func getTagUsageCount(for tag: TagModel) -> Int {
        // Find the statistic for this tag
        if let statistic = tagStatistics.first(where: { $0.tagId == tag.id }) {
            return statistic.transactionCount
        }
        return 0
    }
    
    private func loadTagStatistics() async {
        do {
            tagStatistics = try await walletManager.getTagStatistics()
        } catch {
            print("❌ Failed to load tag statistics: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    TagsView()
        .environment(WalletManager(useMock: true))
        .frame(width: 800, height: 600)
}
