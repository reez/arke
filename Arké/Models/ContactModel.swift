//
//  ContactModel.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/04/25.
//

import SwiftUI
import SwiftData

struct ContactModel: Identifiable, Hashable, Codable {
    let id: UUID
    let cachedName: String
    let notes: String?
    let avatarData: Data?
    let createdAt: Date
    let updatedAt: Date
    
    // Native contact integration
    let nativeContactID: String?           // CNContact.identifier for linked native contacts
    let lastSyncedFromNative: Date?        // When we last imported/refreshed from native contact
    
    // Transaction statistics (optional for backward compatibility)
    let transactionCount: Int?
    let sentAmount: Int?
    let receivedAmount: Int?
    
    // Addresses associated with this contact
    let addresses: [ContactAddressModel]
    
    init(id: UUID = UUID(), cachedName: String, notes: String? = nil, avatarData: Data? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), nativeContactID: String? = nil, lastSyncedFromNative: Date? = nil, transactionCount: Int? = nil, sentAmount: Int? = nil, receivedAmount: Int? = nil, addresses: [ContactAddressModel] = []) {
        self.id = id
        self.cachedName = cachedName
        self.notes = notes
        self.avatarData = avatarData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.nativeContactID = nativeContactID
        self.lastSyncedFromNative = lastSyncedFromNative
        self.transactionCount = transactionCount
        self.sentAmount = sentAmount
        self.receivedAmount = receivedAmount
        self.addresses = addresses
    }
    
    // Initialize from persistent contact
    init(from persistentContact: PersistentContact) {
        self.id = persistentContact.id
        self.cachedName = persistentContact.cachedName
        self.notes = persistentContact.notes
        self.avatarData = persistentContact.avatarData
        self.createdAt = persistentContact.createdAt
        self.updatedAt = persistentContact.updatedAt
        self.nativeContactID = persistentContact.nativeContactID
        self.lastSyncedFromNative = persistentContact.lastSyncedFromNative
        self.transactionCount = persistentContact.transactionCount
        self.sentAmount = persistentContact.sentAmount
        self.receivedAmount = persistentContact.receivedAmount
        self.addresses = persistentContact.addresses.map { ContactAddressModel(from: $0) }
    }
    
    // Display name (just the cached name for now)
    var displayName: String {
        cachedName.isEmpty ? "Unknown Contact" : cachedName
    }
    
    // Check if this contact is linked to a native contact
    var isLinkedToNativeContact: Bool {
        nativeContactID != nil
    }
    
    // Computed properties for formatted display of transaction statistics
    var formattedTransactionCount: String? {
        guard let count = transactionCount else { return nil }
        return count == 1 ? "1 transaction" : "\(count) transactions"
    }
    
    var formattedSentAmount: String? {
        guard let amount = sentAmount, amount > 0 else { return nil }
        return BitcoinFormatter.formatAccountingAmount(amount, transactionType: .sent)
    }
    
    var formattedReceivedAmount: String? {
        guard let amount = receivedAmount, amount > 0 else { return nil }
        return BitcoinFormatter.formatAccountingAmount(amount, transactionType: .received)
    }
    
    // MARK: - Address-related computed properties
    
    /// Primary address if one exists
    var primaryAddress: ContactAddressModel? {
        addresses.first { $0.isPrimary }
    }
    
    /// Bitcoin addresses
    var bitcoinAddresses: [ContactAddressModel] {
        addresses.filter { $0.format == .bitcoin }
    }
    
    /// Lightning addresses
    var lightningAddresses: [ContactAddressModel] {
        addresses.filter { $0.format == .lightning }
    }
    
    /// Silent payment addresses
    var silentPaymentAddresses: [ContactAddressModel] {
        addresses.filter { $0.format == .silentPayments }
    }
    
    /// Ark addresses
    var arkAddresses: [ContactAddressModel] {
        addresses.filter { $0.format == .ark }
    }
    
    /// BIP-21 payment URIs
    var bip21Addresses: [ContactAddressModel] {
        addresses.filter { $0.format == .bip21 }
    }
    
    /// BIP-353 addresses
    var bip353Addresses: [ContactAddressModel] {
        addresses.filter { $0.format == .bip353 }
    }
    
    /// Count of addresses
    var addressCount: Int {
        addresses.count
    }
    
    /// Get addresses by format
    func addresses(for format: AddressFormat) -> [ContactAddressModel] {
        addresses.filter { $0.format == format }
    }
    
    /// Get addresses compatible with a specific network configuration
    func addressesForNetwork(_ networkConfig: NetworkConfig) -> [ContactAddressModel] {
        addresses.filter { $0.isCompatibleWith(networkConfig) }
    }
    
    /// Check if contact has any addresses
    var hasAddresses: Bool {
        !addresses.isEmpty
    }
    
    /// Get a summary of address types for display
    var addressTypesSummary: String {
        let formats = Set(addresses.map { $0.format })
        if formats.isEmpty {
            return "No addresses"
        } else if formats.count == 1 {
            return formats.first?.displayName ?? "Unknown"
        } else {
            return "\(formats.count) address types"
        }
    }
    
    // Convert to persistent model
    func toPersistentContact() -> PersistentContact {
        let persistentContact = PersistentContact(
            id: self.id,
            cachedName: self.cachedName,
            notes: self.notes,
            avatarData: self.avatarData,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            nativeContactID: self.nativeContactID,
            lastSyncedFromNative: self.lastSyncedFromNative
        )
        
        // Note: Addresses should be managed separately through the ContactAddressService
        // to avoid complex relationship management during contact creation
        
        return persistentContact
    }
    
    // Create a new contact model with updated timestamp
    func withUpdatedTimestamp() -> ContactModel {
        return ContactModel(
            id: self.id,
            cachedName: self.cachedName,
            notes: self.notes,
            avatarData: self.avatarData,
            createdAt: self.createdAt,
            updatedAt: Date(),
            nativeContactID: self.nativeContactID,
            lastSyncedFromNative: self.lastSyncedFromNative,
            transactionCount: self.transactionCount,
            sentAmount: self.sentAmount,
            receivedAmount: self.receivedAmount,
            addresses: self.addresses
        )
    }
}
