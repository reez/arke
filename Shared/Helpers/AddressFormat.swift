//
//  AddressFormat.swift
//  Arké
//
//  Created by Christoph on 11/17/25.
//

import Foundation

enum AddressFormat: String, CaseIterable, Codable {
    case bitcoin = "Bitcoin"
    case ark = "Ark"
    case lightning = "Lightning"
    case lightningInvoice = "Lightning Invoice"
    case bolt12 = "BOLT12"
    case bip353 = "BIP-353"
    case bip21 = "BIP-21"
    case silentPayments = "Silent Payments"
    
    var displayName: String {
        switch self {
        case .bitcoin:
            return "Bitcoin address"
        case .ark:
            return "Ark address"
        case .lightning:
            return "Lightning address"
        case .lightningInvoice:
            return "Lightning invoice"
        case .bolt12:
            return "Lightning offer"
        case .bip353:
            return "BIP-353 address"
        case .bip21:
            return "BIP-21 payment URI"
        case .silentPayments:
            return "Silent payments address"
        }
    }
    
    var simplifiedDisplayName: String {
        switch self {
        case .bitcoin:
            return "Savings (Bitcoin)"
        case .ark:
            return "Payments (Ark)"
        case .lightning:
            return "Payments (Lightning)"
        case .lightningInvoice:
            return "Payments (Lightning)"
        case .bolt12:
            return "Payments (Lightning)"
        case .bip353:
            return "BIP-353 address"
        case .bip21:
            return "BIP-21 payment URI"
        case .silentPayments:
            return "Savings (Silent payments)"
        }
    }
    
    var supportsBitcoinNetworks: Bool {
        switch self {
        case .bitcoin, .silentPayments, .bip21, .ark:
            return true
        case .lightning, .lightningInvoice, .bolt12, .bip353:
            return false
        }
    }
}
