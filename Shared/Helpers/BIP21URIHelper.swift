//
//  BIP21URIHelper.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/21/25.
//

import Foundation

struct BIP21URIHelper {
    /// Create BIP 21 URI with optional alternative payment destinations
    static func createBIP21URI(
        arkAddress: String? = nil,
        onchainAddress: String? = nil,
        lightningInvoice: String? = nil,
        silentPaymentsAddress: String? = nil,
        amount: String? = nil,
        label: String? = nil,
        message: String? = nil
    ) -> String {
        var components = URLComponents()
        components.scheme = "bitcoin"
        components.path = onchainAddress ?? ""
        
        var queryItems: [URLQueryItem] = []
        
        // Add ark address as alternative payment option
        if let arkAddress = arkAddress {
            queryItems.append(URLQueryItem(name: "ark", value: arkAddress))
        }
        
        // Add lightning invoice as alternative payment option
        if let lightningInvoice = lightningInvoice {
            queryItems.append(URLQueryItem(name: "lightning", value: lightningInvoice))
        }
        
        // Add silent payments address as alternative payment option
        if let silentPaymentsAddress = silentPaymentsAddress {
            queryItems.append(URLQueryItem(name: "sp", value: silentPaymentsAddress))
        }
        
        // Add amount
        if let amount = amount {
            queryItems.append(URLQueryItem(name: "amount", value: amount))
        }
        
        // Add label
        if let label = label {
            queryItems.append(URLQueryItem(name: "label", value: label))
        }
        
        // Add message
        if let message = message {
            queryItems.append(URLQueryItem(name: "message", value: message))
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        return components.url?.absoluteString ?? "bitcoin:\(onchainAddress ?? "")"
    }
    
    /// Create a unified BIP-21 URI from a PaymentRequest with multiple destinations
    static func createBIP21URI(from paymentRequest: PaymentRequest) -> String {
        guard let primaryDestination = paymentRequest.primaryDestination else {
            return ""
        }
        
        // Extract alternative destinations by format
        let arkAddress = paymentRequest.firstDestination(for: .ark)?.address
        let lightningInvoice = paymentRequest.firstDestination(for: .lightningInvoice)?.address
        let silentPaymentsAddress = paymentRequest.firstDestination(for: .silentPayments)?.address
        
        // Convert amount from satoshis to BTC if present
        let amountBTC: String? = {
            if let sats = paymentRequest.amount {
                let btc = Double(sats) / 100_000_000
                return String(format: "%.8f", btc)
            }
            return nil
        }()
        
        return createBIP21URI(
            arkAddress: arkAddress,
            onchainAddress: primaryDestination.address,
            lightningInvoice: lightningInvoice,
            silentPaymentsAddress: silentPaymentsAddress,
            amount: amountBTC,
            label: paymentRequest.label,
            message: paymentRequest.message
        )
    }
}
