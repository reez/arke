//
//  BitcoinFormatSettings.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/13/25.
//

import Foundation

public enum BitcoinAmountFormat: String, Codable, CaseIterable, Sendable {
    case bip177
    case fullBitcoin
    case satoshis
    case corn
    case unicorn
    
    public var displayName: String {
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
    
    public var exampleFormat: String {
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
    public static let userDefaultsKey = "bitcoinAmountFormat"
    public static let defaultFormat: BitcoinAmountFormat = .bip177
}
