//
//  Untitled.swift
//  Arke
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension BarkWalletFFI {
    
    func getArkBalance() async throws -> ArkBalanceResponse {
        // Preview mode handling
        if isPreview {
            return ArkBalanceResponse(
                spendableSat: 50000,
                pendingLightningSendSat: 0,
                pendingInRoundSat: 0,
                pendingExitSat: 0,
                pendingBoardSat: 0
            )
        }
        
        // Log wallet initialization status
        print("🔍 Wallet initialized: \(wallet != nil) at \(Date())")
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Fetching balance via FFI...")
        
        do {
            // Call FFI balance method
            let ffiBalance = try await wallet.balance()
            
            print("✅ Balance retrieved:")
            print("   Full FFI Balance: \(ffiBalance)")
            print("   Spendable: \(ffiBalance.spendableSats) sats")
            print("   Pending Lightning Send: \(ffiBalance.pendingLightningSendSats) sats")
            print("   Pending in round: \(ffiBalance.pendingInRoundSats) sats")
            print("   Pending exit: \(ffiBalance.pendingExitSats) sats")
            print("   Pending board: \(ffiBalance.pendingBoardSats) sats")
            
            // Convert FFI Balance to ArkBalanceResponse
            let response = ArkBalanceResponse(
                spendableSat: Int(ffiBalance.spendableSats),
                pendingLightningSendSat: Int(ffiBalance.pendingLightningSendSats),
                pendingInRoundSat: Int(ffiBalance.pendingInRoundSats),
                pendingExitSat: Int(ffiBalance.pendingExitSats),
                pendingBoardSat: Int(ffiBalance.pendingBoardSats)
            )
            
            return response
            
        } catch let error as BarkError {
            print("❌ FFI Error fetching balance: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get balance: \(error.localizedDescription)")
        } catch {
            print("❌ Error fetching balance: \(error)")
            throw error
        }
    }
    
    func getArkAddress() async throws -> String {
        // Log call stack to trace where this is being called from
#if DEBUG
        print("🔧 [ADDRESS TRACE] getArkAddress() CALLED")
        // Note: Ark addresses can be safely reused without privacy concerns.
        // The Rust wallet manages address derivation and tracks all previously
        // generated addresses for incoming payment detection.
        print("   📞 Call stack:")
        Thread.callStackSymbols.prefix(6).enumerated().forEach { index, symbol in
            print("      \(index): \(symbol)")
        }
#endif
        
        // Preview mode handling
        if isPreview {
            return "ark1preview0000000000000000000000000000000000000000000000000000000"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Generating new address via FFI...")
        print("🔍 [DEBUG] Current wallet state:")
        print("   - Wallet object exists: \(self.wallet != nil)")
        print("   - Config server: \(config.serverAddress)")
        print("   - Config esplora: \(config.esploraAddress ?? "nil")")
        
        // Try to get server info first to diagnose connection
        print("🔍 [DEBUG] Attempting to fetch server info before address generation...")
        if let arkInfo = await wallet.arkInfo() {
            print("✅ [DEBUG] Server connected! ArkInfo available:")
            print("   - Round interval: \(arkInfo.roundIntervalSecs)s")
            print("   - VTXO expiry: \(arkInfo.vtxoExpiryDelta) blocks")
        } else {
            print("⚠️ [DEBUG] Cannot fetch ArkInfo (returns nil - server may not be connected)")
            print("🔍 [DEBUG] This explains why address generation will fail")
        }
        
        do {
            // Call FFI newAddressWithIndex method to get address with index
            let addressWithIndex = try await wallet.newAddressWithIndex()
            
            print("✅ New address generated with index:")
            print("   Address: \(addressWithIndex.address)")
            print("   Index: \(addressWithIndex.index)")
            
            return addressWithIndex.address
            
        } catch let error as BarkError {
            print("❌ FFI Error generating address: \(error)")
            print("🔍 [DEBUG] BarkError details:")
            print("   - Error type: \(type(of: error))")
            print("   - Description: \(error.localizedDescription)")
            
            // Check if this is specifically a connection error
            if case .ServerConnection(let message) = error {
                print("🔍 [DEBUG] Confirmed: This is a ServerConnection error")
                print("   - Message: \(message)")
                print("💡 [HINT] The Rust wallet needs an explicit connection step")
                print("   Possible solutions:")
                print("   1. Call wallet.connect() or similar before address generation")
                print("   2. Check if forceRescan parameter establishes connection")
                print("   3. Investigate if there's a network initialization delay")
            }
            
            throw BarkWalletFFIError.configurationError("Failed to generate address: \(error.localizedDescription)")
        } catch {
            print("❌ Error generating address: \(error)")
            throw error
        }
    }
    
    func getOnchainAddress() async throws -> String {
        // Get a Bitcoin onchain address from the BDK onchain wallet
        
        if isPreview {
            return "tb1preview00000000000000000000000000000000000000000000"
        }
        
        // Ensure onchain wallet is initialized
        guard let onchainWallet = onchainWallet else {
            throw BarkWalletFFIError.configurationError("Onchain wallet not initialized")
        }
        
        print("🔧 Generating onchain address from built-in wallet...")
        
        do {
            // Get address from built-in OnchainWallet
            let address = try await onchainWallet.newAddress()
            
            print("✅ Onchain address generated")
            print("   Address: \(address)")
            
            return address
            
        } catch {
            print("❌ Error generating onchain address: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to generate onchain address: \(error.localizedDescription)")
        }
    }
    
    func getOnchainBalance() async throws -> OnchainBalanceResponse {
        // Get onchain Bitcoin balance from the BDK wallet
        // This waits for initial sync to complete to avoid returning stale data
        
        if isPreview {
            return OnchainBalanceResponse(
                totalSat: 0,
                confirmedSat: 0,
                pendingSat: 0
            )
        }
        
        // Ensure onchain wallet is initialized
        guard let onchainWallet = onchainWallet else {
            throw BarkWalletFFIError.configurationError("Onchain wallet not initialized")
        }
        
        print("🔧 Fetching onchain balance via FFI...")
        
        do {
            // Call built-in wallet's balance method
            let ffiBalance = try await onchainWallet.balance()
            
            print("✅ Onchain balance retrieved:")
            print("   Total: \(ffiBalance.totalSats) sats")
            print("   Confirmed: \(ffiBalance.confirmedSats) sats")
            print("   Pending: \(ffiBalance.pendingSats) sats")
            
            // Convert FFI OnchainBalance to OnchainBalanceResponse (direct 1:1 mapping)
            let response = OnchainBalanceResponse(
                totalSat: Int(ffiBalance.totalSats),
                confirmedSat: Int(ffiBalance.confirmedSats),
                pendingSat: Int(ffiBalance.pendingSats)
            )
            
            return response
            
        } catch let error as BarkError {
            print("❌ FFI Error fetching onchain balance: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get onchain balance: \(error.localizedDescription)")
        } catch {
            print("❌ Error fetching onchain balance: \(error)")
            throw error
        }
    }
}
