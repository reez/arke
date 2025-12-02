//
//  TagEditorMacOSExample.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/30/25.
//

import SwiftUI
import SwiftData

// MARK: - macOS Tag Management

struct TagsView: View {
    @Environment(WalletManager.self) private var walletManager
    
    let onNavigateToActivity: ((TagModel) -> Void)?
    
    @State private var viewModel: TagsViewModel?
    
    init(onNavigateToActivity: ((TagModel) -> Void)? = nil) {
        self.onNavigateToActivity = onNavigateToActivity
    }
    
    var body: some View {
        Group {
            if let viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .task {
                        viewModel = TagsViewModel(walletManager: walletManager)
                        await viewModel?.loadTagStatistics()
                    }
            }
        }
    }
    
    @ViewBuilder
    private func contentView(viewModel: TagsViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Content
                if viewModel.hasTags {
                    // TagsGraph()
                    tagsSection(viewModel: viewModel)
                } else {
                    emptyStateView(viewModel: viewModel)
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
                        viewModel.showNewTagEditor()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        // Sheet presentation for new tag
        .sheet(isPresented: Binding(
            get: { viewModel.showingNewTagEditor },
            set: { if !$0 { viewModel.hideNewTagEditor() } }
        )) {
            TagEditor(
                onSave: { tag in
                    Task {
                        await viewModel.createNewTag(tag)
                    }
                    viewModel.hideNewTagEditor()
                },
                onCancel: {
                    viewModel.hideNewTagEditor()
                }
            )
            .environment(walletManager)
            .environment(walletManager.tagServiceForEnvironment)
            .frame(width: 500, height: 600)
        }
        // Sheet presentation for editing tag using item-based approach
        .sheet(item: Binding(
            get: { viewModel.editingTag },
            set: { viewModel.editingTag = $0 }
        )) { tag in
            print("🔧 TagsView: Creating TagEditor sheet with tag: \(tag.name) (ID: \(tag.id))")
            return TagEditor(
                editingTag: tag,
                onSave: { updatedTag in
                    print("🔧 TagsView: TagEditor onSave called with tag: \(updatedTag.name) (ID: \(updatedTag.id))")
                    Task {
                        await viewModel.updateTag(updatedTag)
                    }
                    viewModel.hideEditTagEditor()
                },
                onCancel: {
                    print("🔧 TagsView: TagEditor onCancel called")
                    viewModel.hideEditTagEditor()
                }
            )
            .environment(walletManager)
            .environment(walletManager.tagServiceForEnvironment)
            .frame(width: 500, height: 600)
            .onAppear {
                print("🔧 TagsView: TagEditor sheet appeared with tag: \(tag.name) (ID: \(tag.id))")
            }
        }
        .confirmationDialog(
            "Delete Tag",
            isPresented: Binding(
                get: { viewModel.tagToDelete != nil },
                set: { if !$0 { viewModel.hideDeleteConfirmation() } }
            ),
            presenting: viewModel.tagToDelete
        ) { tag in
            Button("Delete \"\(tag.name)\"", role: .destructive) {
                Task {
                    await viewModel.deleteTag(tag)
                    viewModel.hideDeleteConfirmation()
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.hideDeleteConfirmation()
            }
        } message: { tag in
            Text("Are you sure you want to delete this tag? This action cannot be undone.")
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func tagsSection(viewModel: TagsViewModel) -> some View {
        let items = viewModel.sortedTagsWithStatistics
        
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
                            if viewModel.largestPositiveAmount > 0 || viewModel.largestNegativeAmount < 0 {
                                NetChangeBar(
                                    currentAmount: item.statistic.totalAmount,
                                    largestPositiveAmount: viewModel.largestPositiveAmount,
                                    largestNegativeAmount: viewModel.largestNegativeAmount
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
                                viewModel.showEditTagEditor(for: item.tag)
                            }
                            
                            Divider()
                            
                            Button("Delete", role: .destructive) {
                                viewModel.showDeleteConfirmation(for: item.tag)
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
    
    @ViewBuilder
    private func emptyStateView(viewModel: TagsViewModel) -> some View {
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
                viewModel.showNewTagEditor()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Button("Add default tags") {
                Task {
                    await viewModel.createDefaultTags()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: 400)
        .frame(maxHeight: .infinity)
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
