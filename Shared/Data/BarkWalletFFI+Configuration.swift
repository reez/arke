//
//  BarkWallet+Configuration.swift
//  Arke
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension BarkWalletFFI {
    
    func getConfig() async throws -> ArkConfigModel {
        // Get wallet configuration
        
        if isPreview {
            // Return mock config
            return ArkConfigModel(
                serverAddress: "https://preview.asp.com",
                esploraAddress: "https://preview.esplora.com",
                bitcoindAddress: nil,
                bitcoindCookiefile: nil,
                bitcoindUser: nil,
                bitcoindPass: nil,
                network: "signet",
                vtxoRefreshExpiryThreshold: 144,
                vtxoExitMargin: 512,
                htlcRecvClaimDelta: 72,
                fallbackFeeRate: 10,
                roundTxRequiredConfirmations: 1
            )
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Fetching wallet config via FFI...")
        
        // Call FFI config method (doesn't throw)
        let ffiConfig = await wallet.config()
        
        print("✅ Config retrieved: \(ffiConfig)")
        
        // Convert FFI Network enum to string
        let networkString = Self.convertFFINetworkToString(ffiConfig.network)
        
        // Convert FFI Config to ArkConfigModel (1:1 mapping of all fields)
        let configModel = ArkConfigModel(
            serverAddress: ffiConfig.serverAddress,
            esploraAddress: ffiConfig.esploraAddress,
            bitcoindAddress: ffiConfig.bitcoindAddress,
            bitcoindCookiefile: ffiConfig.bitcoindCookiefile,
            bitcoindUser: ffiConfig.bitcoindUser,
            bitcoindPass: ffiConfig.bitcoindPass,
            network: networkString,
            vtxoRefreshExpiryThreshold: ffiConfig.vtxoRefreshExpiryThreshold,
            vtxoExitMargin: ffiConfig.vtxoExitMargin,
            htlcRecvClaimDelta: ffiConfig.htlcRecvClaimDelta,
            fallbackFeeRate: ffiConfig.fallbackFeeRate,
            roundTxRequiredConfirmations: ffiConfig.roundTxRequiredConfirmations
        )
        
        return configModel
    }
    
    // MARK: - Debug Helpers
    
    /// Print the entire config object for debugging
    func printFullConfig() {
        print("📋 Full Config Object:")
        print("   Server Address: \(config.serverAddress)")
        print("   Esplora Address: \(config.esploraAddress ?? "nil")")
        print("   Bitcoind Address: \(config.bitcoindAddress ?? "nil")")
        print("   Bitcoind Cookie File: \(config.bitcoindCookiefile ?? "nil")")
        print("   Bitcoind User: \(config.bitcoindUser ?? "nil")")
        print("   Bitcoind Pass: \(config.bitcoindPass != nil ? "[REDACTED]" : "nil")")
        print("   Network: \(config.network)")
        print("   VTXO Refresh Expiry Threshold: \(config.vtxoRefreshExpiryThreshold.map { String($0) } ?? "nil")")
        print("   VTXO Exit Margin: \(config.vtxoExitMargin.map { String($0) } ?? "nil")")
        print("   HTLC Recv Claim Delta: \(config.htlcRecvClaimDelta.map { String($0) } ?? "nil")")
        print("   Fallback Fee Rate: \(config.fallbackFeeRate.map { String($0) } ?? "nil")")
        print("   Round Tx Required Confirmations: \(config.roundTxRequiredConfirmations.map { String($0) } ?? "nil")")
    }
    
    func getArkInfo() async throws -> ArkInfoModel {
        // Get ASP/Ark server information
        
        if isPreview {
            // Create a sample fee schedule for preview
            let sampleFeeSchedule = FeeSchedule(
                board: BoardFeeStructure(minFeeSat: 0, baseFeeSat: 0, ppm: 0),
                offboard: OffboardFeeStructure(
                    baseFeeSat: 0,
                    fixedAdditionalVb: 212,
                    ppmExpiryTable: [
                        PpmExpiryEntry(expiryBlocksThreshold: 0, ppm: 2000),
                        PpmExpiryEntry(expiryBlocksThreshold: 1008, ppm: 4000),
                        PpmExpiryEntry(expiryBlocksThreshold: 2016, ppm: 5000)
                    ]
                ),
                refresh: RefreshFeeStructure(
                    baseFeeSat: 0,
                    ppmExpiryTable: [
                        PpmExpiryEntry(expiryBlocksThreshold: 0, ppm: 0),
                        PpmExpiryEntry(expiryBlocksThreshold: 288, ppm: 2000),
                        PpmExpiryEntry(expiryBlocksThreshold: 1008, ppm: 4000),
                        PpmExpiryEntry(expiryBlocksThreshold: 2016, ppm: 5000)
                    ]
                ),
                lightningReceive: LightningReceiveFeeStructure(baseFeeSat: 0, ppm: 0),
                lightningSend: LightningSendFeeStructure(
                    minFeeSat: 20,
                    baseFeeSat: 0,
                    ppmExpiryTable: [
                        PpmExpiryEntry(expiryBlocksThreshold: 0, ppm: 2000),
                        PpmExpiryEntry(expiryBlocksThreshold: 1008, ppm: 4000),
                        PpmExpiryEntry(expiryBlocksThreshold: 2016, ppm: 5000)
                    ]
                )
            )
            
            return ArkInfoModel(
                network: "signet",
                serverPubkey: "02preview0000000000000000000000000000000000000000000000000000000000",
                roundInterval: "30s",
                nbRoundNonces: 256,
                vtxoExitDelta: 512,
                vtxoExpiryDelta: 1024,
                htlcSendExpiryDelta: 72,
                htlcExpiryDelta: 144,
                maxVtxoAmount: 100000000,
                requiredBoardConfirmations: 6,
                maxUserInvoiceCltvDelta: 288,
                minBoardAmount: 10000,
                offboardFeerate: 10,
                lnReceiveAntiDosRequired: false,
                feeSchedule: sampleFeeSchedule
            )
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Fetching Ark server info via FFI...")
        
        // Call FFI arkInfo method
        guard let ffiArkInfo = await wallet.arkInfo() else {
            print("⚠️ Ark server info not available (not connected)")
            throw BarkWalletFFIError.configurationError("Ark server info not available. Wallet may not be connected to ASP.")
        }
        
        print("✅ Ark server info retrieved")
        
        // Convert FFI ArkInfo to ArkInfoModel
        let networkString = Self.convertFFINetworkToString(ffiArkInfo.network)
        
        // Convert round interval from seconds to string format like "30s"
        let roundIntervalString = "\(ffiArkInfo.roundIntervalSecs)s"
        
        // NOTE: Some fields may not be available in older FFI ArkInfo versions
        // FFI ArkInfo provides all fields we need - 1:1 mapping
        
        // Log the FFI ArkInfo fields
        print("📋 FFI ArkInfo fields:")
        print("   - roundIntervalSecs: \(ffiArkInfo.roundIntervalSecs)")
        print("   - nbRoundNonces: \(ffiArkInfo.nbRoundNonces)")
        print("   - vtxoExitDelta: \(ffiArkInfo.vtxoExitDelta)")
        print("   - vtxoExpiryDelta: \(ffiArkInfo.vtxoExpiryDelta)")
        print("   - htlcSendExpiryDelta: \(ffiArkInfo.htlcSendExpiryDelta)")
        print("   - htlcExpiryDelta: \(ffiArkInfo.htlcExpiryDelta)")
        print("   - maxVtxoAmountSats: \(ffiArkInfo.maxVtxoAmountSats.map { String($0) } ?? "nil")")
        print("   - requiredBoardConfirmations: \(ffiArkInfo.requiredBoardConfirmations)")
        print("   - maxUserInvoiceCltvDelta: \(ffiArkInfo.maxUserInvoiceCltvDelta)")
        print("   - minBoardAmountSats: \(ffiArkInfo.minBoardAmountSats)")
        print("   - offboardFeerateSatPerVb: \(ffiArkInfo.offboardFeerateSatPerVb)")
        print("   - lnReceiveAntiDosRequired: \(ffiArkInfo.lnReceiveAntiDosRequired)")
        print("   - feeScheduleJson: \(ffiArkInfo.feeScheduleJson)")
        
        // Parse fee schedule from JSON string
        let feeSchedule = FeeSchedule.from(jsonString: ffiArkInfo.feeScheduleJson)
        if feeSchedule != nil {
            print("✅ Fee schedule parsed successfully")
        } else {
            print("⚠️ Failed to parse fee schedule JSON")
        }
        
        let arkInfoModel = ArkInfoModel(
            network: networkString,
            serverPubkey: ffiArkInfo.serverPubkey,
            roundInterval: roundIntervalString,
            nbRoundNonces: Int(ffiArkInfo.nbRoundNonces),
            vtxoExitDelta: Int(ffiArkInfo.vtxoExitDelta),
            vtxoExpiryDelta: Int(ffiArkInfo.vtxoExpiryDelta),
            htlcSendExpiryDelta: Int(ffiArkInfo.htlcSendExpiryDelta),
            htlcExpiryDelta: Int(ffiArkInfo.htlcExpiryDelta),
            maxVtxoAmount: ffiArkInfo.maxVtxoAmountSats.map { Int($0) },
            requiredBoardConfirmations: Int(ffiArkInfo.requiredBoardConfirmations),
            maxUserInvoiceCltvDelta: Int(ffiArkInfo.maxUserInvoiceCltvDelta),
            minBoardAmount: Int(ffiArkInfo.minBoardAmountSats),
            offboardFeerate: Int(ffiArkInfo.offboardFeerateSatPerVb),
            lnReceiveAntiDosRequired: ffiArkInfo.lnReceiveAntiDosRequired,
            feeSchedule: feeSchedule
        )
        
        print("✅ ArkInfoModel constructed from FFI data")
        print("   - All fields mapped directly from FFI ArkInfo")
        
        return arkInfoModel
    }
    
    /// Convert FFI Network enum back to string
    private static func convertFFINetworkToString(_ network: Network) -> String {
        switch network {
        case .bitcoin:
            return "bitcoin"
        case .testnet:
            return "testnet"
        case .signet:
            return "signet"
        case .regtest:
            return "regtest"
        }
    }
}
