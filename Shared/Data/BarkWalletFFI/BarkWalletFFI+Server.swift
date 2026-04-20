//
//  BarkWalletFFI+Server.swift
//  Arke
//
//  Server connection management and sync operations
//  Handles connection establishment, polling, and wallet synchronization
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension BarkWalletFFI {
    
    // MARK: - Server Connection
    
    /// Attempts to establish connection to the Ark server
    /// This should be called after wallet is opened and before operations requiring server access
    /// - Returns: `true` if connection established, `false` otherwise
    @discardableResult
    func ensureServerConnection() async -> Bool {
        guard let wallet = wallet else {
            print("⚠️ [ensureServerConnection] No wallet - cannot connect")
            return false
        }
        
        print("🔌 [ensureServerConnection] Attempting to establish server connection...")
        print("   Target server: \(config.serverAddress)")
        
        // Strategy 1: Try to fetch ArkInfo (this requires server connection)
        // Note: arkInfo() returns ArkInfo? (optional), doesn't throw
        if let arkInfo = await wallet.arkInfo() {
            print("✅ [ensureServerConnection] Server connection verified!")
            print("   Round interval: \(arkInfo.roundIntervalSecs)s")
            return true
        } else {
            print("❌ [ensureServerConnection] Cannot fetch ArkInfo (returns nil)")
            print("🔍 [ensureServerConnection] Investigating if wallet needs explicit connection...")
            
            // TODO: Check Rust FFI documentation for:
            // - wallet.connect()
            // - wallet.sync()
            // - wallet.refreshServerInfo()
            // Or any method that establishes connection
            
            return false
        }
    }
    
    /// Polls for server connection at regular intervals until connected or timeout
    /// - Parameters:
    ///   - intervalSeconds: How often to check (default: 1 second)
    ///   - timeoutSeconds: Maximum time to wait (default: 20 seconds)
    /// - Returns: `true` if connection established, `false` if timeout reached
    @discardableResult
    func waitForServerConnection(intervalSeconds: TimeInterval = 1.0, timeoutSeconds: TimeInterval = 20.0) async -> Bool {
        guard let wallet = wallet else {
            print("⚠️ [waitForServerConnection] No wallet - cannot connect")
            return false
        }
        
        let startTime = Date()
        var attemptCount = 0
        
        print("⏳ [waitForServerConnection] Starting connection polling...")
        print("   Check interval: \(intervalSeconds)s")
        print("   Timeout: \(timeoutSeconds)s")
        print("   Target server: \(config.serverAddress)")
        
        while Date().timeIntervalSince(startTime) < timeoutSeconds {
            attemptCount += 1
            let elapsed = Date().timeIntervalSince(startTime)
            
            print("🔍 [waitForServerConnection] Attempt #\(attemptCount) (elapsed: \(String(format: "%.1f", elapsed))s)")
            
            // Try to fetch ArkInfo to check connection
            if let arkInfo = await wallet.arkInfo() {
                let totalTime = Date().timeIntervalSince(startTime)
                print("✅ [waitForServerConnection] Connection established!")
                print("   Total time: \(String(format: "%.2f", totalTime))s")
                print("   Attempts: \(attemptCount)")
                print("   Round interval: \(arkInfo.roundIntervalSecs)s")
                print("   VTXO expiry: \(arkInfo.vtxoExpiryDelta) blocks")
                return true
            }
            
            // Wait before next attempt
            print("   ⏸️ No connection yet, waiting \(intervalSeconds)s before retry...")
            try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
        }
        
        // Timeout reached
        let totalTime = Date().timeIntervalSince(startTime)
        print("❌ [waitForServerConnection] Timeout reached after \(String(format: "%.2f", totalTime))s")
        print("   Total attempts: \(attemptCount)")
        print("   Server may be unreachable or wallet needs explicit connection step")
        
        return false
    }
    
    // MARK: - Sync Operations
    
    // DIAGNOSTIC: Test basic connectivity to the server
    private func testServerConnectivity() async {
        guard let url = URL(string: config.serverAddress) else {
            print("🔍 [DIAGNOSTIC] Invalid server URL")
            return
        }
        
        print("🔍 [DIAGNOSTIC] Testing connection to: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url, timeoutInterval: 5.0)
            request.httpMethod = "HEAD"
            
            let startTime = Date()
            let (_, response) = try await URLSession.shared.data(for: request)
            let endTime = Date()
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 [DIAGNOSTIC] Server response:")
                print("   - Status Code: \(httpResponse.statusCode)")
                print("   - Response Time: \(endTime.timeIntervalSince(startTime)) seconds")
                print("   - Headers: \(httpResponse.allHeaderFields)")
            }
        } catch {
            print("🔍 [DIAGNOSTIC] Server connectivity test failed: \(error)")
            print("   - Error type: \(type(of: error))")
            print("   - Error description: \(error.localizedDescription)")
        }
    }
    
    func sync() async throws {
        // Synchronize wallet state with the ASP server
        
        if isPreview {
            print("ℹ️ Mock: Synced wallet (preview mode)")
            return
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔄 Syncing wallet with ASP server...")
        
        do {
            // Sync the onchain wallet if available (non-fatal if it fails)
            if let onchainWallet = onchainWallet {
                do {
                    _ = try await onchainWallet.sync()
                    print("✅ Onchain wallet synced successfully")
                } catch {
                    // Don't crash the app if onchain sync fails
                    // This can happen if Esplora is unreachable or returns unexpected data
                    print("⚠️ Onchain wallet sync failed (non-fatal): \(error)")
                    print("   Continuing with Ark wallet sync...")
                }
            }
            
            // Call FFI sync method
            _ = try await wallet.sync()
            
            print("✅ Wallet synced successfully")
            
        } catch let error as BarkError {
            print("❌ FFI Error syncing wallet: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to sync wallet: \(error.localizedDescription)")
        } catch {
            print("❌ Error syncing wallet: \(error)")
            throw error
        }
    }
    
    // MARK: - Server Connection (New in FFI)
    
    func refreshServer() async throws {
        // Refresh the Ark server connection
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Refreshing server connection via FFI...")
        
        do {
            try await wallet.refreshServer()
            print("✅ Server connection refreshed")
        } catch let error as BarkError {
            print("❌ FFI Error refreshing server: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to refresh server: \(error.localizedDescription)")
        } catch {
            print("❌ Error refreshing server: \(error)")
            throw error
        }
    }
}
