//
//  ActivityView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
import SwiftData

struct ActivityView_iOS: View {
    @Environment(WalletManager.self) private var manager
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTransaction: TransactionModel?
    let filterTag: PersistentTag?
    let filterContact: PersistentContact?
    let onClearFilter: (() -> Void)?
    let onNavigate: ((ActivityDestination) -> Void)?
    
    // State for scroll tracking
    @State private var scrollOffset: CGFloat = 0
    
    // Constants for layout
    private let balanceCardHeight: CGFloat = 120 // Approximate height, adjust as needed
    private let scrollThreshold: CGFloat = 60 // When to show condensed balance
    
    init(selectedTransaction: Binding<TransactionModel?>, filterTag: PersistentTag? = nil, filterContact: PersistentContact? = nil, onClearFilter: (() -> Void)? = nil, onNavigate: ((ActivityDestination) -> Void)? = nil) {
        self._selectedTransaction = selectedTransaction
        self.filterTag = filterTag
        self.filterContact = filterContact
        self.onClearFilter = onClearFilter
        self.onNavigate = onNavigate
    }
    
    // Computed property to check if any filter is active
    private var hasActiveFilter: Bool {
        filterTag != nil || filterContact != nil
    }
    
    // Computed property for filter display text
    private var filterDisplayText: String? {
        if let tag = filterTag {
            return tag.displayName
        } else if let contact = filterContact {
            return contact.displayName
        }
        return nil
    }
    
    // Calculate opacity for condensed balance (fade in when scrolled)
    private var condensedBalanceOpacity: Double {
        let progress = min(max(scrollOffset / scrollThreshold, 0), 1)
        return progress
    }
    
    // Calculate opacity for full balance card (fade out when scrolling)
    private var balanceCardOpacity: Double {
        let progress = min(max(scrollOffset / scrollThreshold, 0), 1)
        return 1 - progress
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Balance Card - inside scroll view, not fixed
                Button {
                    onNavigate?(.balance)
                } label: {
                    BalanceCard(totalBalance: manager.totalBalance)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
                .padding(.horizontal, 20)
                
                // Filter chip (if active)
                if hasActiveFilter, let filterText = filterDisplayText {
                    HStack {
                        HStack(spacing: 8) {
                            // Filter icon/indicator
                            if filterTag != nil {
                                // Could add a tag icon here if desired
                            } else if let contact = filterContact {
                                // Show contact avatar
                                ContactAvatarView(avatarData: contact.avatarData, size: 16)
                            }
                            
                            Text(filterText)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            // Clear button
                            Button {
                                clearFilter()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(6)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.separator, lineWidth: 0.5)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                
                // Transaction List
                if let transactionService = manager.transactionServiceInstance {
                    TransactionList(
                        selectedTransaction: $selectedTransaction,
                        filterTag: filterTag,
                        filterContact: filterContact
                    )
                        .environment(transactionService)
                        .onAppear {
                            // Double-check ModelContext is set (defensive programming)
                            transactionService.setModelContext(modelContext)
                        }
                    
                    // Error Display - Transaction-specific errors
                    if let error = transactionService.error {
                        ErrorView(errorMessage: error)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                    }
                } else {
                    ContentUnavailableView {
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading transactions...")
                                .font(.system(size: 19, design: .serif))
                        }
                    }
                }
            }
            .background {
                // GeometryReader to track scroll offset
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: -geometry.frame(in: .named("scroll")).minY
                        )
                }
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .frame(maxHeight: .infinity, alignment: .top)
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
        .refreshable {
            await manager.refresh()
        }
        .toolbar {
            /*
            ToolbarItem(placement: .principal) {
                // Condensed balance indicator
                Text(manager.totalBalance.map { BitcoinFormatter.shared.formatAmount($0.grandTotalSat) } ?? "—")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            */
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onNavigate?(.tags)
                } label: {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        onNavigate?(.settings)
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    
                    Divider()
                    
                    Button {
                        onNavigate?(.data)
                    } label: {
                        Label("X-Ray", systemImage: "brain.head.profile.fill")
                    }
                    
                    Button {
                        onNavigate?(.console)
                    } label: {
                        Label("Console", systemImage: "arcade.stick.console.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary)
                }
            }
        }
        .onChange(of: selectedTransaction) { oldValue, newValue in
            if let transaction = newValue {
                onNavigate?(.transaction(transaction))
                // Reset after navigation
                selectedTransaction = nil
            }
        }
    }
    
    // Helper function to clear the active filter
    private func clearFilter() {
        onClearFilter?()
    }
}

// MARK: - Preference Key for Scroll Offset
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    @Previewable @State var selectedTransaction: TransactionModel? = nil
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    ActivityView_iOS(selectedTransaction: $selectedTransaction)
        .environment(walletManager)
        .modelContainer(for: PersistentTransaction.self, inMemory: true)
        .task {
            // Initialize the wallet manager to set up services
            await walletManager.initialize()
        }
}

#Preview("Filtered by Tag") {
    @Previewable @State var selectedTransaction: TransactionModel? = nil
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    // Create a sample tag for filtering
    let sampleTag = PersistentTag(name: "Coffee", colorHex: "#FF6B35", emoji: "☕️")
    
    ActivityView_iOS(
        selectedTransaction: $selectedTransaction,
        filterTag: sampleTag
    )
        .environment(walletManager)
        .modelContainer(for: [PersistentTransaction.self, PersistentTag.self, TransactionTagAssignment.self], inMemory: true)
        .task {
            await walletManager.initialize()
        }
}

#Preview("Filtered by Contact") {
    @Previewable @State var selectedTransaction: TransactionModel? = nil
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    // Create a sample contact for filtering
    let sampleContact = PersistentContact(cachedName: "Alice Smith")
    
    ActivityView_iOS(
        selectedTransaction: $selectedTransaction,
        filterContact: sampleContact
    )
        .environment(walletManager)
        .modelContainer(for: [PersistentTransaction.self, PersistentContact.self, TransactionContactAssignment.self], inMemory: true)
        .task {
            await walletManager.initialize()
        }
}

