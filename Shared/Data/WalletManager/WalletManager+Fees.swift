//
//  WalletManager+Fees.swift
//  Arké
//
//  Fee estimation operations
//  All operations delegate to the wallet's fee estimation methods
//

import Foundation
import Bark

extension WalletManager {
    
    // MARK: - Fee Estimation
    
    /// Estimate the fee for an Arkoor payment
    /// - Parameter amountSats: Amount in satoshis to send
    /// - Returns: Estimated fee in satoshis
    func estimateArkoorPaymentFee(amountSats: UInt64) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateArkoorPaymentFee(amountSats: amountSats)
    }
    
    /// Estimate the fee for boarding funds to Ark
    /// - Parameter amountSats: Amount in satoshis to board
    /// - Returns: Estimated fee in satoshis
    func estimateBoardFee(amountSats: UInt64) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateBoardFee(amountSats: amountSats)
    }
    
    /// Estimate the fee for receiving Lightning payments
    /// - Parameter amountSats: Amount in satoshis to receive
    /// - Returns: Estimated fee in satoshis
    func estimateLightningReceiveFee(amountSats: UInt64) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateLightningReceiveFee(amountSats: amountSats)
    }
    
    /// Estimate the fee for sending Lightning payments
    /// - Parameter amountSats: Amount in satoshis to send
    /// - Returns: Estimated fee in satoshis
    func estimateLightningSendFee(amountSats: UInt64) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateLightningSendFee(amountSats: amountSats)
    }
    
    /// Estimate the fee for offboarding funds from Ark
    /// - Parameters:
    ///   - address: Destination Bitcoin address
    ///   - vtxoIds: Array of VTXO IDs to offboard
    /// - Returns: Estimated fee in satoshis
    func estimateOffboardFee(address: String, vtxoIds: [String]) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateOffboardFee(address: address, vtxoIds: vtxoIds)
    }
    
    /// Estimate the fee for refreshing VTXOs
    /// - Parameter vtxoIds: Array of VTXO IDs to refresh
    /// - Returns: Estimated fee in satoshis
    func estimateRefreshFee(vtxoIds: [String]) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateRefreshFee(vtxoIds: vtxoIds)
    }
    
    /// Estimate the fee for sending an onchain transaction
    /// - Parameters:
    ///   - address: The destination Bitcoin address
    ///   - amountSats: Amount in satoshis to send
    /// - Returns: Estimated fee in satoshis
    func estimateSendOnchainFee(address: String, amountSats: UInt64) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateSendOnchainFee(address: address, amountSats: amountSats)
    }
}
