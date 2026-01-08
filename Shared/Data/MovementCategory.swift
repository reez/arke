//
//  MovementCategory.swift
//  Ark wallet prototype
//
//  Categorization system for movements based on subsystem
//

import Foundation

/// High-level categorization of movements based on subsystem
enum MovementCategory: String, Codable, CaseIterable, Sendable {
    case offchainTransfer = "offchain_transfer"  // bark.arkoor send/receive
    case boarding = "boarding"                   // bark.board
    case exit = "exit"                          // bark.exit
    case lightningSend = "lightning_send"       // bark.lightning_send
    case lightningReceive = "lightning_receive" // bark.lightning_receive
    case offboarding = "offboarding"            // bark.round offboard
    case onchainSend = "onchain_send"          // bark.round send_onchain
    case refresh = "refresh"                    // bark.round refresh
    case unknown = "unknown"
    
    // MARK: - Display
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .offchainTransfer: return "Offchain Transfer"
        case .boarding: return "Boarding"
        case .exit: return "Exit"
        case .lightningSend: return "Lightning Send"
        case .lightningReceive: return "Lightning Receive"
        case .offboarding: return "Offboarding"
        case .onchainSend: return "Onchain Send"
        case .refresh: return "Refresh"
        case .unknown: return "Unknown"
        }
    }
    
    /// Short display name for compact UI
    var shortDisplayName: String {
        switch self {
        case .offchainTransfer: return "Ark Transfer"
        case .boarding: return "Board"
        case .exit: return "Exit"
        case .lightningSend: return "LN Send"
        case .lightningReceive: return "LN Receive"
        case .offboarding: return "Offboard"
        case .onchainSend: return "Onchain"
        case .refresh: return "Refresh"
        case .unknown: return "?"
        }
    }
    
    /// Description of what this category represents
    var description: String {
        switch self {
        case .offchainTransfer:
            return "Offchain transfer between Ark users"
        case .boarding:
            return "Moving funds from Bitcoin onchain to Ark"
        case .exit:
            return "Unilateral exit from Ark to Bitcoin onchain"
        case .lightningSend:
            return "Sending payment via Lightning Network"
        case .lightningReceive:
            return "Receiving payment via Lightning Network"
        case .offboarding:
            return "Moving entire VTXOs from Ark to Bitcoin onchain"
        case .onchainSend:
            return "Sending specific amount from Ark to Bitcoin onchain"
        case .refresh:
            return "Consolidating and refreshing VTXO lifetimes"
        case .unknown:
            return "Unknown operation"
        }
    }
    
    // MARK: - Icons
    
    /// System icon name (SF Symbols)
    var icon: String {
        switch self {
        case .offchainTransfer: return "arrow.left.arrow.right"
        case .boarding: return "repeat"
        case .exit: return "arrow.up.forward"
        case .lightningSend: return "bolt.fill"
        case .lightningReceive: return "bolt.fill"
        case .offboarding: return "repeat"
        case .onchainSend: return "link"
        case .refresh: return "arrow.clockwise"
        case .unknown: return "questionmark"
        }
    }
    
    /// Icon color name for theming
    var iconColorName: String {
        switch self {
        case .offchainTransfer: return "purple"
        case .boarding: return "gray"
        case .exit: return "orange"
        case .lightningSend: return "yellow"
        case .lightningReceive: return "yellow"
        case .offboarding: return "gray"
        case .onchainSend: return "blue"
        case .refresh: return "gray"
        case .unknown: return "gray"
        }
    }
    
    // MARK: - Behavior
    
    /// Whether this category should be shown in transaction history by default
    var showInHistoryByDefault: Bool {
        switch self {
        case .refresh:
            // Refresh operations are maintenance, might want to hide by default
            return false
        default:
            return true
        }
    }
    
    /// Whether this operation involves Lightning Network
    var isLightning: Bool {
        switch self {
        case .lightningSend, .lightningReceive:
            return true
        default:
            return false
        }
    }
    
    /// Whether this operation involves onchain Bitcoin
    var isOnchain: Bool {
        switch self {
        case .boarding, .exit, .offboarding, .onchainSend:
            return true
        default:
            return false
        }
    }
    
    /// Whether this operation is offchain (Ark-to-Ark)
    var isOffchain: Bool {
        switch self {
        case .offchainTransfer:
            return true
        default:
            return false
        }
    }
    
    /// Whether this is a maintenance operation
    var isMaintenance: Bool {
        switch self {
        case .refresh:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Detection
    
    /// Determine category from subsystem name and kind
    /// - Parameters:
    ///   - subsystemName: The subsystem name (e.g., "bark.arkoor")
    ///   - subsystemKind: The subsystem kind (e.g., "send", "receive")
    /// - Returns: The detected movement category
    static func from(subsystemName: String, subsystemKind: String) -> MovementCategory {
        switch subsystemName {
        case "bark.arkoor":
            return .offchainTransfer
            
        case "bark.board":
            return .boarding
            
        case "bark.exit":
            return .exit
            
        case "bark.lightning_send":
            return .lightningSend
            
        case "bark.lightning_receive":
            return .lightningReceive
            
        case "bark.round":
            // Differentiate based on kind
            switch subsystemKind {
            case "offboard":
                return .offboarding
            case "send_onchain":
                return .onchainSend
            case "refresh":
                return .refresh
            default:
                return .unknown
            }
            
        default:
            return .unknown
        }
    }
}

// MARK: - Filter Groups

extension MovementCategory {
    /// Groups of categories for filtering UI
    enum FilterGroup: String, CaseIterable {
        case all = "All"
        case offchain = "Offchain"
        case lightning = "Lightning"
        case onchain = "Onchain"
        case maintenance = "Maintenance"
        
        var displayName: String { rawValue }
        
        func matches(_ category: MovementCategory) -> Bool {
            switch self {
            case .all:
                return true
            case .offchain:
                return category.isOffchain
            case .lightning:
                return category.isLightning
            case .onchain:
                return category.isOnchain
            case .maintenance:
                return category.isMaintenance
            }
        }
    }
}
