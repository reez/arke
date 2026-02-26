//
//  TransactionTagView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/30/25.
//

import SwiftUI
import SwiftData
import ArkeUI

struct TransactionTagView: View {
    let transaction: TransactionModel
    @Environment(WalletManager.self) private var walletManager
    
    @State private var showingTagSelector = false
    @State private var assignedTags: [TagModel] = []
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if assignedTags.isEmpty {
                if !transaction.isInternalTransfer {
                    FlowLayout(alignment: .leading, spacing: 8) {
                        // Add tags button styled like a TagChip
                        /*
                        Button("Add tags") {
                            showingTagSelector = true
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.secondary)
                        .font(.body)
                        .fontWeight(.medium)
                        .overlay(
                            Capsule()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isLoading)
                        */
                        
                        Button{
                            showingTagSelector = true
                        } label: {
                            Text("Add tags")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.Arke.gold2)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    }
                }
            } else {
                FlowLayout(alignment: .leading, spacing: 8) {
                    ForEach(assignedTags) { tag in
                        TagChip(tag: tag, size: .large)
                    }
                    
                    if !transaction.isInternalTransfer {
                        // Edit tags button styled like a TagChip
                        /*
                        Button("Change") {
                            showingTagSelector = true
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.secondary)
                        .font(.body)
                        .fontWeight(.medium)
                        .overlay(
                            Capsule()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isLoading)
                         */
                        
                        Button {
                            showingTagSelector = true
                        } label: {
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.body)
                        }
                        .accessibilityLabel("Change tags")
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                        
                        
                        /*
                        Button(action: onEdit) {
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.body)
                                .tint(Color.Arke.gold3)
                        }
                        .accessibilityLabel("Edit address")
                        .buttonStyle(.bordered)
                         */
                    }
                }
            }
            
            if let error = error {
                ErrorView(errorMessage: error)
            }
        }
        .task(id: transaction.txid) {
            await loadAssignedTags()
        }
        .task(id: walletManager.dataVersion) {
            // Reload tags when dataVersion changes
            await loadAssignedTags()
        }
        .sheet(isPresented: $showingTagSelector) {
            NavigationStack {
                TagSelectorSheet(
                    selectedTagIds: Binding(
                        get: { Set(assignedTags.map { $0.id }) },
                        set: { newTagIds in
                            Task {
                                await updateTagAssignments(newTagIds)
                            }
                        }
                    ),
                    onCreateNewTag: { tag in
                        await createAndAssignTag(tag)
                    }
                )
                .environment(walletManager)
            }
            #if os(macOS)
            .frame(maxWidth: 300, maxHeight: 400)
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    private func loadAssignedTags() async {
        isLoading = true
        error = nil
        
        do {
            let tags = try await walletManager.getTransactionTags(transaction.txid)
            await MainActor.run {
                self.assignedTags = tags
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func removeTag(_ tagId: UUID) async {
        do {
            try await walletManager.unassignTag(tagId, from: transaction.txid)
            await loadAssignedTags() // Refresh the display
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func updateTagAssignments(_ newTagIds: Set<UUID>) async {
        let currentTagIds = Set(assignedTags.map { $0.id })
        
        // Determine which tags to add and remove
        let tagsToAdd = newTagIds.subtracting(currentTagIds)
        let tagsToRemove = currentTagIds.subtracting(newTagIds)
        
        do {
            // Remove tags that are no longer selected
            for tagId in tagsToRemove {
                try await walletManager.unassignTag(tagId, from: transaction.txid)
            }
            
            // Add newly selected tags
            for tagId in tagsToAdd {
                try await walletManager.assignTag(tagId, to: transaction.txid)
            }
            
            await loadAssignedTags() // Refresh the display
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func createAndAssignTag(_ tag: TagModel) async {
        do {
            let createdTag = try await walletManager.createTag(tag)
            try await walletManager.assignTag(createdTag.id, to: transaction.txid)
            await loadAssignedTags() // Refresh the display
            print("✅ Successfully created and assigned tag: \(createdTag.name)")
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            print("❌ Failed to create and assign tag: \(error)")
        }
    }
}

#Preview {
    TransactionTagView(
        transaction: TransactionModel(
            txid: "sample-123", 
            movementId: nil, 
            recipientIndex: nil, 
            type: .received, 
            amount: 50000, 
            date: Date(), 
            status: .confirmed, 
            address: nil
        )
    )
    .environment(WalletManager(useMock: true))
    .frame(width: 400, height: 200)
}
