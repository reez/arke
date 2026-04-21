//
//  BarkWalletFFI+Lightning.swift
//  Arke
//
//  Lightning Network operations: invoices, payments, BOLT11/BOLT12
//  Handles send/receive flows and payment claiming
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark
import os

extension BarkWalletFFI {
    
    // MARK: - Lightning Payment (Send)
    
    func payLightningInvoice(invoice: String, amount: Int) async throws -> String {
        // Pay a Lightning invoice with explicit amount
        // This is for invoices that don't have an amount encoded (amountless invoices)
        
        if isPreview {
            return "Mock: Paid invoice \(invoice) with \(amount) sats (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        // Validate amount
        guard amount > 0 else {
            throw BarkWalletFFIError.configurationError("Amount must be greater than 0")
        }
        
        // Convert Int to UInt64 for FFI
        let amountSats = UInt64(amount)
        
        Self.logger.debug("Paying Lightning invoice via FFI, Invoice: \(String(invoice.prefix(30)))..., Amount: \(amount) sats")
        
        do {
            // Call FFI payLightningInvoice with explicit amount
            let result = try await wallet.payLightningInvoice(
                invoice: invoice,
                amountSats: amountSats
            )
            
            if let preimage = result.preimage {
                Self.logger.info("Lightning payment successful, Paid invoice: \(result.invoice), Preimage: \(String(preimage.prefix(16)))...")
            } else {
                Self.logger.info("Lightning payment successful, Paid invoice: \(result.invoice), Preimage: not available")
            }
            
            // Return result string (amount not in result, use input amount)
            return "Successfully paid \(amount) sats to Lightning invoice"
            
        } catch let error as BarkError {
            Self.logger.error("FFI Error paying Lightning invoice: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to pay Lightning invoice: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error paying Lightning invoice: \(error)")
            throw error
        }
    }
    
    func payLightningInvoice(invoice: String, amount: Int?) async throws -> String {
        // Pay a Lightning invoice with optional amount
        // If amount is provided, use it; otherwise invoice should have amount encoded
        
        if isPreview {
            if let amount = amount {
                return "Mock: Paid invoice with \(amount) sats (preview mode)"
            } else {
                return "Mock: Paid invoice with encoded amount (preview mode)"
            }
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        // Validate amount if provided
        if let amount = amount {
            guard amount > 0 else {
                throw BarkWalletFFIError.configurationError("Amount must be greater than 0")
            }
        }
        
        // Convert optional Int to optional UInt64 for FFI
        let amountSats: UInt64? = amount.map { UInt64($0) }
        
        if let amount = amount {
            Self.logger.debug("Paying Lightning invoice via FFI, Invoice: \(String(invoice.prefix(30)))..., Amount: \(amount) sats (explicit)")
        } else {
            Self.logger.debug("Paying Lightning invoice via FFI, Invoice: \(String(invoice.prefix(30)))..., Amount: from invoice")
        }
        
        do {
            // Call FFI payLightningInvoice with optional amount
            let result = try await wallet.payLightningInvoice(
                invoice: invoice,
                amountSats: amountSats
            )
            
            if let preimage = result.preimage {
                Self.logger.info("Lightning payment successful, Paid invoice: \(result.invoice), Preimage: \(String(preimage.prefix(16)))...")
            } else {
                Self.logger.info("Lightning payment successful, Paid invoice: \(result.invoice), Preimage: not available")
            }
            
            // Return result string
            if let amt = amount {
                return "Successfully paid \(amt) sats to Lightning invoice"
            } else {
                return "Successfully paid Lightning invoice"
            }
            
        } catch let error as BarkError {
            Self.logger.error("FFI Error paying Lightning invoice: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to pay Lightning invoice: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error paying Lightning invoice: \(error)")
            throw error
        }
    }
    
    // MARK: - Lightning Invoice Generation (Receive)
    
    func getLightningInvoice(amount: Int) async throws -> String {
        // Generate a Lightning invoice for receiving payment
        
        if isPreview {
            return "lnbc\(amount)0n1preview..."
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        // Validate amount
        guard amount > 0 else {
            throw BarkWalletFFIError.configurationError("Amount must be greater than 0")
        }
        
        // Convert Int to UInt64 for FFI
        let amountSats = UInt64(amount)
        
        Self.logger.debug("Generating Lightning invoice via FFI, Amount: \(amount) sats")
        
        do {
            // Call FFI bolt11Invoice method
            let result = try await wallet.bolt11Invoice(amountSats: amountSats)
            
            Self.logger.info("Lightning invoice generated, Amount: \(result.amountSats) sats, Invoice: \(String(result.invoice.prefix(30)))...")
            
            // Return the invoice string
            return result.invoice
            
        } catch let error as BarkError {
            Self.logger.error("FFI Error generating Lightning invoice: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to generate Lightning invoice: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error generating Lightning invoice: \(error)")
            throw error
        }
    }
    
    func getLightningInvoiceStatus(invoice: String) async throws -> String {
        // Check the status of a Lightning invoice
        
        if isPreview {
            return "Mock: Invoice status - pending (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        Self.logger.debug("Checking Lightning invoice status via FFI, Invoice: \(String(invoice.prefix(30)))...")
        
        do {
            // Call FFI pendingLightningReceives method
            let pendingReceives = try await wallet.pendingLightningReceives()
            
            // Find the invoice in pending receives
            if let receiveStatus = pendingReceives.first(where: { $0.invoice == invoice }) {
                Self.logger.info("Found invoice in pending receives")
                
                // Build status string
                var status = "Invoice Status:\n"
                status += "  Payment Hash: \(receiveStatus.paymentHash)\n"
                status += "  Amount: \(receiveStatus.amountSats) sats\n"
                status += "  Has HTLC VTXOs: \(receiveStatus.hasHtlcVtxos ? String(localized: "button_yes") : String(localized: "button_no"))\n"
                status += "  Preimage Revealed: \(receiveStatus.preimageRevealed ? String(localized: "button_yes") : String(localized: "button_no"))\n"
                
                if receiveStatus.hasHtlcVtxos && !receiveStatus.preimageRevealed {
                    status += "  Status: Pending (ready to claim)"
                } else if receiveStatus.preimageRevealed {
                    status += "  Status: Claimed"
                } else {
                    status += "  Status: Waiting for payment"
                }
                
                return status
            } else {
                // Invoice not found in pending receives
                // It might be already claimed or never created
                Self.logger.warning("Invoice not found in pending receives")
                return "Invoice not found in pending receives. It may be already claimed or not yet paid."
            }
            
        } catch let error as BarkError {
            Self.logger.error("FFI Error checking invoice status: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to check invoice status: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error checking invoice status: \(error)")
            throw error
        }
    }
    
    // MARK: - Invoice Status & Management
    
    func listLightningInvoices() async throws -> String {
        // List all Lightning invoices
        
        if isPreview {
            return "[]"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        Self.logger.debug("Listing Lightning invoices via FFI...")
        
        do {
            // Call FFI pendingLightningReceives method
            let pendingReceives = try await wallet.pendingLightningReceives()
            
            Self.logger.info("Retrieved \(pendingReceives.count) pending Lightning receives")
            
            // Convert to JSON array
            let invoiceList: [[String: Any]] = pendingReceives.map { receive in
                return [
                    "payment_hash": receive.paymentHash,
                    "invoice": receive.invoice,
                    "amount_sats": receive.amountSats,
                    "has_htlc_vtxos": receive.hasHtlcVtxos,
                    "preimage_revealed": receive.preimageRevealed,
                    "status": receive.hasHtlcVtxos && !receive.preimageRevealed ? "ready_to_claim" :
                             (receive.preimageRevealed ? "claimed" : "waiting")
                ]
            }
            
            // Convert to JSON string
            let jsonData = try JSONSerialization.data(withJSONObject: invoiceList, options: [.prettyPrinted, .sortedKeys])
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw BarkWalletFFIError.configurationError("Failed to encode invoice list as JSON string")
            }
            
            return jsonString
            
        } catch let error as BarkError {
            Self.logger.error("FFI Error listing invoices: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to list invoices: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error listing invoices: \(error)")
            throw error
        }
    }
    
    // MARK: - Claiming & Balance
    
    func claimLightningInvoice(invoice: String) async throws -> String {
        // Claim a specific paid Lightning invoice
        // FFI uses tryClaimAllLightningReceives() which claims all pending
        
        if isPreview {
            return "Mock: Claimed invoice (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        Self.logger.debug("Claiming Lightning receives via FFI, Note: FFI claims ALL pending receives, not individual invoices")
        
        do {
            // Call FFI tryClaimAllLightningReceives
            // This claims all pending Lightning receives
            let _ = try await wallet.tryClaimAllLightningReceives(wait: true)
            
            Self.logger.info("Lightning receives claimed successfully, All pending receives have been processed")
            
            return "Successfully claimed all pending Lightning receives"
            
        } catch let error as BarkError {
            Self.logger.error("FFI Error claiming Lightning receives: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to claim Lightning receives: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error claiming Lightning receives: \(error)")
            throw error
        }
    }
    
    func payLightningOffer(offer: String, amountSats: UInt64?) async throws -> LightningSend {
        // Pay a BOLT12 lightning offer
        
        if isPreview {
            return LightningSend(invoice: "lnbc...", amountSats: amountSats ?? 0, htlcVtxoCount: 1, preimage: nil)
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        guard amountSats ?? 0 > 0 else {
            throw BarkWalletFFIError.configurationError("Amount must be greater than 0 for BOLT12 offers")
        }
        
        if let amt = amountSats {
            Self.logger.debug("Paying Lightning BOLT12 offer via FFI, Offer: \(String(offer.prefix(30)))..., Amount: \(amt) sats")
        } else {
            Self.logger.debug("Paying Lightning BOLT12 offer via FFI, Offer: \(String(offer.prefix(30)))...")
        }
        
        do {
            let result = try await wallet.payLightningOffer(offer: offer, amountSats: amountSats)
            
            Self.logger.info("Lightning BOLT12 payment initiated, Invoice: \(String(result.invoice.prefix(30)))..., Amount: \(result.amountSats) sats")
            
            return result
            
        } catch let error as BarkError {
            Self.logger.error("FFI Error paying Lightning offer: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to pay Lightning offer: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error paying Lightning offer: \(error)")
            throw error
        }
    }
    
    // MARK: - BOLT12 Offers
    
    func checkLightningPayment(paymentHash: String, wait: Bool) async throws -> String? {
        // Check lightning payment status by payment hash
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try await wallet.checkLightningPayment(paymentHash: paymentHash, wait: wait)
        } catch let error as BarkError {
            Self.logger.error("FFI Error checking lightning payment: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to check lightning payment: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error checking lightning payment: \(error)")
            throw error
        }
    }
    
    func lightningReceiveStatus(paymentHash: String) async throws -> LightningReceive? {
        // Get lightning receive status by payment hash
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try await wallet.lightningReceiveStatus(paymentHash: paymentHash)
        } catch let error as BarkError {
            Self.logger.error("FFI Error getting lightning receive status: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get lightning receive status: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error getting lightning receive status: \(error)")
            throw error
        }
    }
    
    func tryClaimLightningReceive(paymentHash: String, wait: Bool) async throws {
        // Try to claim a specific lightning receive by payment hash
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        Self.logger.debug("Claiming specific Lightning receive via FFI, Payment hash: \(String(paymentHash.prefix(16)))...")
        
        do {
            try await wallet.tryClaimLightningReceive(paymentHash: paymentHash, wait: wait)
            Self.logger.info("Lightning receive claimed")
        } catch let error as BarkError {
            Self.logger.error("FFI Error claiming lightning receive: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to claim lightning receive: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error claiming lightning receive: \(error)")
            throw error
        }
    }
    
    func claimableLightningReceiveBalanceSats() async throws -> UInt64 {
        // Get claimable lightning receive balance
        
        if isPreview {
            return 0
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try await wallet.claimableLightningReceiveBalanceSats()
        } catch let error as BarkError {
            Self.logger.error("FFI Error getting claimable lightning receive balance: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get claimable lightning receive balance: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error getting claimable lightning receive balance: \(error)")
            throw error
        }
    }
    
    func pendingLightningReceives() async throws -> [LightningReceive] {
        // Get all pending lightning receives
        
        if isPreview {
            return []
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try await wallet.pendingLightningReceives()
        } catch let error as BarkError {
            Self.logger.error("FFI Error getting pending lightning receives: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get pending lightning receives: \(error.localizedDescription)")
        } catch {
            Self.logger.error("Error getting pending lightning receives: \(error)")
            throw error
        }
    }
}
