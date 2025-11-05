//
//  ContactAddressEditor.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/5/25.
//

import SwiftUI
import AppKit

struct ContactAddressEditor: View {
    
    // MARK: - Properties
    
    /// The contact this address belongs to
    let contact: ContactModel
    
    /// The address being edited (nil for new address)
    let editingAddress: ContactAddressModel?
    
    /// Callback when address is saved
    let onSave: () -> Void
    
    /// Callback when editing is cancelled
    let onCancel: () -> Void
    
    /// Address service for validation and operations
    @Environment(WalletManager.self) private var walletManager
    
    // MARK: - Form State
    
    @State private var addressText: String = ""
    @State private var label: String = ""
    @State private var isPrimary: Bool = false
    
    // MARK: - UI State
    
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var validationResult: ParsedAddress?
    
    // MARK: - Validation
    
    private var trimmedAddress: String {
        addressText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isValidAddress: Bool {
        validationResult != nil
    }
    
    private var canSave: Bool {
        isValidAddress && !trimmedAddress.isEmpty && !isLoading
    }
    
    private var isEditing: Bool {
        editingAddress != nil
    }
    
    // MARK: - Initialization
    
    init(
        contact: ContactModel,
        editingAddress: ContactAddressModel? = nil,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.contact = contact
        self.editingAddress = editingAddress
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Form Fields
                    formSection
                    
                    // Validation Info
                    if let validationResult = validationResult {
                        validationSection(validationResult)
                    }
                    
                    // Error Section
                    if let errorMessage = errorMessage {
                        errorSection(errorMessage)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Address" : "Add Address")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveAddress()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            setupInitialState()
        }
        .onChange(of: addressText) { _, newValue in
            validateAddress(newValue)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ContactAvatarView(contact: contact, size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(isEditing ? "Edit Address" : "Add New Address")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    private var formSection: some View {
        VStack(spacing: 16) {
            // Address Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Address")
                    .font(.headline)
                    .fontWeight(.medium)
                
                TextField("Enter Bitcoin address, Lightning address, or BIP-353 name", text: $addressText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .font(.body.monospaced())
                    .disabled(isEditing) // Don't allow editing the address itself
                
                if !trimmedAddress.isEmpty && !isValidAddress {
                    Label("Invalid address format", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Label Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Label (Optional)")
                    .font(.headline)
                    .fontWeight(.medium)
                
                TextField("Enter a label for this address", text: $label)
                    .textFieldStyle(.roundedBorder)
                
                Text("If left empty, the address format will be used as the label")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Primary Toggle
            Toggle("Set as primary address", isOn: $isPrimary)
                .font(.headline)
                .fontWeight(.medium)
        }
    }
    
    private func validationSection(_ parsed: ParsedAddress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Address Information")
                .font(.headline)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Format:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(parsed.format.displayName)
                        .fontWeight(.medium)
                }
                
                if let network = parsed.network {
                    HStack {
                        Text("Network:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(network.displayName)
                            .fontWeight(.medium)
                            .foregroundColor(network == .mainnet ? .green : .orange)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Actions
    
    private func setupInitialState() {
        if let editingAddress = editingAddress {
            addressText = editingAddress.address
            label = editingAddress.label ?? ""
            isPrimary = editingAddress.isPrimary
            validateAddress(editingAddress.address)
        }
    }
    
    private func validateAddress(_ address: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            validationResult = nil
            return
        }
        
        validationResult = walletManager.parseAddress(trimmed)
    }
    
    private func saveAddress() async {
        guard canSave else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let finalLabel = trimmedLabel.isEmpty ? nil : trimmedLabel
            
            if let editingAddress = editingAddress {
                // Update existing address
                let updatedAddress = ContactAddressModel(
                    id: editingAddress.id,
                    address: editingAddress.address,
                    normalizedAddress: editingAddress.normalizedAddress,
                    format: editingAddress.format,
                    label: finalLabel,
                    isPrimary: isPrimary,
                    contactId: editingAddress.contactId,
                    network: editingAddress.network,
                    createdAt: editingAddress.createdAt,
                    updatedAt: Date()
                )
                
                try await walletManager.updateAddress(updatedAddress)
            } else {
                // Create new address
                _ = try await walletManager.validateAndCreateAddress(
                    trimmedAddress,
                    for: contact.id,
                    label: finalLabel,
                    isPrimary: isPrimary
                )
            }
            
            onSave()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    ContactAddressEditor(
        contact: ContactModel(
            cachedName: "John Doe"
        ),
        onSave: {},
        onCancel: {}
    )
    .environment(WalletManager(useMock: true))
}
