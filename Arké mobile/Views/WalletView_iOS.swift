//
//  WalletView_iOS.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import SwiftData
import ArkeUI

enum WalletTab: String, CaseIterable {
    case activity = "Activity"
    case send = "Send"
    case receive = "Receive"
    
    var systemImage: String {
        switch self {
        case .activity: return "bitcoinsign"
        case .send: return "arrow.up"
        case .receive: return "arrow.down"
        }
    }
    
    var label: String {
        return self.rawValue
    }
}

// Navigation destinations for Activity tab
enum ActivityDestination: Hashable {
    case balance
    case transaction(TransactionModel)
    case contact(ContactModel)
    case settings
    case exit
    case contacts
    case tags
    case data
    case console
    case dataDetail(DataDetailItem_iOS)
}

// Enum to represent the selected item in the data view
enum DataDetailItem_iOS: Hashable {
    case vtxo(VTXOModel)
    case utxo(UTXOModel)
}

struct WalletView_iOS: View {
    @State private var selectedTab: WalletTab = .activity
    
    // Navigation paths for each tab
    @State private var activityNavPath = NavigationPath()
    @State private var sendNavPath = NavigationPath()
    @State private var receiveNavPath = NavigationPath()
    
    // State for modals and sheets
    @State private var editingContact: ContactModel?
    @State private var prefilledSendAddress: String?
    @State private var prefilledSendContact: ContactModel?
    @State private var selectedTransaction: TransactionModel?
    
    // State for activity filtering
    @State private var activityFilterTag: TagModel?
    @State private var activityFilterContact: ContactModel?
    
    // Track if this is the first appearance of the view
    @State private var hasAppearedBefore = false
    
    // Toggle for send and receive tab interactions
    @State private var sendTabDoubleTapTrigger = 0
    @State private var receiveTabDoubleTapTrigger = 0
    
    // State for tilt-to-share motion detection
    @State private var motionManager = MotionManager()
    
    @Environment(WalletManager.self) private var manager
    
    let onWalletDeleted: (() -> Void)?
    
    init(onWalletDeleted: (() -> Void)? = nil) {
        self.onWalletDeleted = onWalletDeleted
        
        // Customize navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.largeTitleTextAttributes = [
            .font: UIFont(descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withDesign(.serif)!, size: 34)
        ]
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // Custom binding to detect tab re-selection
    private var selectedTabBinding: Binding<WalletTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                let oldValue = selectedTab
                
                print("📍 [WalletView_iOS] Tab selection: \(oldValue) → \(newValue)")
                
                // Detect tab re-selection (tapping already-selected tab)
                if newValue == oldValue {
                    print("👆 [WalletView_iOS] Tab re-selection detected: \(newValue)")
                    
                    // Handle Send tab re-selection - toggle input method
                    if newValue == .send {
                        sendTabDoubleTapTrigger += 1
                        print("   └─ sendTabDoubleTapTrigger incremented to: \(sendTabDoubleTapTrigger)")
                    }
                    
                    // Handle Receive tab re-selection - toggle display mode
                    if newValue == .receive {
                        receiveTabDoubleTapTrigger += 1
                        print("   └─ receiveTabDoubleTapTrigger incremented to: \(receiveTabDoubleTapTrigger)")
                    }
                    
                    // Could handle other tabs here (e.g., scroll to top on Activity)
                    
                }
                
                // Clear send prefilled data when navigating away from send
                if oldValue == .send && newValue != .send {
                    prefilledSendAddress = nil
                    prefilledSendContact = nil
                    print("   └─ Cleared send prefilled data")
                }
                
                // Always update the state
                selectedTab = newValue
            }
        )
    }
    
    var body: some View {
        TabView(selection: selectedTabBinding) {
            // MARK: - Activity Tab
            NavigationStack(path: $activityNavPath) {
                ActivityView_iOS(
                    selectedTransaction: $selectedTransaction,
                    filterTag: activityFilterTag?.toPersistentTag(),
                    filterContact: activityFilterContact?.toPersistentContact(),
                    onClearFilter: {
                        activityFilterTag = nil
                        activityFilterContact = nil
                    },
                    onNavigate: { destination in
                        activityNavPath.append(destination)
                    }
                )
                .navigationDestination(for: ActivityDestination.self) { destination in
                    switch destination {
                    case .balance:
                        BalanceView_iOS()
                    case .transaction(let transaction):
                        TransactionDetailView_iOS(
                            transaction: transaction,
                            onNavigateToContact: { contact in
                                activityNavPath.append(ActivityDestination.contact(contact))
                            }
                        )
                    case .contact(let contact):
                        ContactDetailView_iOS(
                            contact: contact,
                            onSendToAddress: { address in
                                // Navigate to send tab with prefilled data
                                prefilledSendAddress = address.address
                                prefilledSendContact = contact
                                selectedTab = .send
                            },
                            onEdit: {
                                editingContact = contact
                            },
                            onDelete: {
                                Task {
                                    await deleteContact(contact)
                                }
                            },
                            onNavigateToActivity: { contact in
                                if let contact {
                                    print("🔄 [WalletView_iOS] Activity tab: Filtering by contact: \(contact.displayName)")
                                    activityFilterContact = contact
                                } else {
                                    print("🔄 [WalletView_iOS] Activity tab: Clearing contact filter")
                                    activityFilterContact = nil
                                }
                                
                                // Clear any tag filter to avoid conflicts
                                activityFilterTag = nil
                                
                                // Pop navigation stack back to root
                                if !activityNavPath.isEmpty {
                                    activityNavPath.removeLast(activityNavPath.count)
                                }
                                
                                // ActivityView_iOS will automatically re-render with the new filter
                            }
                        )
                    case .settings:
                        SettingsView_iOS(onWalletDeleted: onWalletDeleted)
                    case .exit:
                        ExitView_iOS()
                    case .contacts:
                        // Note: This is currently unused - contacts are accessed via SendView
                        // Consider removing this case if not needed
                        ContactsView_iOS(
                            onSelectContact: { contact, address in
                                // Navigate to send tab with prefilled data
                                prefilledSendAddress = address.address
                                prefilledSendContact = contact
                                selectedTab = .send
                            },
                            onNavigateToActivity: { contact in
                                // Already on activity tab, just apply the filter and pop back
                                activityFilterContact = contact
                                activityFilterTag = nil
                                if !activityNavPath.isEmpty {
                                    activityNavPath.removeLast(activityNavPath.count)
                                }
                            }
                        )
                        .navigationTitle("contacts_title")
                    case .tags:
                        TagsView_iOS { tag in
                            // Apply tag filter and pop back to activity view
                            activityFilterTag = tag
                            activityNavPath.removeLast()
                        }
                        .navigationTitle("tags_title")
                    case .data:
                        DataView_iOS(onNavigateToDetail: { dataItem in
                            activityNavPath.append(ActivityDestination.dataDetail(dataItem))
                        })
                    case .console:
                        ConsoleView_iOS()
                            .navigationTitle("console_title")
                    case .dataDetail(let dataItem):
                        switch dataItem {
                        case .vtxo(let vtxo):
                            VTXODetailView(vtxo: vtxo)
                        case .utxo(let utxo):
                            UTXODetailView(utxo: utxo)
                        }
                    }
                }
            }
            .tabItem {
                Image(systemName: WalletTab.activity.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                //Label(WalletTab.activity.label, systemImage: WalletTab.activity.systemImage)
            }
            .tag(WalletTab.activity)
            
            // MARK: - Send Tab
            NavigationStack(path: $sendNavPath) {
                SendView_iOS(
                    prefilledRecipient: prefilledSendAddress,
                    prefilledContact: prefilledSendContact,
                    onNavigateToContact: { contact in
                        sendNavPath.append(contact)
                    },
                    onNavigateToActivity: { contact in
                        if let contact {
                            print("🔄 [WalletView_iOS] Navigating to Activity tab with contact filter: \(contact.displayName)")
                        } else {
                            print("🔄 [WalletView_iOS] Navigating to Activity tab (no filter)")
                        }
                        
                        // Set the contact filter
                        activityFilterContact = contact
                        
                        // Clear any tag filter to avoid conflicts
                        activityFilterTag = nil
                        
                        // Clear the send navigation path
                        if !sendNavPath.isEmpty {
                            sendNavPath.removeLast(sendNavPath.count)
                        }
                        
                        // Switch to activity tab
                        selectedTab = .activity
                        
                        // Clear send prefilled data
                        prefilledSendAddress = nil
                        prefilledSendContact = nil
                    },
                    doubleTapTrigger: sendTabDoubleTapTrigger
                )
                .navigationBarHidden(true)
                .navigationDestination(for: ContactModel.self) { contact in
                    ContactDetailView_iOS(
                        contact: contact,
                        onSendToAddress: { address in
                            // Pop back and fill the send form
                            sendNavPath.removeLast()
                            prefilledSendAddress = address.address
                            prefilledSendContact = contact
                        },
                        onEdit: {
                            editingContact = contact
                        },
                        onDelete: {
                            Task {
                                await deleteContact(contact)
                            }
                        },
                        onNavigateToActivity: { contact in
                            // Clear any filters when navigating from send tab
                            activityFilterContact = contact
                            activityFilterTag = nil
                            
                            // Navigate to activity tab
                            selectedTab = .activity
                        }
                    )
                }
            }
            .tabItem {
                Image(systemName: WalletTab.send.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                //Label(WalletTab.send.label, systemImage: WalletTab.send.systemImage)
            }
            .tag(WalletTab.send)
            
            // MARK: - Receive Tab
            NavigationStack(path: $receiveNavPath) {
                ReceiveView_iOS(
                    doubleTapTrigger: receiveTabDoubleTapTrigger
                )
            }
            .tabItem {
                Image(systemName: WalletTab.receive.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                //Label(WalletTab.receive.label, systemImage: WalletTab.receive.systemImage)
            }
            .tag(WalletTab.receive)
        }
        .tint(Color.Arke.gold)
        .sheet(item: $editingContact) { contact in
            NavigationStack {
                ContactEditor_iOS(
                    editingContact: contact,
                    onSave: { updatedContact in
                        Task {
                            await updateContact(updatedContact)
                        }
                        editingContact = nil
                    },
                    onCancel: {
                        editingContact = nil
                    },
                    onDelete: { contactToDelete in
                        Task {
                            await deleteContact(contactToDelete)
                        }
                        editingContact = nil
                    }
                )
                .environment(manager)
                .environment(manager.contactServiceForEnvironment)
            }
        }
        .overlay(alignment: .center) {
            // Tilt-activated share overlay - placed at TabView level to cover everything
            // Only visible when on Activity tab
            TiltShareOverlay_iOS(
                arkAddress: manager.arkAddress,
                isVisible: motionManager.isForwardTilted && selectedTab == .activity
            )
        }
        .task {
            // Only refresh if this view has appeared before
            // On first appearance, MainView_iOS has already called initialize()
            // which loads all data. We only want to refresh on subsequent
            // appearances (e.g., returning from background, navigating back)
            if hasAppearedBefore {
                print("🔄 [WalletView_iOS] 📍 REFRESH: Calling refresh() (hasAppearedBefore=true)")
                print("   └─ Location: WalletView_iOS .task block (subsequent appearance)")
                await manager.refresh()
                print("✅ [WalletView_iOS] 📍 REFRESH: Complete")
            } else {
                print("⏭️ [WalletView_iOS] 📍 SKIP: Skipping refresh (hasAppearedBefore=false)")
                print("   └─ Data already loaded by MainView_iOS initialization")
                hasAppearedBefore = true
            }
        }
        .onAppear {
            // Start motion monitoring if on Activity tab
            if selectedTab == .activity {
                motionManager.startMonitoring()
            }
        }
        .onDisappear {
            motionManager.stopMonitoring()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Start/stop motion monitoring based on tab selection
            if newValue == .activity {
                motionManager.startMonitoring()
            } else {
                motionManager.stopMonitoring()
            }
        }
    }
    
    // MARK: - Contact Management Methods
    
    private func deleteContact(_ contact: ContactModel) async {
        do {
            try await manager.deleteContact(contact.id)
            print("✅ Successfully deleted contact: \(contact.displayName)")
        } catch {
            print("❌ Failed to delete contact: \(error)")
        }
    }
    
    private func updateContact(_ contact: ContactModel) async {
        do {
            try await manager.updateContact(contact)
            print("✅ Successfully updated contact: \(contact.displayName)")
        } catch {
            print("❌ Failed to update contact: \(error)")
        }
    }
}

#Preview {
    WalletView_iOS(onWalletDeleted: nil)
        .environment(WalletManager(useMock: true))
        .modelContainer(for: ArkBalanceModel.self, inMemory: true)
}
