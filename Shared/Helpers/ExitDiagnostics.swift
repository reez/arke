//
//  ExitDiagnostics.swift
//  Arké
//
//  Helper functions for diagnosing exit failures and analyzing blockchain state
//

import Foundation
import Bark

/// Helper class for diagnosing exit failures by querying blockchain state
class ExitDiagnostics {
    
    private let esploraURL: String
    
    init(esploraURL: String) {
        self.esploraURL = esploraURL
    }
    
    // MARK: - Public Diagnostic Methods
    
    /// Extract and analyze transaction IDs from error messages
    func extractAndAnalyzeTransactionIds(from errorMessage: String) async {
        // Extract potential transaction IDs (64-character hex strings)
        let words = errorMessage.split(whereSeparator: { " ,;:[]()\"'".contains($0) })
        var foundTxids: [String] = []
        
        for word in words {
            let wordStr = String(word)
            // Bitcoin txids are 64-character hex strings
            if wordStr.count == 64 && wordStr.allSatisfy({ $0.isHexDigit }) {
                foundTxids.append(wordStr)
            }
        }
        
        if foundTxids.isEmpty {
            print("            ⚠️ No transaction IDs found in error message")
            return
        }
        
        print("            Found \(foundTxids.count) potential parent transaction(s):")
        
        for (txIndex, txid) in foundTxids.enumerated() {
            print("\n            ┌─ Parent TX #\(txIndex + 1): \(txid.prefix(8))...\(txid.suffix(8))")
            print("            │  Note: These are locally-constructed exit transactions")
            print("            │  They reference inputs that may already be spent on-chain")
            print("            │  [Cannot parse inputs - raw tx hex not exposed via FFI]")
            print("            └─ Check the VTXO outpoint below for on-chain status")
        }
    }
    
    /// Analyze a VTXO outpoint by querying Esplora
    func analyzeVtxoOutpoint(vtxoId: String) async {
        // Parse the VTXO ID which should be in format: txid:vout
        let components = vtxoId.split(separator: ":")
        guard components.count == 2,
              let vout = UInt32(components[1]) else {
            print("\n         ⚠️ VTXO ID not in expected outpoint format (txid:vout)")
            return
        }
        
        let txid = String(components[0])
        print("\n         📍 Outpoint Analysis:")
        print("            Parent txid: \(txid.prefix(8))...\(txid.suffix(8))")
        print("            Output index: \(vout)")
        
        do {
            // Check transaction status
            let txStatusURL = URL(string: "\(esploraURL)/tx/\(txid)/status")!
            let (statusData, statusResponse) = try await URLSession.shared.data(from: txStatusURL)
            
            if let httpResponse = statusResponse as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    print("            ❌ Parent transaction NOT FOUND on-chain")
                    print("            → This VTXO references a transaction that doesn't exist")
                    print("            → Likely: VTXO was from an ASP round that was never confirmed")
                    return
                } else if httpResponse.statusCode != 200 {
                    print("            ⚠️ Esplora returned status \(httpResponse.statusCode)")
                    return
                }
            }
            
            // Parse transaction status
            if let statusJson = try? JSONSerialization.jsonObject(with: statusData) as? [String: Any] {
                let confirmed = statusJson["confirmed"] as? Bool ?? false
                
                if confirmed {
                    if let blockHeight = statusJson["block_height"] as? Int {
                        print("            ✅ Parent transaction IS confirmed on-chain")
                        print("            → Block height: \(blockHeight)")
                    } else {
                        print("            ✅ Parent transaction is confirmed")
                    }
                } else {
                    print("            ⏳ Parent transaction is UNCONFIRMED (in mempool)")
                }
            }
            
            // Now check if the specific output (UTXO) still exists
            let utxoURL = URL(string: "\(esploraURL)/tx/\(txid)/outspend/\(vout)")!
            let (utxoData, utxoResponse) = try await URLSession.shared.data(from: utxoURL)
            
            if let httpResponse = utxoResponse as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let utxoJson = try? JSONSerialization.jsonObject(with: utxoData) as? [String: Any] {
                    let spent = utxoJson["spent"] as? Bool ?? false
                    
                    if spent {
                        print("\n            ❌ This UTXO HAS BEEN SPENT")
                        
                        // Get spending transaction details
                        if let spendingTxid = utxoJson["txid"] as? String {
                            print("            → Spent by: \(spendingTxid.prefix(8))...\(spendingTxid.suffix(8))")
                            
                            if let spendingVin = utxoJson["vin"] as? Int {
                                print("            → Input index: \(spendingVin)")
                            }
                            
                            // Analyze spending transaction
                            await analyzeSpendingTransaction(spendingTxid: spendingTxid)
                        }
                    } else {
                        print("\n            ✅ This UTXO is UNSPENT")
                        print("            → Should be available for exit transaction")
                        print("            → Error may be due to different issue")
                    }
                }
            }
            
        } catch {
            print("            ⚠️ Error querying Esplora: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Analyze the transaction that spent a UTXO
    private func analyzeSpendingTransaction(spendingTxid: String) async {
        do {
            // Get spending transaction details
            let txURL = URL(string: "\(esploraURL)/tx/\(spendingTxid)")!
            let (txData, txResponse) = try await URLSession.shared.data(from: txURL)
            
            if let httpResponse = txResponse as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let txJson = try? JSONSerialization.jsonObject(with: txData) as? [String: Any] {
                    
                    // Check transaction status
                    let statusURL = URL(string: "\(esploraURL)/tx/\(spendingTxid)/status")!
                    let (statusData, _) = try await URLSession.shared.data(from: statusURL)
                    
                    if let statusJson = try? JSONSerialization.jsonObject(with: statusData) as? [String: Any] {
                        let confirmed = statusJson["confirmed"] as? Bool ?? false
                        
                        if confirmed {
                            if let blockHeight = statusJson["block_height"] as? Int,
                               let blockTime = statusJson["block_time"] as? Int {
                                let date = Date(timeIntervalSince1970: TimeInterval(blockTime))
                                let formatter = DateFormatter()
                                formatter.dateStyle = .short
                                formatter.timeStyle = .short
                                print("\n            📊 Spending Transaction Details:")
                                print("               Status: Confirmed")
                                print("               Block: \(blockHeight)")
                                print("               Time: \(formatter.string(from: date))")
                            }
                        } else {
                            print("\n            📊 Spending Transaction Details:")
                            print("               Status: Unconfirmed (in mempool)")
                        }
                    }
                    
                    // Count inputs and outputs to understand transaction type
                    if let vin = txJson["vin"] as? [[String: Any]],
                       let vout = txJson["vout"] as? [[String: Any]] {
                        print("               Inputs: \(vin.count)")
                        print("               Outputs: \(vout.count)")
                        
                        // Check if this looks like an ASP round transaction
                        if vin.count > 10 || vout.count > 10 {
                            print("               🔍 Large transaction - likely an ASP round")
                            print("               → Your VTXO was consumed in a cooperative round")
                        }
                    }
                }
            }
        } catch {
            print("            ⚠️ Error analyzing spending tx: \(error.localizedDescription)")
        }
    }
}


