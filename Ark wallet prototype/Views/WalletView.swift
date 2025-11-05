//
//  WalletView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import SwiftData

enum NavigationItem: String, CaseIterable {
    case balance = "Balancé"
    case activity = "Activité"
    case send = "Sénd"
    case receive = "Réceive"
    case contacts = "Contacts"
    case tags = "Tags"
    case settings = "Séttings"
    case data = "X-Ráy"
    
    var systemImage: String {
        switch self {
        case .balance: return "list.bullet"
        case .activity: return "list.bullet"
        case .send: return "arrow.up.circle.fill"
        case .receive: return "arrow.down.circle.fill"
        case .contacts: return "arrow.down.circle.fill"
        case .tags: return "arrow.down.circle.fill"
        case .settings: return "gearshape.fill"
        case .data: return "doc.text.fill"
        }
    }
}

// Enum to represent the selected item in the data view
enum DataDetailItem: Hashable {
    case vtxo(VTXOModel)
    case utxo(UTXOModel)
}

struct WalletSidebar: View {
    @Binding var selectedItem: NavigationItem
    @Environment(WalletManager.self) private var manager
    
    var body: some View {
        VStack(spacing: 0) {
            // Balance Card at the top
            if let totalBalance = manager.totalBalance {
                Button {
                    selectedItem = .balance
                } label: {
                    BalanceCard(totalBalance: totalBalance)
                }
                .buttonStyle(.plain)
                .padding()
            } else {
                SkeletonLoader(
                    itemCount: 1,
                    itemHeight: 150,
                    spacing: 10,
                    cornerRadius: 15
                )
                .padding()
            }
            
            // Navigation List
            List(NavigationItem.allCases, id: \.self, selection: $selectedItem) { item in
                if(item != .balance) {
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.systemImage)
                            .font(.system(size: 15))
                    }
                }
            }
        }
        .navigationTitle("Wallet")
    }
}

struct WalletView: View {
    @State private var selectedItem: NavigationItem = .activity
    @State private var selectedTransaction: TransactionModel?
    @State private var selectedDataItem: DataDetailItem?
    @State private var selectedContact: ContactModel?
    @State private var editingContact: ContactModel?
    @State private var activityFilterContact: PersistentContact? = nil
    @State private var activityFilterTag: PersistentTag? = nil
    @State private var prefilledSendAddress: String?
    @State private var prefilledSendContact: ContactModel?
    @Environment(WalletManager.self) private var manager
    
    let onWalletDeleted: (() -> Void)?
    
    // MARK: - Navigation Methods
    
    private func navigateToFilteredActivityByContact(contact: ContactModel) {
        selectedItem = .activity
        selectedTransaction = nil
        selectedContact = nil
        activityFilterTag = nil
        activityFilterContact = contact.toPersistentContact()
    }
    
    private func navigateToFilteredActivityByTag(tag: TagModel) {
        selectedItem = .activity
        selectedTransaction = nil
        selectedContact = nil
        activityFilterContact = nil
        activityFilterTag = tag.toPersistentTag()
    }
    
    private func navigateToSendWithAddress(_ address: String, contact: ContactModel) {
        prefilledSendAddress = address
        prefilledSendContact = contact
        selectedItem = .send
    }
    
    // MARK: - Contact Management Methods
    
    private func deleteContact(_ contact: ContactModel) async {
        do {
            try await manager.deleteContact(contact.id)
            print("✅ Successfully deleted contact: \(contact.displayName)")
            
            // Clear selected contact if it's the one being deleted
            if selectedContact?.id == contact.id {
                selectedContact = nil
            }
        } catch {
            print("❌ Failed to delete contact: \(error)")
        }
    }
    
    private func updateContact(_ contact: ContactModel) async {
        do {
            try await manager.updateContact(contact)
            print("✅ Successfully updated contact: \(contact.displayName)")
            
            // Update selected contact if it matches
            if selectedContact?.id == contact.id {
                selectedContact = contact
            }
        } catch {
            print("❌ Failed to update contact: \(error)")
        }
    }
    
    var body: some View {
        Group {
            if selectedItem == .activity {
            // Three-column layout for activity view
            NavigationSplitView {
                // Sidebar
                WalletSidebar(selectedItem: $selectedItem)
                    .navigationSplitViewColumnWidth(min: 250, ideal: 250)
            } content: {
                ActivityView(
                    selectedTransaction: $selectedTransaction,
                    filterTag: activityFilterTag,
                    filterContact: activityFilterContact,
                    onClearFilter: { activityFilterContact = nil; activityFilterTag = nil }
                )
                    .navigationSplitViewColumnWidth(min: 300, ideal: 500)
            } detail: {
                if let transaction = selectedTransaction {
                    TransactionDetailView(transaction: transaction)
                        .navigationSplitViewColumnWidth(min: 250, ideal: 250, max: 400)
                } else {
                    ContentUnavailableView {
                        VStack(spacing: 15) {
                            Image(systemName: "list.bullet")
                                .imageScale(.medium)
                                .symbolVariant(.none)
                            Text("Select a transaction")
                                .font(.system(size: 19, design: .serif))
                        }
                    }
                    .navigationSplitViewColumnWidth(min: 250, ideal: 250, max: 400)
                }
            }
            } else if selectedItem == .data {
            // Three-column layout for data view
            NavigationSplitView {
                // Sidebar
                WalletSidebar(selectedItem: $selectedItem)
                    .navigationSplitViewColumnWidth(min: 250, ideal: 250)
            } content: {
                DataView(selectedDataItem: $selectedDataItem)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 300)
            } detail: {
                if let dataItem = selectedDataItem {
                    switch dataItem {
                    case .vtxo(let vtxo):
                        VTXODetailView(vtxo: vtxo)
                            .navigationSplitViewColumnWidth(min: 250, ideal: 250, max: 400)
                    case .utxo(let utxo):
                        UTXODetailView(utxo: utxo)
                            .navigationSplitViewColumnWidth(min: 250, ideal: 250, max: 400)
                    }
                } else {
                    ContentUnavailableView {
                        VStack(spacing: 15) {
                            Image(systemName: "list.bullet")
                                .imageScale(.medium)
                                .symbolVariant(.none)
                            Text("Select a VTXO or UTXO")
                                .font(.system(size: 19, design: .serif))
                        }
                    }
                    .navigationSplitViewColumnWidth(min: 250, ideal: 250, max: 400)
                }
            }
            } else if selectedItem == .contacts {
            // Three-column layout for contacts view
            NavigationSplitView {
                // Sidebar
                WalletSidebar(selectedItem: $selectedItem)
                    .navigationSplitViewColumnWidth(min: 250, ideal: 250)
            } content: {
                ContactsView(
                    selectedContact: $selectedContact,
                    onNavigateToActivity: navigateToFilteredActivityByContact
                )
                .navigationSplitViewColumnWidth(min: 300, ideal: 300)
            } detail: {
                if let contact = selectedContact {
                    ContactDetailView(
                        contact: contact,
                        onSendToAddress: { address in
                            navigateToSendWithAddress(address.address, contact: contact)
                        },
                        onEdit: {
                            editingContact = contact
                        },
                        onDelete: {
                            Task {
                                await deleteContact(contact)
                            }
                        }
                    )
                    .navigationSplitViewColumnWidth(min: 250, ideal: 250, max: 400)
                } else {
                    ContentUnavailableView {
                        VStack(spacing: 15) {
                            Image(systemName: "list.bullet")
                                .imageScale(.medium)
                                .symbolVariant(.none)
                            Text("Select a contact")
                                .font(.system(size: 19, design: .serif))
                        }
                    }
                    .navigationSplitViewColumnWidth(min: 250, ideal: 250, max: 400)
                }
            }
            } else {
                // Two-column layout for other views
            NavigationSplitView {
                // Sidebar
                WalletSidebar(selectedItem: $selectedItem)
                    .navigationSplitViewColumnWidth(min: 250, ideal: 250)
            } detail: {
                // Content view for non-activity items
                switch selectedItem {
                case .balance:
                    BalanceView()
                case .send:
                    SendView(
                        prefilledRecipient: prefilledSendAddress,
                        prefilledContact: prefilledSendContact
                    )
                case .receive:
                    ReceiveView()
                case .contacts:
                    EmptyView() // This case shouldn't be reached now
                case .tags:
                    TagsView(onNavigateToActivity: navigateToFilteredActivityByTag)
                case .settings:
                    SettingsView(onWalletDeleted: onWalletDeleted)
                case .data:
                    EmptyView() // This case shouldn't be reached now
                case .activity:
                    EmptyView() // This case shouldn't be reached
                }
            }
            }
        }
        .sheet(item: $editingContact) { contact in
            ContactEditor(
                editingContact: contact,
                onSave: { updatedContact in
                    Task {
                        await updateContact(updatedContact)
                    }
                    editingContact = nil
                },
                onCancel: {
                    editingContact = nil
                }
            )
            .environment(manager)
            .environment(manager.contactServiceForEnvironment)
            .frame(width: 500, height: 700)
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            // Clear activity filter when navigating away from activity
            if oldValue == .activity && newValue != .activity {
                activityFilterContact = nil
            }
            // Clear send prefilled data when navigating away from send
            if oldValue == .send && newValue != .send {
                prefilledSendAddress = nil
                prefilledSendContact = nil
            }
        }
    }
}



#Preview {
    WalletView(onWalletDeleted: nil)
        .environment(WalletManager(useMock: true))
        .modelContainer(for: [TransactionModel.self, ArkBalanceModel.self], inMemory: true)
}
