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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        let items = sortedTagsWithStatistics
        
        if items.isEmpty {
            // Fallback if we have tags but no statistics yet
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
                                netChangeBar(for: item.statistic)
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
                                Task {
                                    await deleteTag(item.tag)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
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
    
    // MARK: - Net Change Bar Helper
    
    @ViewBuilder
    private func netChangeBar(for statistic: TagStatistic) -> some View {
        GeometryReader { geometry in
            let totalRange = largestPositiveAmount + abs(largestNegativeAmount)
            let zeroPosition: CGFloat = totalRange > 0 ? CGFloat(abs(largestNegativeAmount)) / CGFloat(totalRange) : 0.5
            let currentAmount = statistic.totalAmount
            
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 8)
                
                // Value bar
                if currentAmount != 0 {
                    let barWidth: CGFloat = {
                        if currentAmount > 0 {
                            // Positive value: bar extends from zero to the right
                            let percentage = CGFloat(currentAmount) / CGFloat(largestPositiveAmount)
                            return geometry.size.width * (1.0 - zeroPosition) * percentage
                        } else {
                            // Negative value: bar extends from zero to the left
                            let percentage = CGFloat(abs(currentAmount)) / CGFloat(abs(largestNegativeAmount))
                            return geometry.size.width * zeroPosition * percentage
                        }
                    }()
                    
                    let barOffset: CGFloat = {
                        if currentAmount > 0 {
                            return geometry.size.width * zeroPosition
                        } else {
                            return geometry.size.width * zeroPosition - barWidth
                        }
                    }()
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(currentAmount >= 0 ? Color.green : Color.red)
                        .frame(width: barWidth, height: 8)
                        .offset(x: barOffset)
                    
                    // Zero line indicator
                    Rectangle()
                        .fill(Color.black.opacity(1))
                        .frame(width: 1, height: 14)
                        .offset(x: geometry.size.width * zeroPosition)
                }
            }
        }
        .frame(height: 10)
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

#Preview("With Tags") {
    TagsView()
        .environment(WalletManager(useMock: true))
        .frame(width: 800, height: 600)
}

#Preview("Empty State") {
    @Previewable @State var emptyWalletManager = {
        let manager = WalletManager(useMock: true)
        // Clear out any default tags to show empty state
        Task {
            for tag in manager.activeTags {
                try? await manager.deleteTag(tag.id)
            }
        }
        return manager
    }()
    
    TagsView()
        .environment(emptyWalletManager)
        .frame(width: 800, height: 600)
}
