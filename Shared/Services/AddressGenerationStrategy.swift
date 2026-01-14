//
//  AddressGenerationStrategy.swift
//  Ark wallet prototype
//
//  Created by Assistant on 1/12/26.
//

import Foundation

/// Strategy used to generate an address
enum AddressGenerationStrategy: String, Codable {
    case auto = "auto"  // System-generated automatically
    case userRequested = "user_request"  // User explicitly requested new address
    case discovered = "discovered"  // Discovered during wallet sync/restore
    
    var displayName: String {
        switch self {
        case .auto: return "Auto-generated"
        case .userRequested: return "User Requested"
        case .discovered: return "Discovered"
        }
    }
}
