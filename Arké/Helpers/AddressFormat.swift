//
//  AddressFormat.swift
//  Arké
//
//  Created by Christoph on 11/17/25.
//

import Foundation

enum AddressFormat: String, CaseIterable, Codable {
    case bitcoin = "Bitcoin"
    case silentPayments = "Silent Payments"
    case ark = "Ark"
    case lightning = "Lightning"
    case lightningInvoice = "Lightning Invoice"
    case bip353 = "BIP-353"
    case bip21 = "BIP-21"
    
    var displayName: String {
        switch self {
        case .bitcoin:
            return "Bitcoin address"
        case .silentPayments:
            return "Silent payments address"
        case .ark:
            return "Ark address"
        case .lightning:
            return "Lightning address"
        case .lightningInvoice:
            return "Lightning invoice"
        case .bip353:
            return "BIP-353 address"
        case .bip21:
            return "BIP-21 payment URI"
        }
    }
    
    var supportsBitcoinNetworks: Bool {
        switch self {
        case .bitcoin, .silentPayments, .bip21, .ark:
            return true
        case .lightning, .lightningInvoice, .bip353:
            return false
        }
    }
}
