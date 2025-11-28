//
//  WalletConfiguration.swift
//  Arké
//
//  Created by Christoph on 11/28/25.
//

import SwiftData
import Foundation

@Model
class WalletConfiguration {
    var id: UUID = UUID()
    
    /// PBKDF2 hash of the mnemonic (for validation across devices)
    /// This is NOT the mnemonic itself - it's a one-way hash
    var mnemonicHash: String = ""
    
    /// When the wallet was first created
    var createdAt: Date = Date()
    
    /// Last time the wallet was accessed
    var lastAccessedAt: Date = Date()
    
    /// App version when wallet was created
    var createdWithVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    init(
        id: UUID = UUID(),
        mnemonicHash: String,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        createdWithVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    ) {
        self.id = id
        self.mnemonicHash = mnemonicHash
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.createdWithVersion = createdWithVersion
    }
}
