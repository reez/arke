//
//  WalletView_iOS.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import SwiftData

enum WalletTab: String, CaseIterable {
    case activity = "Activity"
    case send = "Send"
    case receive = "Receive"
    case more = "More"
    
    var systemImage: String {
        switch self {
        case .activity: return "bitcoinsign.circle.fill"
        case .send: return "arrow.up.circle.fill"
        case .receive: return "arrow.down.circle.fill"
        case .more: return "ellipsis.circle.fill"
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
}

enum MoreMenuItem: String, CaseIterable, Identifiable {
    case contacts = "Contacts"
    case tags = "Tags"
    case data = "X-Ray"
    case console = "Console"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .contacts: return "person.fill"
        case .tags: return "tag.fill"
        case .data: return "brain.head.profile.fill"
        case .console: return "arcade.stick.console.fill"
        case .settings: return "gearshape.fill"
        }
    }
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
    @State private var moreNavPath = NavigationPath()
    
    // State for modals and sheets
    @State private var editingContact: ContactModel?
    @State private var prefilledSendAddress: String?
    @State private var prefilledSendContact: ContactModel?
    @State private var selectedTransaction: TransactionModel?
    
    // Track if this is the first appearance of the view
    @State private var hasAppearedBefore = false
    
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
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - Activity Tab
            NavigationStack(path: $activityNavPath) {
                ActivityView_iOS(
                    selectedTransaction: $selectedTransaction,
                    onNavigate: { destination in
                        activityNavPath.append(destination)
                    }
                )
                .toolbar(.hidden, for: .navigationBar)
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
                            onNavigateToActivity: { filteredContact in
                                // Could show filtered view or just stay in activity
                            }
                        )
                    }
                }
            }
            .tabItem {
                Label(WalletTab.activity.label, systemImage: WalletTab.activity.systemImage)
            }
            .tag(WalletTab.activity)
            
            // MARK: - Send Tab
            NavigationStack(path: $sendNavPath) {
                SendView_iOS(
                    prefilledRecipient: prefilledSendAddress,
                    prefilledContact: prefilledSendContact,
                    onNavigateToContact: { contact in
                        sendNavPath.append(contact)
                    }
                )
                .navigationTitle("Send")
                .navigationBarTitleDisplayMode(.large)
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
                        onNavigateToActivity: { _ in
                            // Navigate to activity tab
                            selectedTab = .activity
                        }
                    )
                }
            }
            .tabItem {
                Label(WalletTab.send.label, systemImage: WalletTab.send.systemImage)
            }
            .tag(WalletTab.send)
            
            // MARK: - Receive Tab
            NavigationStack(path: $receiveNavPath) {
                ReceiveView_iOS()
                    .navigationTitle("Your payment info")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label(WalletTab.receive.label, systemImage: WalletTab.receive.systemImage)
            }
            .tag(WalletTab.receive)
            
            // MARK: - More Tab
            NavigationStack(path: $moreNavPath) {
                MoreMenuView_iOS(
                    onNavigateToContact: { contact in
                        moreNavPath.append(contact)
                    },
                    onNavigateToActivity: {
                        selectedTab = .activity
                    },
                    onWalletDeleted: onWalletDeleted
                )
                .navigationTitle("More")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: MoreMenuItem.self) { menuItem in
                    moreMenuDestination(for: menuItem)
                }
                .navigationDestination(for: ContactModel.self) { contact in
                    ContactDetailView_iOS(
                        contact: contact,
                        onSendToAddress: { address in
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
                        onNavigateToActivity: { _ in
                            selectedTab = .activity
                        }
                    )
                }
                .navigationDestination(for: TagModel.self) { tag in
                    // Show activity filtered by tag
                    FilteredActivityView_iOS(tag: tag)
                }
                .navigationDestination(for: DataDetailItem_iOS.self) { dataItem in
                    switch dataItem {
                    case .vtxo(let vtxo):
                        VTXODetailView_iOS(vtxo: vtxo)
                    case .utxo(let utxo):
                        UTXODetailView_iOS(utxo: utxo)
                    }
                }
            }
            .tabItem {
                Label(WalletTab.more.label, systemImage: WalletTab.more.systemImage)
            }
            .tag(WalletTab.more)
        }
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
        .onChange(of: selectedTab) { oldValue, newValue in
            // Clear send prefilled data when navigating away from send
            if oldValue == .send && newValue != .send {
                prefilledSendAddress = nil
                prefilledSendContact = nil
            }
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
    }
    
    // MARK: - More Menu Destination Builder
    @ViewBuilder
    private func moreMenuDestination(for item: MoreMenuItem) -> some View {
        switch item {
        case .contacts:
            ContactsView_iOS(
                onSendToAddress: { address, contact in
                    // Navigate to send tab with prefilled data
                    prefilledSendAddress = address.address
                    prefilledSendContact = contact
                    selectedTab = .send
                },
                onNavigateToActivity: { contact in
                    // Navigate to activity filtered by contact
                    selectedTab = .activity
                },
                onSelectContact: { contact in
                    moreNavPath.append(contact)
                }
            )
            .navigationTitle("Contacts")
        case .tags:
            TagsView_iOS(onNavigateToActivity: { tag in
                moreNavPath.append(tag)
            })
            .navigationTitle("Tags")
        case .data:
            DataView_iOS(onSelectItem: { dataItem in
                moreNavPath.append(dataItem)
            })
            .navigationTitle("X-Ray")
        case .console:
            ConsoleView_iOS()
                .navigationTitle("Console")
        case .settings:
            SettingsView_iOS(onWalletDeleted: onWalletDeleted)
                .navigationTitle("Settings")
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

// MARK: - More Menu View

struct MoreMenuView_iOS: View {
    let onNavigateToContact: (ContactModel) -> Void
    let onNavigateToActivity: () -> Void
    let onWalletDeleted: (() -> Void)?
    
    var body: some View {
        List {
            ForEach(MoreMenuItem.allCases) { menuItem in
                NavigationLink(value: menuItem) {
                    Label(menuItem.rawValue, systemImage: menuItem.systemImage)
                }
            }
        }
    }
}

#Preview {
    WalletView_iOS(onWalletDeleted: nil)
        .environment(WalletManager(useMock: true))
        .modelContainer(for: ArkBalanceModel.self, inMemory: true)
}
