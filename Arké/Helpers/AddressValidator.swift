//
//  AddressValidator.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/24/25.
//

import Foundation

class AddressValidator {
    
    /// Validates and parses various address formats into a payment request
    static func parsePaymentRequest(_ input: String) -> PaymentRequest? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check BIP-21 URI first (can contain multiple destinations)
        if let bip21 = parseBIP21URI(trimmed) {
            return bip21
        }
        
        // For all other formats, create a single-destination payment request
        if let destination = parseSingleDestination(trimmed) {
            return PaymentRequest(destination: destination)
        }
        
        return nil
    }
    
    /// Parses a single payment destination (non-URI formats)
    private static func parseSingleDestination(_ input: String) -> PaymentDestination? {
        // Check Lightning address
        if isLightningAddress(input) {
            return PaymentDestination(
                format: .lightning,
                network: nil,
                address: input
            )
        }
        
        // Check Lightning invoice using dedicated parser
        if isLightningInvoice(input) {
            return parseLightningDestination(input)
        }
        
        // Check BIP-353 address
        if isBIP353Address(input) {
            return PaymentDestination(
                format: .bip353,
                network: nil,
                address: input
            )
        }
        
        // Check Bitcoin address with network detection
        if let network = detectBitcoinNetwork(input) {
            return PaymentDestination(
                format: .bitcoin,
                network: network,
                address: input
            )
        }
        
        // Check Silent Payments address with network detection
        if let network = detectSilentPaymentsNetwork(input) {
            let keys = extractSilentPaymentsKeys(input)
            return PaymentDestination(
                format: .silentPayments,
                network: network,
                address: input,
                scanPublicKey: keys?.scanKey,
                spendPublicKey: keys?.spendKey
            )
        }
        
        // Check Ark address with network detection
        if let network = detectArkNetwork(input) {
            return PaymentDestination(
                format: .ark,
                network: network,
                address: input
            )
        }
        
        return nil
    }
    
    /// Determines the Bitcoin network for an address
    static func detectBitcoinNetwork(_ address: String) -> BitcoinNetwork? {
        // Mainnet patterns
        if address.range(of: "^bc1[a-z0-9]{39,59}$", options: .regularExpression) != nil ||
           address.range(of: "^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$", options: .regularExpression) != nil {
            return .mainnet
        }
        
        // Testnet patterns
        if address.range(of: "^tb1[a-z0-9]{39,59}$", options: .regularExpression) != nil ||
           address.range(of: "^[2mn][a-km-zA-HJ-NP-Z1-9]{25,34}$", options: .regularExpression) != nil {
            return .testnet
        }
        
        // Signet patterns (uses same prefixes as testnet but different magic bytes)
        // Note: At the string level, signet addresses look identical to testnet
        // You might need additional context or user selection to differentiate
        
        // Regtest patterns (same as testnet for most address types)
        // Note: Regtest typically uses same address formats as testnet
        
        return nil
    }
    
    /// Determines the Bitcoin network for a silent payments address
    static func detectSilentPaymentsNetwork(_ address: String) -> BitcoinNetwork? {
        // Mainnet silent payments: sp1...
        if address.hasPrefix("sp1") && isValidSilentPaymentsAddress(address) {
            return .mainnet
        }
        
        // Testnet silent payments: tsp1...
        if address.hasPrefix("tsp1") && isValidSilentPaymentsAddress(address) {
            return .testnet
        }
        
        // Signet silent payments: ssp1...
        if address.hasPrefix("ssp1") && isValidSilentPaymentsAddress(address) {
            return .signet
        }
        
        // Regtest silent payments: rsp1...
        if address.hasPrefix("rsp1") && isValidSilentPaymentsAddress(address) {
            return .regtest
        }
        
        return nil
    }
    
    /// Validates a silent payments address according to BIP-352
    static func isValidSilentPaymentsAddress(_ address: String) -> Bool {
        // Check if it has a valid silent payments prefix
        let validPrefixes = ["sp1", "tsp1", "ssp1", "rsp1"]
        guard validPrefixes.contains(where: { address.hasPrefix($0) }) else {
            return false
        }
        
        // Decode using bech32m
        guard let decoded = decodeBech32m(address) else {
            return false
        }
        
        // Silent payments addresses should have exactly 66 bytes of data
        // (33 bytes for scan public key + 33 bytes for spend public key)
        return decoded.data.count == 66
    }
    
    /// Extracts the scan and spend public keys from a silent payments address
    static func extractSilentPaymentsKeys(_ address: String) -> (scanKey: Data, spendKey: Data)? {
        guard let decoded = decodeBech32m(address),
              decoded.data.count == 66 else {
            return nil
        }
        
        let scanKey = decoded.data.prefix(33)
        let spendKey = decoded.data.suffix(33)
        
        return (scanKey: Data(scanKey), spendKey: Data(spendKey))
    }
    
    /// Basic bech32m decoder for silent payments validation
    private static func decodeBech32m(_ address: String) -> (hrp: String, data: Data)? {
        // This is a simplified bech32m decoder for validation purposes
        // In production, you'd want a full implementation that handles all edge cases
        
        guard let separatorIndex = address.lastIndex(of: "1") else { return nil }
        
        let hrp = String(address[..<separatorIndex])
        let data = String(address[address.index(after: separatorIndex)...])
        
        // Basic character set validation for bech32m
        let validChars = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
        guard data.allSatisfy({ validChars.contains($0) }) else { return nil }
        
        // Convert bech32 string to 5-bit groups then to bytes
        // This is a simplified version - full implementation would include checksum verification
        let fiveBitGroups = data.dropLast(6).compactMap { validChars.firstIndex(of: $0)?.utf16Offset(in: validChars) }
        
        // Convert from 5-bit groups to 8-bit bytes
        var bytes: [UInt8] = []
        var accumulator = 0
        var bitsCount = 0
        
        for value in fiveBitGroups {
            accumulator = (accumulator << 5) | value
            bitsCount += 5
            
            if bitsCount >= 8 {
                bytes.append(UInt8((accumulator >> (bitsCount - 8)) & 0xFF))
                bitsCount -= 8
            }
        }
        
        return (hrp: hrp, data: Data(bytes))
    }
    
    /// Method for checking if an address is a valid Bitcoin address
    static func isBitcoinAddress(_ address: String) -> Bool {
        return detectBitcoinNetwork(address) != nil
    }
    
    /// Determines the Ark network for an address
    static func detectArkNetwork(_ address: String) -> BitcoinNetwork? {
        // Mainnet Ark addresses start with "ark1"
        if address.range(of: "^ark1[a-z0-9]+$", options: .regularExpression) != nil {
            return .mainnet
        }
        
        // Signet Ark addresses start with "t" (as you mentioned)
        if address.range(of: "^t[a-z0-9]+$", options: .regularExpression) != nil {
            return .signet
        }
        
        // Testnet Ark addresses - need to confirm the pattern
        // TODO: Update this when testnet pattern is confirmed
        if address.range(of: "^tark1[a-z0-9]+$", options: .regularExpression) != nil {
            return .testnet
        }
        
        // Regtest Ark addresses - typically same as testnet
        // TODO: Update this when regtest pattern is confirmed
        
        return nil
    }
    
    /// Determines if the address is an Ark address
    static func isArkAddress(_ address: String) -> Bool {
        return detectArkNetwork(address) != nil
    }
    
    /// Determines if the address is a silent payments address
    static func isSilentPaymentsAddress(_ address: String) -> Bool {
        return detectSilentPaymentsNetwork(address) != nil
    }
    
    /// Determines if the address is a Lightning address (user@domain.com format)
    static func isLightningAddress(_ address: String) -> Bool {
        // Lightning address format: username@domain.tld
        let lightningPattern = "^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        return address.range(of: lightningPattern, options: .regularExpression) != nil
    }
    
    /// Parses a Lightning invoice using the dedicated LightningInvoiceParser
    private static func parseLightningDestination(_ input: String) -> PaymentDestination? {
        // Try detailed parsing first
        if let lightningInvoice = try? LightningInvoiceParser.parse(input) {
            // Convert Lightning network to BitcoinNetwork
            let bitcoinNetwork: BitcoinNetwork? = {
                switch lightningInvoice.network {
                case .mainnet:
                    return .mainnet
                case .testnet:
                    return .testnet
                case .regtest:
                    return .regtest
                case .simnet:
                    return .signet  // Map simnet to signet
                }
            }()
            
            return PaymentDestination(
                format: .lightningInvoice,
                network: bitcoinNetwork,
                address: input
            )
        }
        
        // If detailed parsing fails, fall back to basic validation
        return isLightningInvoice(input) ? PaymentDestination(
            format: .lightningInvoice,
            network: nil,
            address: input
        ) : nil
    }
    
    /// Helper to get Lightning invoice amount (for payment request metadata)
    private static func extractLightningInvoiceInfo(_ input: String) -> (amount: Int?, description: String?) {
        if let lightningInvoice = try? LightningInvoiceParser.parse(input) {
            let amountInt: Int? = {
                if let amount = lightningInvoice.amountSatoshis {
                    return Int(amount)
                }
                return nil
            }()
            return (amount: amountInt, description: lightningInvoice.description)
        }
        return (amount: nil, description: nil)
    }

    /// Determines if the address is a Lightning invoice (BOLT11 format)
    static func isLightningInvoice(_ invoice: String) -> Bool {
        let trimmed = invoice.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // BOLT11 Lightning invoices start with network-specific prefixes
        let lightningInvoicePrefixes = ["lnbc", "lntb", "lnbcrt", "lnsb"]
        
        return lightningInvoicePrefixes.contains { prefix in
            trimmed.hasPrefix(prefix)
        }
    }
    
    /// Extracts amount from a BOLT11 Lightning invoice
    /// Returns amount in satoshis, or nil if no amount is specified or parsing fails
    /// Note: This method is kept for backward compatibility. Consider using LightningInvoiceParser directly.
    static func extractLightningInvoiceAmount(_ invoice: String) -> Int? {
        // Use the dedicated parser for better accuracy
        let (amount, _) = LightningInvoiceParser.extractAmountAndDescription(fromInvoice: invoice)
        if let amount = amount {
            return Int(amount)
        }
        
        // Fallback to original implementation for edge cases
        return extractLightningInvoiceAmountFallback(invoice)
    }
    
    /// Legacy implementation kept as fallback
    private static func extractLightningInvoiceAmountFallback(_ invoice: String) -> Int? {
        let trimmed = invoice.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the network prefix and extract the amount part
        let lightningInvoicePrefixes = ["lnbc", "lntb", "lnbcrt", "lnsb"]
        
        guard let matchingPrefix = lightningInvoicePrefixes.first(where: { trimmed.hasPrefix($0) }) else {
            return nil
        }
        
        // Remove the prefix to get the amount + rest of invoice
        let withoutPrefix = String(trimmed.dropFirst(matchingPrefix.count))
        
        // Extract amount part (everything before the first '1' which indicates start of data part)
        guard let separatorIndex = withoutPrefix.firstIndex(of: "1") else {
            return nil
        }
        
        let amountPart = String(withoutPrefix[..<separatorIndex])
        
        // If amount part is empty, invoice allows any amount
        if amountPart.isEmpty {
            return nil
        }
        
        // Parse the amount with multiplier
        return parseLightningAmountFallback(amountPart)
    }
    
    /// Legacy implementation kept as fallback
    private static func parseLightningAmountFallback(_ amountString: String) -> Int? {
        guard !amountString.isEmpty else { return nil }
        
        // Get the multiplier suffix and base amount
        let lastChar = amountString.last
        let multiplier: Double
        let baseAmountString: String
        
        switch lastChar {
        case "m": // milli-bitcoin (0.001 BTC = 100,000 sats)
            multiplier = 100_000
            baseAmountString = String(amountString.dropLast())
        case "u": // micro-bitcoin (0.000001 BTC = 100 sats)
            multiplier = 100
            baseAmountString = String(amountString.dropLast())
        case "n": // nano-bitcoin (0.000000001 BTC = 0.1 sats)
            multiplier = 0.1
            baseAmountString = String(amountString.dropLast())
        case "p": // pico-bitcoin (0.000000000001 BTC = 0.0001 sats)
            multiplier = 0.0001
            baseAmountString = String(amountString.dropLast())
        default:
            // No suffix means the amount is in bitcoin
            if lastChar?.isLetter == false {
                multiplier = 100_000_000 // 1 BTC = 100,000,000 sats
                baseAmountString = amountString
            } else {
                return nil // Unknown suffix
            }
        }
        
        // Parse the numeric part
        guard let baseAmount = Double(baseAmountString) else {
            return nil
        }
        
        // Calculate satoshis and round to nearest integer
        let satoshis = baseAmount * multiplier
        return Int(satoshis.rounded())
    }
    
    /// Determines if the address is a BIP-353 address (₿username.domain.tld format)
    static func isBIP353Address(_ address: String) -> Bool {
        // BIP-353 format: ₿username.domain.tld
        let bip353Pattern = "^₿[a-zA-Z0-9._-]+\\.[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        return address.range(of: bip353Pattern, options: .regularExpression) != nil
    }
    
    /// Parses a BIP-21 Bitcoin URI with all payment destinations
    static func parseBIP21URI(_ uri: String) -> PaymentRequest? {
        guard uri.lowercased().starts(with: "bitcoin:") else { return nil }
        
        let withoutScheme = String(uri.dropFirst(8)) // Remove "bitcoin:"
        
        // Split address and parameters
        let components = withoutScheme.components(separatedBy: "?")
        let primaryAddress = components.first ?? ""
        
        var destinations: [PaymentDestination] = []
        var amount: Int?
        var label: String?
        var message: String?
        
        // Parse primary address as first destination
        if let destination = parseSingleDestination(primaryAddress) {
            destinations.append(destination)
        } else {
            return nil // Invalid primary address
        }
        
        // Parse query parameters for amount, metadata, and alternative destinations
        if components.count > 1 {
            let queryString = components[1]
            let parameters = parseQueryParameters(queryString)
            
            // Parse amount (BTC to satoshis conversion)
            if let amountString = parameters["amount"],
               let amountDouble = Double(amountString) {
                amount = Int(amountDouble * 100_000_000) // Convert BTC to satoshis
            }
            
            label = parameters["label"]?.removingPercentEncoding
            message = parameters["message"]?.removingPercentEncoding
            
            // Parse alternative payment destinations
            
            // Ark address alternative
            if let arkAddress = parameters["ark"],
               let arkDestination = parseSingleDestination(arkAddress) {
                destinations.append(arkDestination)
            }
            
            // Lightning invoice alternative (both "lightning" and "ln" are common)
            if let lightningParam = parameters["lightning"] ?? parameters["ln"] {
                if let lightningDestination = parseSingleDestination(lightningParam) {
                    destinations.append(lightningDestination)
                    
                    // If amount wasn't specified in BIP-21 but is in Lightning invoice, use that
                    if amount == nil {
                        let invoiceInfo = extractLightningInvoiceInfo(lightningParam)
                        amount = invoiceInfo.amount
                        // Also use invoice description as label if not set
                        if label == nil {
                            label = invoiceInfo.description
                        }
                    }
                }
            }
            
            // Silent Payments alternative
            if let spAddress = parameters["sp"],
               let spDestination = parseSingleDestination(spAddress) {
                destinations.append(spDestination)
            }
            
            // Support for additional Bitcoin addresses (for unified QR codes)
            if let altAddress = parameters["address"],
               let altDestination = parseSingleDestination(altAddress) {
                destinations.append(altDestination)
            }
        }
        
        return PaymentRequest(
            destinations: destinations,
            amount: amount,
            label: label,
            message: message,
            originalString: uri
        )
    }
    
    /// Parses URL query parameters
    private static func parseQueryParameters(_ queryString: String) -> [String: String] {
        var parameters: [String: String] = [:]
        
        let pairs = queryString.components(separatedBy: "&")
        for pair in pairs {
            let keyValue = pair.components(separatedBy: "=")
            if keyValue.count == 2 {
                let key = keyValue[0]
                let value = keyValue[1]
                parameters[key] = value
            }
        }
        
        return parameters
    }
    
    /// Checks if the input is any valid address format
    static func isValidPaymentRequest(_ input: String) -> Bool {
        return parsePaymentRequest(input) != nil
    }
    
    // MARK: - NetworkConfig Integration
    
    /// Parse a payment request with network validation against a specific NetworkConfig
    static func parsePaymentRequest(_ input: String, expectedNetwork networkConfig: NetworkConfig) -> PaymentRequest? {
        guard let paymentRequest = parsePaymentRequest(input) else { return nil }
        
        // Filter to only destinations compatible with the network
        return paymentRequest.filtered(for: networkConfig)
    }
    
    /// Check if a payment request is valid for a specific network configuration
    static func isValidPaymentRequest(_ input: String, for networkConfig: NetworkConfig) -> Bool {
        return parsePaymentRequest(input, expectedNetwork: networkConfig) != nil
    }
    
    /// Get all payment requests from a list that match a specific network configuration
    static func filterPaymentRequests(_ requests: [PaymentRequest], for networkConfig: NetworkConfig) -> [PaymentRequest] {
        return requests.compactMap { $0.filtered(for: networkConfig) }
    }
}
