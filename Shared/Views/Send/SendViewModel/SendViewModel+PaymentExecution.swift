//
//  SendViewModel+PaymentExecution.swift
//  Ark wallet prototype
//
//  Created by Assistant on 12/8/25.
//
//  Payment execution with routing to different payment methods
//  (onchain, Lightning, Ark) and LNURL-pay invoice resolution.
//

import SwiftUI
import ArkeUI
import Bark

extension SendViewModel {
    
    // MARK: - LNURL-Pay Resolution
    
    /// Requests a Lightning invoice from an LNURL-pay callback URL
    private func requestLightningInvoice(callback: String, amountMillisats: Int, comment: String?) async throws -> String {
        // Construct the callback URL with amount parameter
        guard var urlComponents = URLComponents(string: callback) else {
            throw SendError.invalidFormat("Invalid LNURL-pay callback URL")
        }
        
        // Add amount parameter (in millisatoshis)
        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "amount", value: String(amountMillisats)))
        
        // Add comment if provided
        if let comment = comment, !comment.isEmpty {
            queryItems.append(URLQueryItem(name: "comment", value: comment))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw SendError.invalidFormat("Failed to construct LNURL-pay callback URL")
        }
        
        // Make the HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30  // Increased to 30 seconds for slow LNURL servers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("   → Requesting invoice from: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("   → Received response (\(data.count) bytes)")
        
        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                print("   ❌ HTTP \(httpResponse.statusCode): \(body)")
                throw SendError.invalidFormat("LNURL-pay callback returned HTTP \(httpResponse.statusCode)")
            }
        }
        
        // Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let body = String(data: data, encoding: .utf8) ?? "(binary data)"
            print("   ❌ Invalid JSON response: \(body)")
            throw SendError.invalidFormat("Invalid JSON response from LNURL-pay callback")
        }
        
        print("   → Response JSON: \(json)")
        
        // Check for error response
        if let status = json["status"] as? String, status == "ERROR" {
            let reason = json["reason"] as? String ?? "Unknown error"
            throw SendError.invalidFormat("LNURL-pay error: \(reason)")
        }
        
        // Extract the invoice (pr = payment request)
        guard let invoice = json["pr"] as? String else {
            throw SendError.invalidFormat("No invoice returned from LNURL-pay callback")
        }
        
        return invoice
    }
    
    // MARK: - Payment Execution
    
    /// Executes the payment using the current send state
    func executeSend(paymentRequest: PaymentRequest? = nil, destinationId: UUID? = nil, amount: String? = nil) async throws {
        print("💸 [SendViewModel] executeSend() called")
        print("   → paymentRequest provided: \(paymentRequest != nil)")
        print("   → destinationId provided: \(destinationId?.uuidString ?? "nil")")
        print("   → amount provided: \(amount ?? "nil")")
        
        // Compute ranked destinations from payment request if provided, otherwise use state
        let rankedDestinations: [PaymentDestinationSelector.RankedDestination]
        if let request = paymentRequest {
            rankedDestinations = request.rankedDestinations(context: paymentContext)
            print("   → Using payment request with \(request.destinations.count) destination(s)")
            for (index, dest) in request.destinations.enumerated() {
                print("      [\(index)] format: \(dest.format.rawValue), address: \(dest.shortAddress)")
            }
        } else {
            rankedDestinations = self.rankedDestinations
            print("   → Using state rankedDestinations: \(rankedDestinations.count)")
        }
        
        // Determine the destination to use
        let destination: PaymentDestination
        if let destId = destinationId,
           let found = rankedDestinations.first(where: { $0.destination.id == destId })?.destination {
            destination = found
            print("   → Selected destination by ID: \(destination.format.rawValue)")
        } else if let selected = selectedDestination {
            destination = selected
            print("   → Using selectedDestination: \(destination.format.rawValue)")
        } else if let firstViable = rankedDestinations.first(where: { $0.viable })?.destination {
            destination = firstViable
            print("   → Using first viable destination: \(destination.format.rawValue)")
        } else {
            print("   ❌ No viable destination found!")
            throw SendError.noDestinationSelected
        }
        
        print("   → Final destination format: \(destination.format.rawValue)")
        print("   → Final destination address: \(destination.address)")
        print("   → Final destination network: \(destination.network?.displayName ?? "N/A")")
        
        // Check if amount is locked (Lightning invoice with embedded amount)
        let amountLocked: Bool
        if let request = paymentRequest {
            amountLocked = destination.format == .lightningInvoice && request.amount != nil
        } else {
            amountLocked = isAmountLocked
        }
        
        // For Lightning invoices with embedded amounts, we don't need to validate the amount field
        if amountLocked {
            error = nil
            
            // Pay the Lightning invoice without passing an amount
            _ = try await walletManager.payLightningInvoice(invoice: destination.address, amountSats: nil)
            return
        }
        
        // Determine the amount to use (parameter override or state)
        let amountString = amount ?? self.amount
        
        // For all other cases, validate the amount field
        guard let amountInt = Int(amountString) else {
            throw SendError.invalidAmount
        }
        
        // Validate amount against viability using FRESH balance data
        // CRITICAL FIX: Don't use cached rankedDestinations - balance may have changed since they were calculated!
        // Always re-rank with current balance to avoid "available balance (0 sats)" errors when balance loads late
        let freshRanking = PaymentDestinationSelector.rankDestination(
            destination,
            amount: amountInt,
            context: paymentContext  // This reads CURRENT balance from walletManager
        )
        
        // Use fresh ranking, or fall back to cached ranking if fresh ranking failed
        if let ranked = freshRanking ?? rankedDestinations.first(where: { $0.destination.id == destination.id }) {
            if !ranked.viable {
                throw SendError.destinationNotViable(ranked.reason)
            }
            
            // Check if amount + fee exceeds available balance
            let totalRequired = amountInt + (ranked.estimatedFee ?? 0)
            if let availableBalance = ranked.availableBalance, totalRequired > availableBalance {
                throw SendError.insufficientBalance(required: totalRequired, available: availableBalance)
            }
        }
        
        error = nil
        
        // Route to the appropriate payment method based on destination format
        print("   → Routing payment to format: \(destination.format.rawValue)")
        
        switch destination.format {
        case .bitcoin, .silentPayments:
            print("   → Sending onchain to: \(destination.address)")
            let feeRate = onchainFeeRates.rate(for: selectedFeePriority)
            print("   → Using fee rate: \(feeRate) sat/vB (priority: \(selectedFeePriority))")
            _ = try await walletManager.sendOnchain(to: destination.address, amount: amountInt, feeRateSatPerVb: feeRate)
            
        case .lightningInvoice:
            // Check if the invoice already has an embedded amount
            let invoiceHasAmount = paymentRequest?.amount != nil || currentPaymentRequest?.amount != nil
            print("   → Paying Lightning invoice: \(destination.shortAddress)")
            print("   → Invoice has embedded amount: \(invoiceHasAmount)")
            if invoiceHasAmount {
                _ = try await walletManager.payLightningInvoice(invoice: destination.address, amountSats: nil)
            } else {
                _ = try await walletManager.payLightningInvoice(invoice: destination.address, amountSats: UInt64(amountInt))
            }
            
        case .lightning:
            // Lightning address - use the direct FFI method
            print("   → Paying Lightning address: \(destination.address)")
            _ = try await walletManager.payLightningAddress(
                lightningAddress: destination.address,
                amountSats: UInt64(amountInt),
                comment: nil
            )
            
        case .bolt12:
            // BOLT12 offers require explicit amount and use dedicated payment method
            // The offer is resolved into an invoice internally by the wallet
            print("   → Paying BOLT12 offer: \(destination.shortAddress)")
            _ = try await walletManager.payLightningOffer(offer: destination.address, amountSats: UInt64(amountInt))
            
        case .ark:
            print("   → Sending Ark to: \(destination.address)")
            _ = try await walletManager.send(to: destination.address, amount: amountInt)
            
        case .bip353:
            // BIP-353 should have been resolved to another format by now
            // This is a fallback - try to send as Ark
            print("   ⚠️ WARNING: BIP-353 destination reached executeSend without resolution!")
            print("   → BIP-353 address: \(destination.address)")
            print("   → Attempting to send as Ark (this will likely fail)")
            _ = try await walletManager.send(to: destination.address, amount: amountInt)
            
        case .bip21:
            // BIP-21 should never be a final destination format
            print("   ❌ ERROR: BIP-21 destination reached executeSend!")
            throw SendError.invalidFormat("BIP-21 is a wrapper format and should be resolved before sending")
        }
    }
    
    // MARK: - Error Definitions
    
    /// Custom errors for send operations
    enum SendError: LocalizedError {
        case noDestinationSelected
        case invalidAmount
        case destinationNotViable(String)
        case insufficientBalance(required: Int, available: Int)
        case invalidFormat(String)
        
        var errorDescription: String? {
            switch self {
            case .noDestinationSelected:
                return "No payment destination selected"
            case .invalidAmount:
                return "Invalid amount"
            case .destinationNotViable(let reason):
                return "Cannot send: \(reason)"
            case .insufficientBalance(let required, let available):
                return "Amount + fees (\(required) sats) exceeds available balance (\(available) sats)"
            case .invalidFormat(let message):
                return message
            }
        }
    }
    
}
