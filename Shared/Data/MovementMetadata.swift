//
//  MovementMetadata.swift
//  Ark wallet prototype
//
//  Subsystem-specific metadata models for movements
//

import Foundation

// MARK: - Base Protocol

/// Base protocol for movement metadata
protocol MovementMetadata: Codable {
    var subsystemName: String { get }
}

// MARK: - Subsystem-Specific Metadata

/// Metadata for bark.board movements (onchain to ark boarding)
struct BoardMetadata: MovementMetadata {
    var subsystemName: String { "bark.board" }
    
    /// Bitcoin network fees paid for the onchain transaction
    let onchainFeeSat: Int
    
    /// Blockchain anchor reference for the VTXO
    let chainAnchor: String
    
    enum CodingKeys: String, CodingKey {
        case onchainFeeSat = "onchain_fee_sat"
        case chainAnchor = "chain_anchor"
    }
}

/// Metadata for bark.lightning_send and bark.lightning_receive movements
struct LightningMetadata: MovementMetadata {
    private let _subsystemName: String
    var subsystemName: String { _subsystemName }
    
    /// Payment hash identifying this Lightning payment
    let paymentHash: String
    
    /// HTLC VTXOs created for this payment (may be empty if already swapped)
    let htlcVtxos: [String]
    
    enum CodingKeys: String, CodingKey {
        case _subsystemName = "subsystem_name"
        case paymentHash = "payment_hash"
        case htlcVtxos = "htlc_vtxos"
    }
    
    init(subsystemName: String = "bark.lightning", paymentHash: String, htlcVtxos: [String]) {
        self._subsystemName = subsystemName
        self.paymentHash = paymentHash
        self.htlcVtxos = htlcVtxos
    }
    
    /// Whether this payment has active HTLC VTXOs
    var hasActiveHtlcs: Bool {
        !htlcVtxos.isEmpty
    }
    
    /// Number of HTLC VTXOs
    var htlcCount: Int {
        htlcVtxos.count
    }
}

/// Metadata for bark.round movements (offboard, send_onchain, refresh)
struct RoundMetadata: MovementMetadata {
    var subsystemName: String { "bark.round" }
    
    /// Funding transaction ID of the round this movement participated in
    let fundingTxid: String
    
    enum CodingKeys: String, CodingKey {
        case fundingTxid = "funding_txid"
    }
}

// MARK: - Sendable Conformance

extension BoardMetadata: Sendable {}
extension LightningMetadata: Sendable {}
extension RoundMetadata: Sendable {}

// MARK: - Parser

/// Parser for movement metadata JSON strings
enum MovementMetadataParser {
    
    /// Parse metadata based on subsystem name
    /// - Parameters:
    ///   - json: The metadata JSON string
    ///   - subsystemName: The subsystem name to determine parsing strategy
    /// - Returns: Parsed metadata object, or nil if parsing fails or no metadata
    static func parse(json: String, subsystemName: String) -> MovementMetadata? {
        // Empty or minimal JSON
        guard !json.isEmpty, json != "{}", json != "null" else {
            return nil
        }
        
        guard let data = json.data(using: .utf8) else {
            print("⚠️ Failed to convert metadata JSON to data")
            return nil
        }
        
        let decoder = JSONDecoder()
        
        do {
            switch subsystemName {
            case "bark.board":
                return try decoder.decode(BoardMetadata.self, from: data)
                
            case "bark.lightning_send", "bark.lightning_receive":
                return try decoder.decode(LightningMetadata.self, from: data)
                
            case "bark.round":
                return try decoder.decode(RoundMetadata.self, from: data)
                
            default:
                // Unknown subsystem, don't parse
                return nil
            }
        } catch {
            print("⚠️ Failed to parse metadata for \(subsystemName): \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   Raw JSON: \(jsonString.prefix(200))")
            }
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension MovementMetadata {
    /// Cast to BoardMetadata if applicable
    var asBoard: BoardMetadata? {
        self as? BoardMetadata
    }
    
    /// Cast to LightningMetadata if applicable
    var asLightning: LightningMetadata? {
        self as? LightningMetadata
    }
    
    /// Cast to RoundMetadata if applicable
    var asRound: RoundMetadata? {
        self as? RoundMetadata
    }
}
