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
    
    init(id: UUID = UUID(), cachedName: String, notes: String? = nil, avatarData: Data? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.cachedName = cachedName
        self.notes = notes
        self.avatarData = avatarData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Initialize from persistent contact
    init(from persistentContact: PersistentContact) {
        self.id = persistentContact.id
        self.cachedName = persistentContact.cachedName
        self.notes = persistentContact.notes
        self.avatarData = persistentContact.avatarData
        self.createdAt = persistentContact.createdAt
        self.updatedAt = persistentContact.updatedAt
    }
    
    // Display name (just the cached name for now)
    var displayName: String {
        cachedName.isEmpty ? "Unknown Contact" : cachedName
    }
    
    // Convert to persistent model
    func toPersistentContact() -> PersistentContact {
        return PersistentContact(
            id: self.id,
            cachedName: self.cachedName,
            notes: self.notes,
            avatarData: self.avatarData,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
    
    // Create a new contact model with updated timestamp
    func withUpdatedTimestamp() -> ContactModel {
        return ContactModel(
            id: self.id,
            cachedName: self.cachedName,
            notes: self.notes,
            avatarData: self.avatarData,
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }
}
