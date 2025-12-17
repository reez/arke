//
//  TagsView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
import SwiftData

// MARK: - iOS Tag Management

struct TagsView_iOS: View {
    @Environment(WalletManager.self) private var walletManager
    
    let onNavigateToActivity: (TagModel) -> Void
    
    @State private var viewModel: TagsViewModel?
    
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
        List {
            if viewModel.hasTags {
                tagsSection(viewModel: viewModel)
            } else {
                emptyStateSection(viewModel: viewModel)
            }
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showNewTagEditor()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.loadTagStatistics()
        }
        // Sheet presentation for new tag
        .sheet(isPresented: Binding(
            get: { viewModel.showingNewTagEditor },
            set: { if !$0 { viewModel.hideNewTagEditor() } }
        )) {
            NavigationStack {
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
            }
            .presentationDetents([.medium, .large])
        }
        // Sheet presentation for editing tag
        .sheet(item: Binding(
            get: { viewModel.editingTag },
            set: { viewModel.editingTag = $0 }
        )) { tag in
            NavigationStack {
                TagEditor(
                    editingTag: tag,
                    onSave: { updatedTag in
                        Task {
                            await viewModel.updateTag(updatedTag)
                        }
                        viewModel.hideEditTagEditor()
                    },
                    onCancel: {
                        viewModel.hideEditTagEditor()
                    }
                )
                .environment(walletManager)
                .environment(walletManager.tagServiceForEnvironment)
            }
            .presentationDetents([.medium, .large])
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
        
        if items.isEmpty {
            ContentUnavailableView {
                Label("Loading Tags", systemImage: "tag.circle")
            } description: {
                Text("Please wait...")
            }
        } else {
            ForEach(items, id: \.tag.id) { item in
                Button {
                    onNavigateToActivity(item.tag)
                } label: {
                    TagRow(
                        tag: item.tag,
                        statistic: item.statistic
                    )
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.showDeleteConfirmation(for: item.tag)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        viewModel.showEditTagEditor(for: item.tag)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button {
                        viewModel.showEditTagEditor(for: item.tag)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    if item.statistic.transactionCount > 0 {
                        Button {
                            onNavigateToActivity(item.tag)
                        } label: {
                            Label("View Transactions", systemImage: "list.bullet")
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        viewModel.showDeleteConfirmation(for: item.tag)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func emptyStateSection(viewModel: TagsViewModel) -> some View {
        Section {
            ContentUnavailableView {
                Label("No Tags Yet", systemImage: "tag.circle")
            } description: {
                Text("Create tags to organize and categorize your transactions")
            } actions: {
                Button("Create Your First Tag") {
                    viewModel.showNewTagEditor()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Add Default Tags") {
                    Task {
                        await viewModel.createDefaultTags()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: - Tag Row Component

/// iOS-specific row component for displaying tag information
private struct TagRow: View {
    let tag: TagModel
    let statistic: TagStatistic
    
    var body: some View {
        HStack(spacing: 12) {
            // Tag chip
            TagChip(tag: tag, size: .medium)
            
            Spacer()
            
            // Statistics
            VStack(alignment: .trailing, spacing: 4) {
                if statistic.transactionCount > 0 {
                    Text(statistic.formattedTotalAmount)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(statistic.totalAmount >= 0 ? .green : .red)
                    
                    Text("\(statistic.transactionCount) transaction\(statistic.transactionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("With Tags") {
    @Previewable @State var container = PreviewHelper.createPreviewContainer()
    @Previewable @State var walletManager: WalletManager?
    
    NavigationStack {
        TagsView_iOS { tag in
            print("Navigate to activity for tag: \(tag.name)")
        }
        .environment(walletManager ?? WalletManager(useMock: true))
        .modelContainer(container)
    }
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
    
    NavigationStack {
        TagsView_iOS { tag in
            print("Navigate to activity for tag: \(tag.name)")
        }
        .environment(walletManager ?? WalletManager(useMock: true))
        .modelContainer(container)
    }
    .task {
        if walletManager == nil {
            walletManager = await PreviewHelper.createEmptyPreviewWalletManager()
        }
    }
}

#Preview("With Sample Data") {
    @Previewable @State var container = PreviewHelper.createPreviewContainer()
    @Previewable @State var walletManager: WalletManager?
    
    NavigationStack {
        TagsView_iOS { tag in
            print("Navigate to activity for tag: \(tag.name)")
        }
        .environment(walletManager ?? WalletManager(useMock: true))
        .modelContainer(container)
    }
    .task {
        if walletManager == nil {
            walletManager = await PreviewHelper.createSampleDataWalletManager()
        }
    }
}

