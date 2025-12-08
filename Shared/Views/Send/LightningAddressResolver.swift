//
//  LightningAddressResolver.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/21/25.
//
//  Lightning Address (LNURL-pay) Resolver
//  Validates Lightning Addresses by checking the LNURL-pay endpoint
//  https://domain.com/.well-known/lnurlp/name
//

import Foundation

/// Resolves and validates Lightning Addresses via LNURL-pay endpoints
class LightningAddressResolver {
    
    // MARK: - Types
    
    struct ResolvedLightningAddress {
        let originalAddress: String       // alice@domain.com
        let callback: String              // URL to request invoice
        let minSendable: Int              // Minimum amount in millisatoshis
        let maxSendable: Int              // Maximum amount in millisatoshis
        let metadata: String?             // LNURL metadata JSON
        let commentAllowed: Int?          // Max comment length allowed
        let resolvedAt: Date              // Timestamp for cache expiration
        
        /// Minimum sendable amount in satoshis
        var minSendableSats: Int { minSendable / 1000 }
        
        /// Maximum sendable amount in satoshis
        var maxSendableSats: Int { maxSendable / 1000 }
    }
    
    enum LightningAddressError: LocalizedError {
        case invalidFormat
        case networkError(Error)
        case invalidResponse
        case notLNURLPay
        case serverError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Invalid Lightning Address format"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from Lightning Address server"
            case .notLNURLPay:
                return "Server does not support LNURL-pay"
            case .serverError(let message):
                return "Server error: \(message)"
            }
        }
    }
    
    // MARK: - Cache
    
    private static var cache: [String: ResolvedLightningAddress] = [:]
    private static let cacheDuration: TimeInterval = 600 // 10 minutes
    private static let cacheQueue = DispatchQueue(label: "com.ark.lightningaddresscache")
    
    // MARK: - Public API
    
    /// Validates and resolves a Lightning Address by checking the LNURL-pay endpoint
    /// - Parameter address: Lightning Address in user@domain format
    /// - Returns: Resolved Lightning Address with server capabilities
    static func resolve(_ address: String) async throws -> ResolvedLightningAddress {
        // Check cache first
        if let cached = getCached(address) {
            return cached
        }
        
        // Validate format
        guard isLightningAddressFormat(address) else {
            throw LightningAddressError.invalidFormat
        }
        
        // Construct LNURL-pay endpoint URL
        let endpoint = constructEndpoint(address)
        
        print("🔍 [LightningAddressResolver] Resolving \(address)")
        print("   → Endpoint: \(endpoint)")
        
        // Fetch LNURL-pay response
        let resolved = try await fetchLNURLPayResponse(address: address, endpoint: endpoint)
        
        print("   → Callback: \(resolved.callback)")
        print("   → Min: \(resolved.minSendableSats) sats, Max: \(resolved.maxSendableSats) sats")
        print("   ✅ Resolved successfully")
        
        // Cache the result
        cache(resolved, for: address)
        
        return resolved
    }
    
    /// Check if a string looks like a Lightning Address (user@domain format)
    static func isLightningAddressFormat(_ address: String) -> Bool {
        // Lightning address format: username@domain.tld
        // Must not start with ₿ (that's BIP-353)
        guard !address.hasPrefix("₿") else { return false }
        
        let pattern = "^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        return address.range(of: pattern, options: .regularExpression) != nil
    }
    
    // MARK: - Endpoint Construction
    
    private static func constructEndpoint(_ address: String) -> URL {
        let components = address.split(separator: "@")
        let username = String(components[0])
        let domain = String(components[1])
        
        // LNURL-pay spec: https://domain.com/.well-known/lnurlp/username
        return URL(string: "https://\(domain)/.well-known/lnurlp/\(username)")!
    }
    
    // MARK: - Network Request
    
    private static func fetchLNURLPayResponse(address: String, endpoint: URL) async throws -> ResolvedLightningAddress {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LightningAddressError.networkError(error)
        }
        
        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw LightningAddressError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        // Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LightningAddressError.invalidResponse
        }
        
        // Check for error response
        if let status = json["status"] as? String, status == "ERROR" {
            let reason = json["reason"] as? String ?? "Unknown error"
            throw LightningAddressError.serverError(reason)
        }
        
        // Validate tag is "payRequest"
        guard let tag = json["tag"] as? String, tag == "payRequest" else {
            throw LightningAddressError.notLNURLPay
        }
        
        // Extract required fields
        guard let callback = json["callback"] as? String,
              let minSendable = json["minSendable"] as? Int,
              let maxSendable = json["maxSendable"] as? Int else {
            throw LightningAddressError.invalidResponse
        }
        
        // Extract optional fields
        let metadata = json["metadata"] as? String
        let commentAllowed = json["commentAllowed"] as? Int
        
        return ResolvedLightningAddress(
            originalAddress: address,
            callback: callback,
            minSendable: minSendable,
            maxSendable: maxSendable,
            metadata: metadata,
            commentAllowed: commentAllowed,
            resolvedAt: Date()
        )
    }
    
    // MARK: - Cache Management
    
    private static func getCached(_ address: String) -> ResolvedLightningAddress? {
        return cacheQueue.sync {
            guard let cached = cache[address] else { return nil }
            
            let age = Date().timeIntervalSince(cached.resolvedAt)
            if age > cacheDuration {
                cache.removeValue(forKey: address)
                return nil
            }
            
            print("🎯 [LightningAddressResolver] Using cached resolution for \(address) (age: \(Int(age))s)")
            return cached
        }
    }
    
    private static func cache(_ resolved: ResolvedLightningAddress, for address: String) {
        cacheQueue.sync {
            cache[address] = resolved
        }
    }
    
    /// Clear all cached resolutions
    static func clearCache() {
        cacheQueue.sync {
            cache.removeAll()
        }
    }
    
    /// Clear cache for a specific address
    static func clearCache(for address: String) {
        cacheQueue.sync {
            _ = cache.removeValue(forKey: address)
        }
    }
}
