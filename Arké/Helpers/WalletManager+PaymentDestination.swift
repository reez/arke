//
//  WalletManager+PaymentDestination.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/17/25.
//

import Foundation

/// Convenience extension to create PaymentContext from WalletManager state
extension WalletManager {
    
    /// Creates a PaymentContext from current wallet state
    func createPaymentContext(
        preferences: PaymentDestinationSelector.PaymentPreferences = .default
    ) -> PaymentDestinationSelector.PaymentContext {
        PaymentDestinationSelector.PaymentContext(
            arkBalance: arkBalance?.spendableSat,
            bitcoinBalance: onchainBalance?.trustedSpendableSat,
            networkConfig: networkConfig ?? NetworkConfig.signet,
            userPreferences: preferences,
            arkServerConnected: true, // TODO: Add actual server connectivity check
            hasLightningCapability: true // TODO: Add actual Lightning capability check
        )
    }
}
