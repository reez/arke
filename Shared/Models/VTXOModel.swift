//
//  VTXOModel.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import Foundation
import SwiftUI
import ArkeUI
import Bark

enum VTXOState: String, Codable, CaseIterable, Sendable {
    case unregisteredBoard = "UnregisteredBoard"
    case registeredBoard = "RegisteredBoard"
    case spent = "Spent"
    case pending = "Pending"
    case spendable = "Spendable"
    case locked = "Locked"
}

extension VTXOState {
    var displayName: String {
        switch self {
        case .unregisteredBoard:
            return "Unregistered Board"
        case .registeredBoard:
            return "Registered Board"
        case .spent:
            return "Spent"
        case .pending:
            return "Pending"
        case .spendable:
            return "Spendable"
        case .locked:
            return "Locked"
        }
    }
    
    var iconName: String {
        switch self {
        case .unregisteredBoard:
            return "clock.arrow.circlepath"
        case .registeredBoard:
            return "checkmark.circle"
        case .spent:
            return "xmark.circle"
        case .pending:
            return "hourglass"
        case .spendable:
            return "bitcoinsign.circle"
        case .locked:
            return "lock.circle"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .unregisteredBoard:
            return .Arke.orange
        case .registeredBoard:
            return .Arke.green
        case .spent:
            return .gray
        case .pending:
            return .Arke.blue
        case .spendable:
            return .Arke.green
        case .locked:
            return .Arke.purple
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .unregisteredBoard:
            return .Arke.orange.opacity(0.2)
        case .registeredBoard:
            return .Arke.green.opacity(0.2)
        case .spent:
            return .gray.opacity(0.2)
        case .pending:
            return .Arke.blue.opacity(0.2)
        case .spendable:
            return .Arke.green.opacity(0.3)
        case .locked:
            return .Arke.purple.opacity(0.3)
        }
    }
    
    var textColor: Color {
        switch self {
        case .unregisteredBoard:
            return .Arke.orange
        case .registeredBoard:
            return .Arke.green
        case .spent:
            return .gray
        case .pending:
            return .Arke.blue
        case .spendable:
            return .Arke.green
        case .locked:
            return .Arke.purple
        }
    }
}

enum VTXOKind: String, Codable, CaseIterable, Sendable {
    case pubkey = "pubkey"
    case checkpoint = "checkpoint"
    case serverHTLCSend = "server-htlc-send"
    case serverHTLCRecv = "server-htlc-receive"
    case expiry = "expiry"
    case board = "board"
    case round = "round"
    case arkoor = "arkoor"
}

extension VTXOKind {
    var displayName: String {
        switch self {
        case .pubkey:
            return "Public Key"
        case .checkpoint:
            return "Checkpoint"
        case .serverHTLCSend:
            return "Server HTLC Send"
        case .serverHTLCRecv:
            return "Server HTLC Receive"
        case .expiry:
            return "Expiry"
        case .board:
            return "Board"
        case .round:
            return "Round"
        case .arkoor:
            return "Arkoor"
        }
    }
}

/// VTXO model that matches what Bark FFI provides
/// Only contains fields directly available from the Rust wallet
struct VTXOModel: Codable, Identifiable, Hashable, Sendable {
    /// VTXO id in format "txid:vout"
    let id: String
    /// Amount in satoshis
    let amountSat: Int
    /// Expiry height (0 if unknown)
    let expiryHeight: Int
    /// Type of VTXO (e.g., "board", "round", "arkoor", "pubkey")
    let kind: VTXOKind
    /// State of VTXO (e.g., "spendable", "spent", "locked")
    let state: VTXOState
    /// Genesis chain length (exit depth)
    let exitDepth: UInt32
    /// Weight units of exit transaction chain
    let exitTxWeightWu: UInt64
    
    // Coding keys to match serialization
    enum CodingKeys: String, CodingKey {
        case id
        case amountSat = "amount_sat"
        case expiryHeight = "expiry_height"
        case kind
        case state
        case exitDepth = "exit_depth"
        case exitTxWeightWu = "exit_tx_weight_wu"
    }
    
    init(id: String, amountSat: Int, expiryHeight: Int, kind: VTXOKind, state: VTXOState, exitDepth: UInt32 = 0, exitTxWeightWu: UInt64 = 0) {
        self.id = id
        self.amountSat = amountSat
        self.expiryHeight = expiryHeight
        self.kind = kind
        self.state = state
        self.exitDepth = exitDepth
        self.exitTxWeightWu = exitTxWeightWu
    }
    
    // Computed properties for convenience
    var formattedAmount: String {
        return BitcoinFormatter.shared.formatAmount(amountSat)
    }
    
    var shortId: String {
        if id.count > 12 {
            return String(id.prefix(8)) + String(localized: "symbol_ellipsis")
        }
        return id
    }
    
    // Extract txid and vout from the id (which is in format "txid:vout")
    var txid: String {
        return String(id.split(separator: ":").first ?? "")
    }
    
    var vout: Int {
        if let voutString = id.split(separator: ":").last {
            return Int(voutString) ?? 0
        }
        return 0
    }
    
    var outpoint: String {
        return id
    }
    
    var shortTxid: String {
        let txidValue = txid
        if txidValue.count > 8 {
            return String(txidValue.prefix(8)) + String(localized: "symbol_ellipsis")
        }
        return txidValue
    }
    
    var isSpent: Bool {
        return state == .spent
    }
}

// Extension for conversion from SDK types
extension VTXOModel {
    /// Initialize from SDK's Vtxo type
    init(from vtxo: Vtxo) {
        // Map SDK state string to VTXOState enum
        let state: VTXOState = {
            switch vtxo.state.lowercased() {
            case "spendable": return .spendable
            case "spent": return .spent
            case "locked": return .locked
            case "pending": return .pending
            default: return .pending
            }
        }()
        
        // Map SDK kind string to VTXOKind enum
        let kind: VTXOKind = {
            switch vtxo.kind.lowercased() {
            case "board": return .board
            case "round": return .round
            case "arkoor": return .arkoor
            case "pubkey": return .pubkey
            case "checkpoint": return .checkpoint
            case "server-htlc-send", "serverhtlcsend": return .serverHTLCSend
            case "server-htlc-receive", "serverhtlcreceive": return .serverHTLCRecv
            case "expiry": return .expiry
            default: return .round
            }
        }()
        
        self.init(
            id: vtxo.id,
            amountSat: Int(vtxo.amountSats),
            expiryHeight: Int(vtxo.expiryHeight),
            kind: kind,
            state: state,
            exitDepth: vtxo.exitDepth,
            exitTxWeightWu: vtxo.exitTxWeightWu
        )
    }
}

// Extension for parsing and mock data
extension VTXOModel {
    static func parseFromJSON(_ jsonData: Data) throws -> [VTXOModel] {
        let decoder = JSONDecoder()
        return try decoder.decode([VTXOModel].self, from: jsonData)
    }
    
    static func parseFromJSONString(_ jsonString: String) throws -> [VTXOModel] {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "VTXOModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        return try parseFromJSON(data)
    }
    
    static func mockVTXOs() -> [VTXOModel] {
        return [
            VTXOModel(
                id: "4f35af824858dd69802af664a2d1b03d2a49d60b7f66741ba3292de3b756d49a:0",
                amountSat: 1000,
                expiryHeight: 274399,
                kind: .board,
                state: .spendable,
                exitDepth: 1,
                exitTxWeightWu: 500
            ),
            VTXOModel(
                id: "abc123def456789012345678901234567890abcdef123456789012345678901234:1",
                amountSat: 25000,
                expiryHeight: 274500,
                kind: .round,
                state: .spendable,
                exitDepth: 2,
                exitTxWeightWu: 750
            ),
            VTXOModel(
                id: "def456abc123789012345678901234567890abcdef123456789012345678901234:2",
                amountSat: 5000,
                expiryHeight: 0,
                kind: .arkoor,
                state: .locked,
                exitDepth: 3,
                exitTxWeightWu: 1000
            )
        ]
    }
    
    // Legacy parsing method (kept for backward compatibility if needed)
    static func parseFromWalletOutput(_ output: String) -> [VTXOModel] {
        // This method would need to be updated based on the actual output format
        // For now, returning empty array as the format has changed significantly
        return []
    }
}
