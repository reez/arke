//
//  TagEditorMacOSExample.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/30/25.
//

import SwiftUI
import SwiftData

// MARK: - macOS Tag Management Example

struct TagsView: View {
    @Environment(WalletManager.self) private var walletManager
    
    let onNavigateToActivity: ((TagModel) -> Void)?
    
    @State private var showingNewTagEditor = false
    @State private var editingTag: TagModel?
    @State private var tagStatistics: [TagStatistic] = []
    @State private var tagToDelete: TagModel?
    
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.vertical, 20)
            .padding(.horizontal, 30)
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTagEditor = true
                    } label: {
                        Image(systemName: "plus")
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
            // Load tag statistics
            print("🔧 TagsView: task started, hasTags=\(walletManager.hasTags)")
            await loadTagStatistics()
            print("🔧 TagsView: task completed, tags.count=\(walletManager.tags.count), statistics.count=\(tagStatistics.count)")
        }
        .confirmationDialog(
            "Delete Tag",
            isPresented: Binding(
                get: { tagToDelete != nil },
                set: { if !$0 { tagToDelete = nil } }
            ),
            presenting: tagToDelete
        ) { tag in
            Button("Delete \"\(tag.name)\"", role: .destructive) {
                Task {
                    await deleteTag(tag)
                    tagToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                tagToDelete = nil
            }
        } message: { tag in
            Text("Are you sure you want to delete this tag? This action cannot be undone.")
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var tagsSection: some View {
        let items = sortedTagsWithStatistics
        
        // Show empty state if no tags exist
        if items.isEmpty {
            VStack(spacing: 20) {
                ProgressView()
                Text("Loading tags...")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            Grid(alignment: .leading, horizontalSpacing: 15, verticalSpacing: 0) {
                ForEach(items, id: \.tag.id) { item in
                    GridRow {
                        // Column 1: TagChip (flexible, takes remaining space)
                        TagChip(tag: item.tag, size: .large)
                            .gridColumnAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Column 2: Transaction count
                        Group {
                            if let onTransactionCountTap = onNavigateToActivity,
                               item.statistic.transactionCount > 0 {
                                Button {
                                    onTransactionCountTap(item.tag)
                                } label: {
                                    Text("\(item.statistic.transactionCount) transactions")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text("\(item.statistic.transactionCount) transactions")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .gridColumnAlignment(.trailing)
                        .frame(minWidth: 140)
                        
                        // Column 3: Amount
                        Group {
                            if item.statistic.transactionCount > 0 {
                                Text(item.statistic.formattedTotalAmount)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(item.statistic.totalAmount >= 0 ? .green : .red)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                Text("")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .gridColumnAlignment(.trailing)
                        .frame(minWidth: 120)
                        
                        // Column 4: Net change bar
                        Group {
                            if largestPositiveAmount > 0 || largestNegativeAmount < 0 {
                                NetChangeBar(
                                    currentAmount: item.statistic.totalAmount,
                                    largestPositiveAmount: largestPositiveAmount,
                                    largestNegativeAmount: largestNegativeAmount
                                )
                            } else {
                                Color.clear.frame(width: 150, height: 10)
                            }
                        }
                        .gridColumnAlignment(.leading)
                        .frame(width: 150)
                        
                        // Column 5: Menu
                        Menu {
                            Button("Edit") {
                                print("🔧 TagsView: Edit button pressed for tag: \(item.tag.name) (ID: \(item.tag.id))")
                                editingTag = item.tag
                                print("🔧 TagsView: Set editingTag to: \(editingTag?.name ?? "nil") (ID: \(editingTag?.id.uuidString ?? "nil"))")
                            }
                            
                            Divider()
                            
                            Button("Delete", role: .destructive) {
                                tagToDelete = item.tag
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .gridColumnAlignment(.trailing)
                        .frame(width: 20, height: 20)
                    }
                    .padding(.vertical, 10)
                    
                    if item.tag.id != items.last?.tag.id {
                        Divider()
                            .gridCellUnsizedAxes(.horizontal)
                            .gridCellColumns(5)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    /// Tags paired with their statistics, sorted by net amount (highest to lowest)
    /// Tags with 0 transactions are placed at the bottom
    private var sortedTagsWithStatistics: [(tag: TagModel, statistic: TagStatistic)] {
        walletManager.tags
            .compactMap { tag in
                // Find statistic or create a zero-stat placeholder
                let statistic = tagStatistics.first(where: { $0.tagId == tag.id }) ?? 
                    TagStatistic(
                        tagId: tag.id,
                        tagName: tag.name,
                        transactionCount: 0,
                        totalAmount: 0,
                        sentAmount: 0,
                        receivedAmount: 0
                    )
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
            
            Button("Add default tags") {
                Task {
                    await walletManager.createDefaultTagsIfNeeded()
                    await loadTagStatistics()
                }
            }
            .buttonStyle(.bordered)
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
            print("📊 Loaded \(tagStatistics.count) tag statistics")
        } catch {
            print("❌ Failed to load tag statistics: \(error)")
            // On error, ensure we still show tags with zero statistics
            tagStatistics = []
        }
    }
}

// MARK: - Preview

#Preview("With Tags") {
    @Previewable @State var container = PreviewHelper.createPreviewContainer()
    @Previewable @State var walletManager: WalletManager?
    
    TagsView()
        .environment(walletManager ?? WalletManager(useMock: true))
        .modelContainer(container)
        .frame(width: 800, height: 600)
        .task {
            if walletManager == nil {
                walletManager = await PreviewHelper.createPreviewWalletManager(
                    container: container,
                    populateWithDefaultTags: true
                )
            }
        }
}

#Preview("Empty State") {
    @Previewable @State var container = PreviewHelper.createPreviewContainer()
    @Previewable @State var walletManager: WalletManager?
    
    TagsView()
        .environment(walletManager ?? WalletManager(useMock: true))
        .modelContainer(container)
        .frame(width: 800, height: 600)
        .task {
            if walletManager == nil {
                // Create with NO default tags to show empty state
                walletManager = await PreviewHelper.createEmptyPreviewWalletManager()
            }
        }
}

#Preview("With Sample Data") {
    @Previewable @State var container = PreviewHelper.createPreviewContainer()
    @Previewable @State var walletManager: WalletManager?
    
    TagsView()
        .environment(walletManager ?? WalletManager(useMock: true))
        .modelContainer(container)
        .frame(width: 800, height: 600)
        .task {
            if walletManager == nil {
                walletManager = await PreviewHelper.createSampleDataWalletManager()
            }
        }
}
