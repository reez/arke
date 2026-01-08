//
//  MovementDestination.swift
//  Ark wallet prototype
//
//  Movement destination with payment method information
//

import Foundation

/// Represents a destination in a movement
/// Note: Current API limitation - amounts per destination are not provided by the FFI
struct MovementDestination: Codable, Hashable, Sendable {
    let paymentMethod: PaymentMethod
    let address: String  // Original string for display
    
    // MARK: - Factory Methods
    
    /// Create from a plain address string (current API format)
    /// Uses heuristic detection to determine payment method type
    static func fromAddress(_ address: String) -> MovementDestination {
        MovementDestination(
            paymentMethod: PaymentMethod.detect(from: address),
            address: address
        )
    }
    
    // MARK: - Display Helpers
    
    /// Short display version of the address (truncated for UI)
    var shortAddress: String {
        if address.count > 20 {
            return "\(address.prefix(10))...\(address.suffix(10))"
        }
        return address
    }
    
    /// Very short version for compact display
    var veryShortAddress: String {
        if address.count > 16 {
            return "\(address.prefix(8))...\(address.suffix(6))"
        }
        return address
    }
    
    /// Display text with type and shortened address
    var displayText: String {
        "\(paymentMethod.shortDisplayType): \(shortAddress)"
    }
    
    /// Full display text with type and full address
    var fullDisplayText: String {
        "\(paymentMethod.displayType): \(address)"
    }
    
    // MARK: - Type Checks
    
    /// Whether this destination is a Lightning payment
    var isLightning: Bool {
        paymentMethod.isLightning
    }
    
    /// Whether this destination is an onchain payment
    var isOnchain: Bool {
        paymentMethod.isOnchain
    }
    
    /// Whether this destination is an Ark offchain payment
    var isArkOffchain: Bool {
        paymentMethod.isArkOffchain
    }
}
