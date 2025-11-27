//
//  ContactAddressModel.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/05/25.
//

import Foundation
import SwiftUI

struct ContactAddressModel: Identifiable, Hashable, Codable {
    let id: UUID
    let address: String
    let normalizedAddress: String
    let format: AddressFormat
    let label: String?
    let isPrimary: Bool
    let contactId: UUID
    let createdAt: Date
    let updatedAt: Date
    
    // Network info (derived from address validation)
    let network: BitcoinNetwork?
    
    // MARK: - Initializers
    
    init(id: UUID = UUID(), address: String, normalizedAddress: String, format: AddressFormat, label: String? = nil, isPrimary: Bool = false, contactId: UUID, network: BitcoinNetwork? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.address = address
        self.normalizedAddress = normalizedAddress
        self.format = format
        self.label = label
        self.isPrimary = isPrimary
        self.contactId = contactId
        self.network = network
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Initialize from payment destination
    init(from destination: PaymentDestination, contactId: UUID, label: String? = nil, isPrimary: Bool = false) {
        self.id = UUID()
        self.address = destination.address
        self.normalizedAddress = destination.address.lowercased()
        self.format = destination.format
        self.network = destination.network
        self.label = label
        self.isPrimary = isPrimary
        self.contactId = contactId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Initialize from persistent address
    init(from persistentAddress: PersistentContactAddress) {
        self.id = persistentAddress.id
        self.address = persistentAddress.address
        self.normalizedAddress = persistentAddress.normalizedAddress
        self.format = persistentAddress.format
        self.label = persistentAddress.label
        self.isPrimary = persistentAddress.isPrimary
        self.contactId = persistentAddress.contact?.id ?? UUID()
        self.network = persistentAddress.network
        self.createdAt = persistentAddress.createdAt
        self.updatedAt = persistentAddress.updatedAt
    }
    
    // MARK: - Computed Properties
    
    /// Display name for the address (label if available, otherwise format name)
    var displayName: String {
        if let label = label, !label.isEmpty {
            return label
        }
        return format.displayName
    }
    
    /// Full display name including network info
    var fullDisplayName: String {
        if let network = network {
            return "\(displayName) (\(network.displayName))"
        }
        return displayName
    }
    
    /// Check if this address supports Bitcoin networks
    var supportsBitcoinNetworks: Bool {
        format.supportsBitcoinNetworks
    }
    
    /// Shortened address for display (first 8 + "..." + last 8 characters)
    var shortAddress: String {
        guard address.count > 16 else { return address }
        let start = address.prefix(8)
        let end = address.suffix(8)
        return "\(start)...\(end)"
    }
    
    // MARK: - Methods
    
    /// Convert to persistent model
    func toPersistentAddress() -> PersistentContactAddress {
        let persistent = PersistentContactAddress(
            id: self.id,
            address: self.address,
            normalizedAddress: self.normalizedAddress,
            format: self.format,
            label: self.label,
            isPrimary: self.isPrimary,
            network: self.network,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
        return persistent
    }
    
    /// Create a new address model with updated timestamp
    func withUpdatedTimestamp() -> ContactAddressModel {
        return ContactAddressModel(
            id: self.id,
            address: self.address,
            normalizedAddress: self.normalizedAddress,
            format: self.format,
            label: self.label,
            isPrimary: self.isPrimary,
            contactId: self.contactId,
            network: self.network,
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }
    
    /// Create a new address model with updated primary status
    func withPrimaryStatus(_ isPrimary: Bool) -> ContactAddressModel {
        return ContactAddressModel(
            id: self.id,
            address: self.address,
            normalizedAddress: self.normalizedAddress,
            format: self.format,
            label: self.label,
            isPrimary: isPrimary,
            contactId: self.contactId,
            network: self.network,
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }
    
    /// Check if this address is compatible with a specific network configuration
    func isCompatibleWith(_ networkConfig: NetworkConfig) -> Bool {
        guard let network = network else {
            // Non-Bitcoin addresses (Lightning, BIP-353) are generally network-agnostic
            return !format.supportsBitcoinNetworks
        }
        return network.matches(networkConfig)
    }
}

// MARK: - CustomStringConvertible
extension ContactAddressModel: CustomStringConvertible {
    var description: String {
        return "\(displayName): \(shortAddress)"
    }
}