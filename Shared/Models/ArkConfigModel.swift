//
//  ArkConfigModel.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/20/25.
//

import Foundation

struct ArkConfigModel: Codable, Sendable {
    // Required fields
    let serverAddress: String  // Previously "ark" - matches FFI Config.serverAddress
    
    // Optional connection settings
    let esploraAddress: String?
    let bitcoindAddress: String?
    let bitcoindCookiefile: String?
    let bitcoindUser: String?
    let bitcoindPass: String?
    
    // Network configuration
    let network: String  // "bitcoin", "testnet", "signet", "regtest"
    
    // VTXO and round settings (all optional with defaults in Rust)
    let vtxoRefreshExpiryThreshold: UInt32?
    let vtxoExitMargin: UInt16?
    let htlcRecvClaimDelta: UInt16?
    let fallbackFeeRate: UInt64?  // In sat/vB
    let roundTxRequiredConfirmations: UInt32?
    
    enum CodingKeys: String, CodingKey {
        case serverAddress = "server_address"
        case esploraAddress = "esplora_address"
        case bitcoindAddress = "bitcoind_address"
        case bitcoindCookiefile = "bitcoind_cookiefile"
        case bitcoindUser = "bitcoind_user"
        case bitcoindPass = "bitcoind_pass"
        case network
        case vtxoRefreshExpiryThreshold = "vtxo_refresh_expiry_threshold"
        case vtxoExitMargin = "vtxo_exit_margin"
        case htlcRecvClaimDelta = "htlc_recv_claim_delta"
        case fallbackFeeRate = "fallback_fee_rate"
        case roundTxRequiredConfirmations = "round_tx_required_confirmations"
    }
    
    // MARK: - Computed Properties
    
    // Legacy property aliases for backward compatibility
    var ark: String { serverAddress }
    var esplora: String? { esploraAddress }
    var bitcoind: String? { bitcoindAddress }
    var bitcoindCookie: String? { bitcoindCookiefile }
    
    var hasArkEndpoint: Bool {
        !serverAddress.isEmpty
    }
    
    var hasEsploraEndpoint: Bool {
        esploraAddress != nil && !esploraAddress!.isEmpty
    }
    
    var hasBitcoindConnection: Bool {
        bitcoindAddress != nil && !bitcoindAddress!.isEmpty
    }
    
    var arkURL: URL? {
        URL(string: serverAddress)
    }
    
    var esploraURL: URL? {
        guard let esploraAddress = esploraAddress else { return nil }
        return URL(string: esploraAddress)
    }
    
    var bitcoindURL: URL? {
        guard let bitcoindAddress = bitcoindAddress else { return nil }
        return URL(string: bitcoindAddress)
    }
    
    // Formatted fallback fee rate in sat/vB (direct value, not kvb)
    var fallbackFeeRateSatPerVB: UInt64 {
        fallbackFeeRate ?? 10  // Default to 10 sat/vB if not set
    }
    
    // Formatted VTXO refresh threshold with default
    var vtxoRefreshThresholdBlocks: UInt32 {
        vtxoRefreshExpiryThreshold ?? 144  // Default to 144 blocks if not set
    }
    
    // Check if using signet endpoints (based on common signet domain patterns or network field)
    var isSignetConfig: Bool {
        if network.lowercased() == "signet" {
            return true
        }
        
        let signetKeywords = ["signet", "testnet"]
        let serverContainsSignet = signetKeywords.contains { keyword in
            serverAddress.lowercased().contains(keyword)
        }
        let esploraContainsSignet = signetKeywords.contains { keyword in
            esploraAddress?.lowercased().contains(keyword) ?? false
        }
        return serverContainsSignet || esploraContainsSignet
    }
    
    var isMainnet: Bool {
        network.lowercased() == "bitcoin"
    }
    
    var isTestnet: Bool {
        network.lowercased() == "testnet"
    }
    
    var isRegtest: Bool {
        network.lowercased() == "regtest"
    }
    
    // Configuration summary for display
    var configurationSummary: String {
        var summary = [String]()
        
        summary.append(String(localized: "format_network", defaultValue: "Network: \(network)"))
        summary.append(String(localized: "data_server", defaultValue: "Server: \(serverAddress)"))
        
        if hasEsploraEndpoint {
            summary.append("Esplora: \(esploraAddress!)")
        }
        if hasBitcoindConnection {
            summary.append("Bitcoin Core: \(bitcoindAddress!)")
        }
        
        summary.append("Fee Rate: \(fallbackFeeRateSatPerVB) sat/vB")
        summary.append("Refresh Threshold: \(vtxoRefreshThresholdBlocks) blocks")
        
        if let exitMargin = vtxoExitMargin {
            summary.append("Exit Margin: \(exitMargin) blocks")
        }
        if let htlcDelta = htlcRecvClaimDelta {
            summary.append("HTLC Claim Delta: \(htlcDelta) blocks")
        }
        if let confirmations = roundTxRequiredConfirmations {
            summary.append("Required Confirmations: \(confirmations)")
        }
        
        return summary.joined(separator: "\n")
    }
}
