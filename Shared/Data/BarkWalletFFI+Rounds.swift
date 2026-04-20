//
//  BarkWalletFFI+Rounds.swift
//  Arke
//
//  Round management operations
//  Handles round cancellation, progress, pending states, and timing
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension BarkWalletFFI {
    
    // MARK: - Round Management
    
    func cancelAllPendingRounds() async throws {
        // Cancel all pending rounds
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Canceling all pending rounds via FFI...")
        
        do {
            try await wallet.cancelAllPendingRounds()
            print("✅ All pending rounds canceled")
        } catch let error as BarkError {
            print("❌ FFI Error canceling pending rounds: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to cancel pending rounds: \(error.localizedDescription)")
        } catch {
            print("❌ Error canceling pending rounds: \(error)")
            throw error
        }
    }
    
    func cancelPendingRound(roundId: UInt32) async throws {
        // Cancel a specific pending round
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Canceling pending round \(roundId) via FFI...")
        
        do {
            try await wallet.cancelPendingRound(roundId: roundId)
            print("✅ Round \(roundId) canceled")
        } catch let error as BarkError {
            print("❌ FFI Error canceling round: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to cancel round: \(error.localizedDescription)")
        } catch {
            print("❌ Error canceling round: \(error)")
            throw error
        }
    }
    
    func pendingRoundStates() async throws -> [RoundState] {
        // Get all pending round states
        
        if isPreview {
            return []
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            let states = try await wallet.pendingRoundStates()
            print("✅ Retrieved \(states.count) pending round states")
            return states
        } catch let error as BarkError {
            print("❌ FFI Error getting pending round states: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get pending round states: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting pending round states: \(error)")
            throw error
        }
    }
    
    func progressPendingRounds() async throws {
        // Progress pending rounds
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Progressing pending rounds via FFI...")
        
        // Log round details before progression
        await RoundStateDebugger.logPendingRounds(from: wallet, context: "BEFORE progression")
        
        do {
            try await wallet.progressPendingRounds()
            print("✅ Pending rounds progressed")
            
            // Log round details after progression
            await RoundStateDebugger.logPendingRounds(from: wallet, context: "AFTER progression")
        } catch let error as BarkError {
            print("❌ FFI Error progressing pending rounds: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to progress pending rounds: \(error.localizedDescription)")
        } catch {
            print("❌ Error progressing pending rounds: \(error)")
            throw error
        }
    }
    
    func syncPendingBoards() async throws {
        // Sync pending board transactions
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Syncing pending boards via FFI...")
        
        do {
            try await wallet.syncPendingBoards()
            print("✅ Pending boards synced")
        } catch let error as BarkError {
            print("❌ FFI Error syncing pending boards: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to sync pending boards: \(error.localizedDescription)")
        } catch {
            print("❌ Error syncing pending boards: \(error)")
            throw error
        }
    }
    
    func nextRoundStartTime() async throws -> UInt64 {
        // Get the Unix timestamp (seconds) of the next round start
        
        if isPreview {
            // Return a mock timestamp (current time + 5 minutes)
            return UInt64(Date().timeIntervalSince1970) + 300
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            let timestamp = try await wallet.nextRoundStartTime()
            print("✅ Next round start time: \(timestamp)")
            return timestamp
        } catch let error as BarkError {
            print("❌ FFI Error getting next round start time: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get next round start time: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting next round start time: \(error)")
            throw error
        }
    }
}
