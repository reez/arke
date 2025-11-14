//
//  BitcoinFormatSettings.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/13/25.
//

import Foundation

enum BitcoinAmountFormat: String, Codable, CaseIterable {
    case bip177
    case fullBitcoin
    case satoshis
    case corn
    case unicorn
    
    var displayName: String {
        switch self {
        case .bip177:
            return "₿-only"
        case .fullBitcoin:
            return "Bitcoin"
        case .satoshis:
            return "Satoshis"
        case .corn:
            return "Corn"
        case .unicorn:
            return "Unicorn"
        }
    }
    
    var exampleFormat: String {
        switch self {
        case .bip177:
            return "₿ 10,000,000" // Or "10,000,000 ₿"
        case .fullBitcoin:
            return "₿ 0.1" // Or "0.1 ₿" depending on locale
        case .satoshis:
            return "10,000,000 sats" // Grouping varies by locale
        case .corn:
            return "🌽 0.1"
        case .unicorn:
            return "🦄 0.1"
        }
    }
}

extension BitcoinAmountFormat {
    static let userDefaultsKey = "bitcoinAmountFormat"
    static let defaultFormat: BitcoinAmountFormat = .bip177
}
