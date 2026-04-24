//
//  UserProfile.swift
//  Arké
//
//  Created by Christoph on 3/5/26.
//

import SwiftUI
import SwiftData

/// Represents the user's personal profile information
/// Used for personalization features like the Tilt-to-Pay overlay
@Model
final class UserProfile {
    /// Display name for the user
    var name: String = ""
    
    /// Profile photo as image data (JPEG/PNG)
    var avatarData: Data?
    
    /// When this profile was created
    var createdAt: Date = Date()
    
    /// When this profile was last updated
    var updatedAt: Date = Date()
    
    init(name: String = "", avatarData: Data? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.name = name
        self.avatarData = avatarData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Update the profile with new information
    func update(name: String, avatarData: Data?) {
        self.name = name
        self.avatarData = avatarData
        self.updatedAt = Date()
    }
    
    /// Check if profile has been configured
    var isConfigured: Bool {
        !name.isEmpty || avatarData != nil
    }
}
