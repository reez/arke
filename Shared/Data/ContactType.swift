//
//  ContactType.swift
//  Ark wallet prototype
//
//  Created by Assistant on 1/25/26.
//

import Foundation

enum ContactType: String, Codable {
    case standard      // Regular user-created contact
    case faucet        // Signet faucet contact (Faucetto Signetto)
    case selfContact   // Reserved for future use - user's own contact info
    case developer     // Reserved for future use - developer/donation contact
    
    /// Whether this is a special system-managed contact type
    var isSpecialType: Bool {
        self != .standard
    }
    
    /// Whether contacts of this type can be edited by the user
    var canBeEdited: Bool {
        self == .standard
    }
    
    /// Whether contacts of this type can be deleted by the user
    var canBeDeleted: Bool {
        self == .standard
    }
    
    /// Human-readable display name for the contact type
    var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .faucet:
            return "Faucet"
        case .selfContact:
            return "Self Contact"
        case .developer:
            return "Developer"
        }
    }
}
