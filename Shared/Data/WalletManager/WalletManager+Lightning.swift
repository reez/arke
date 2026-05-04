//
//  WalletManager+Lightning.swift
//  Arké
//
//  Lightning Network operations
//  Invoice generation, payment, and status checking via the Ark protocol
//

import Foundation
import Bark

extension WalletManager {
    
    // MARK: - Lightning Invoice Operations
    
    /// Generate a Lightning invoice for receiving payment
    func getLightningInvoice(amount: Int) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getLightningInvoice(amount: amount)
    }
    
    // MARK: - Lightning Payment Operations
    
    /// Pay a Lightning invoice with optional amount (for invoices that may already include an amount)
    func payLightningInvoice(invoice: String, amountSats: UInt64?) async throws  -> LightningSend {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.payLightningInvoice(invoice: invoice, amountSats: amountSats)
    }
    
    /// Pay a Lightning address (user@domain format)
    func payLightningAddress(lightningAddress: String, amountSats: UInt64, comment: String?) async throws {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        _ = try await wallet.payLightningAddress(lightningAddress: lightningAddress, amountSats: amountSats, comment: comment)
    }
    
    /// Pay a BOLT12 Lightning offer
    func payLightningOffer(offer: String, amountSats: UInt64?) async throws {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        _ = try await wallet.payLightningOffer(offer: offer, amountSats: amountSats)
    }
    
    // MARK: - Lightning Status & Management
    
    /// Get the current status of a Lightning invoice
    func getLightningInvoiceStatus(invoice: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getLightningInvoiceStatus(invoice: invoice)
    }
    
    /// List all Lightning invoices
    func listLightningInvoices() async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.listLightningInvoices()
    }
    
    
    /// Claim a Lightning invoice
    func claimLightningInvoice(invoice: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.claimLightningInvoice(invoice: invoice)
    }
}
