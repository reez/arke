//
//  ContactDetailView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
import ArkeUI

struct ContactDetailView_iOS: View {
    let contact: ContactModel
    let onSendToAddress: (ContactAddressModel) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onNavigateToActivity: (ContactModel?) -> Void
    
    @Environment(\.serviceContainer) private var serviceContainer
    @Environment(\.dismiss) private var dismiss
    
    @Environment(WalletManager.self) private var walletManager
    
    // MARK: - ViewModel
    
    @State private var viewModel: ContactDetailViewModel?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        contentView
            .task(id: contact.id) {                
                // Initialize ViewModel as soon as environment is available
                viewModel = ContactDetailViewModel(
                    contact: contact,
                    serviceContainer: serviceContainer
                )
            }
    }
    
    @ViewBuilder
    private var contentView: some View {
        listContent
            .toolbar {
                if contact.contactType.canBeEdited {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") {
                            onEdit()
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete Contact",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(contact.displayName)?")
            }
            .sheet(isPresented: contactImportSheetBinding) {
                contactImportSheetView
            }
            .alert("Contact Link", isPresented: alertBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                if let alertMessage = viewModel?.alertMessage {
                    Text(alertMessage)
                }
            }
    }
    
    private var listContent: some View {
        List {
            headerSection
            
            // Signet Faucet section (only for faucet contacts on signet network)
            if contact.contactType == .faucet && isSignetNetwork {
                signetFaucetSection
            }
            
            if viewModel?.hasTransactionData == true {
                transactionSummarySection
            }
            
            addressesSection
            
            if let notes = contact.notes, !notes.isEmpty {
                notesSection(notes)
            }
            
            if let viewModel, contact.contactType.canBeEdited {
                contactDetailsSection(viewModel: viewModel)
            }
            
            if contact.contactType.canBeDeleted {
                managementSection
            }
        }
    }
    
    private var headerSection: some View {
        Section {
            ContactHeaderView(contact: contact)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .listRowBackground(Color.clear)
    }
    
    private var transactionSummarySection: some View {
        Section {
            ContactTransactionSummaryView(
                contact: contact,
                onViewActivity: {
                    onNavigateToActivity(contact) // Filter by this contact
                }
            )
        }
    }
    
    private var addressesSection: some View {
        Section {
            ContactAddressesSection(
                contact: contact,
                onSendToAddress: onSendToAddress
            )
        }
    }
    
    private func notesSection(_ notes: String) -> some View {
        Section("Notes") {
            Text(notes)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    private func contactDetailsSection(viewModel: ContactDetailViewModel) -> some View {
        Section {
            ContactDetailsDisclosure(
                contact: contact,
                onRefreshFromNativeContact: {
                    Task {
                        await viewModel.handleRefreshFromNativeContact()
                    }
                },
                onUnlinkNativeContact: {
                    Task {
                        await viewModel.handleUnlinkFromNativeContact()
                    }
                },
                onLinkNativeContact: {
                    viewModel.handleLinkToNativeContact()
                }
            )
        }
    }
    
    private var managementSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Contact", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var contactImportSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showingContactImport ?? false },
            set: { if let viewModel { viewModel.showingContactImport = $0 } }
        )
    }
    
    private var contactImportSheetView: some View {
        NavigationStack {
            ContactImportSheet(
                onSelect: { importedData in
                    Task {
                        await viewModel?.handleContactImportSelection(importedData)
                    }
                    viewModel?.showingContactImport = false
                },
                onCancel: {
                    viewModel?.showingContactImport = false
                }
            )
        }
        .presentationDetents([.medium, .large])
    }
    
    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showingAlert ?? false },
            set: { if let viewModel { viewModel.showingAlert = $0 } }
        )
    }
    
    // MARK: - Computed Properties
    
    /// Check if we're on signet network
    private var isSignetNetwork: Bool {
        guard let networkConfig = walletManager.networkConfig else { return false }
        return networkConfig.networkType.lowercased() == "signet"
    }
    

    
    // MARK: - Signet Faucet Section
    
    private var signetFaucetSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {                
                // Request button
                faucetRequestButton
                
                // Status message
                if let viewModel, viewModel.showingFaucetAlert {
                    faucetStatusMessage
                }
            }
            .padding(.vertical, 8)
        }
        .listSectionSpacing(15)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var faucetRequestButton: some View {
        Button {
            requestFaucet()
        } label: {
            HStack {
                if viewModel?.isRequestingFaucet == true {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.arkeDark))
                        .controlSize(.small)
                } else {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color.arkeDark)
                }
                Text(viewModel?.isRequestingFaucet == true ? "Requesting..." : "Ask for test bitcoin")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Color.arkeDark)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel?.isRequestingFaucet == true || walletManager.arkAddress.isEmpty)
    }
    
    private var faucetStatusMessage: some View {
        Group {
            if let alertType = viewModel?.faucetAlertType {
                HStack(spacing: 8) {
                    Image(systemName: statusIcon(for: alertType))
                        .foregroundStyle(statusColor(for: alertType))
                    
                    Text(viewModel?.faucetAlertMessage ?? "")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(15)
                .background(statusColor(for: alertType).opacity(0.1))
                .cornerRadius(15)
            }
        }
    }
    
    private func statusIcon(for type: FaucetAlertType) -> String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .rateLimited:
            return "clock.fill"
        case .insufficientFunds:
            return "drop.slash.fill"
        }
    }
    
    private func statusColor(for type: FaucetAlertType) -> Color {
        switch type {
        case .success:
            return .green
        case .error:
            return .red
        case .rateLimited:
            return .orange
        case .insufficientFunds:
            return .yellow
        }
    }
    
    private func requestFaucet() {
        // Use the user's own Ark address
        let address = walletManager.arkAddress
        guard !address.isEmpty else { return }
        
        Task {
            await viewModel?.requestSignetFaucet(toAddress: address) {
                // Navigate to activity view after successful faucet request
                // Don't pass contact to avoid filtering - transaction won't have address info
                onNavigateToActivity(nil)
            }
        }
    }
}

// MARK: - Previews

#Preview("Standard Contact") {
    NavigationStack {
        ContactDetailView_iOS(
            contact: ContactModel(
                cachedName: "John Doe",
                notes: "My Bitcoin contact",
                contactType: .standard,
                transactionCount: 5,
                sentAmount: 25000,
                receivedAmount: 75000,
                addresses: []
            ),
            onSendToAddress: { _ in print("Send to address") },
            onEdit: { print("Edit tapped") },
            onDelete: { print("Delete tapped") },
            onNavigateToActivity: { contact in print("Navigate to activity for \(contact?.displayName ?? "all")") }
        )
    }
    .environment(WalletManager(useMock: true))
    .environment(\.serviceContainer, ServiceContainer.shared)
}

#Preview("Linked to Native Contact") {
    NavigationStack {
        ContactDetailView_iOS(
            contact: ContactModel(
                cachedName: "Jane Smith",
                notes: "Linked to Contacts.app",
                contactType: .standard,
                nativeContactID: "12345",
                lastSyncedFromNative: Date().addingTimeInterval(-7200),
                transactionCount: 12,
                sentAmount: 50000,
                receivedAmount: 125000,
                addresses: []
            ),
            onSendToAddress: { _ in print("Send to address") },
            onEdit: { print("Edit tapped") },
            onDelete: { print("Delete tapped") },
            onNavigateToActivity: { contact in print("Navigate to activity for \(contact?.displayName ?? "all")") }
        )
    }
    .environment(WalletManager(useMock: true))
    .environment(\.serviceContainer, ServiceContainer.shared)
}

#Preview("No Transaction Data") {
    NavigationStack {
        ContactDetailView_iOS(
            contact: ContactModel(
                cachedName: "New Contact",
                notes: "Just added, no transactions yet",
                contactType: .standard,
                addresses: []
            ),
            onSendToAddress: { _ in print("Send to address") },
            onEdit: { print("Edit tapped") },
            onDelete: { print("Delete tapped") },
            onNavigateToActivity: { contact in print("Navigate to activity for \(contact?.displayName ?? "all")") }
        )
    }
    .environment(WalletManager(useMock: true))
    .environment(\.serviceContainer, ServiceContainer.shared)
}
#Preview("System Contact with Faucet") {
    let contactId = UUID()
    let contact = ContactModel(
        id: contactId,
        cachedName: "Signet Faucet",
        notes: "System contact for requesting testnet bitcoin",
        contactType: .faucet,
        addresses: [
            ContactAddressModel(
                address: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
                normalizedAddress: "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
                format: .bitcoin,
                label: "Primary Testnet Address",
                isPrimary: true,
                contactId: contactId,
                network: .signet
            ),
            ContactAddressModel(
                address: "tb1q5y7gze9tqw6fkd8lx3jwqnv7zxr8qlk9ewnxfc",
                normalizedAddress: "tb1q5y7gze9tqw6fkd8lx3jwqnv7zxr8qlk9ewnxfc",
                format: .bitcoin,
                label: "Secondary Testnet Address",
                isPrimary: false,
                contactId: contactId,
                network: .signet
            )
        ]
    )
    
    NavigationStack {
        ContactDetailView_iOS(
            contact: contact,
            onSendToAddress: { _ in print("Send to address") },
            onEdit: { print("Edit tapped") },
            onDelete: { print("Delete tapped") },
            onNavigateToActivity: { contact in print("Navigate to activity for \(contact?.displayName ?? "all")") }
        )
    }
    .environment(WalletManager(useMock: true, networkConfig: .signet))
    .environment(\.serviceContainer, ServiceContainer.shared)
}

