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
    
    // State for faucet modal
    @State private var showFaucetModal = false
    
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
                if let tag = filterTag {
                    FilterChipView(tag: tag, onClear: clearFilter)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                } else if let contact = filterContact {
                    FilterChipView(contact: contact, onClear: clearFilter)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }
                
                // Active Exit Alert (if there's an ongoing exit)
                if let activeExit = manager.activeUnilateralExits.first {
                    ActiveExitAlertView_iOS(
                        exit: activeExit,
                        currentBlockHeight: manager.estimatedBlockHeight ?? 0,
                        claimableHeight: nil,
                        onTap: {
                            onNavigate?(.exit)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                
                // Transaction List
                if let transactionService = manager.transactionServiceInstance {
                    TransactionList(
                        selectedTransaction: $selectedTransaction,
                        filterTag: filterTag,
                        filterContact: filterContact,
                        onShowFaucet: {
                            showFaucetModal = true
                        }
                    )
                        .environment(transactionService)
                        .onAppear {
                            // Double-check ModelContext is set (defensive programming)
                            transactionService.setModelContext(modelContext)
                        }
                        .id("\(filterTag?.id.uuidString ?? "none")_\(filterContact?.id.uuidString ?? "none")")
                    
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
            
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showFaucetModal = true
                } label: {
                    Image(systemName: "popcorn.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onNavigate?(.tags)
                } label: {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onNavigate?(.settings)
                } label: {
                    Image(systemName: "xmark.triangle.circle.square.fill")
                        .font(.system(size: 19))
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
        .sheet(isPresented: $showFaucetModal) {
            FaucetModalView_iOS(onNavigateToContact: { contact in
                showFaucetModal = false
                onNavigate?(.contact(contact))
            })
                .environment(manager)
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

#Preview("With Active Exit") {
    @Previewable @State var selectedTransaction: TransactionModel? = nil
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    ActivityView_iOS(selectedTransaction: $selectedTransaction)
        .environment(walletManager)
        .modelContainer(for: [PersistentTransaction.self], inMemory: true)
        .task {
            await walletManager.initialize()
        }
}
#Preview("Faucet Modal") {
    @Previewable @State var walletManager = WalletManager(useMock: true)
    
    FaucetModalView_iOS()
        .environment(walletManager)
        .task {
            await walletManager.initialize()
        }
}

