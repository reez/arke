//
//  BarkWalletFFI+Maintenance.swift
//  Arke
//
//  Maintenance and refresh operations for wallet health
//  Handles automated and delegated VTXO refresh operations
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension BarkWalletFFI {
    
    // MARK: - Maintenance Operations
    
    func maintenanceRefresh() async throws -> String? {
        // Perform maintenance refresh
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Performing maintenance refresh via FFI...")
        
        do {
            let roundId = try await wallet.maintenanceRefresh()
            
            if let roundId = roundId {
                print("✅ Maintenance refresh initiated. Round ID: \(roundId)")
            } else {
                print("✅ Maintenance refresh completed (no refresh needed)")
            }
            
            return roundId
        } catch let error as BarkError {
            print("❌ FFI Error during maintenance refresh: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to perform maintenance refresh: \(error.localizedDescription)")
        } catch {
            print("❌ Error during maintenance refresh: \(error)")
            throw error
        }
    }
    
    func maybeScheduleMaintenanceRefresh() async throws -> UInt32? {
        // Schedule a maintenance refresh if VTXOs need refreshing
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try await wallet.maybeScheduleMaintenanceRefresh()
        } catch let error as BarkError {
            print("❌ FFI Error scheduling maintenance refresh: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to schedule maintenance refresh: \(error.localizedDescription)")
        } catch {
            print("❌ Error scheduling maintenance refresh: \(error)")
            throw error
        }
    }
    
    func maintenanceWithOnchain() async throws {
        // Full maintenance including onchain wallet sync
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        guard let onchainWallet = onchainWallet else {
            throw BarkWalletFFIError.configurationError("Onchain wallet not initialized")
        }
        
        print("🔧 Performing full maintenance with onchain sync via FFI...")
        
        do {
            try await wallet.maintenanceWithOnchain(onchainWallet: onchainWallet)
            print("✅ Full maintenance completed")
        } catch let error as BarkError {
            print("❌ FFI Error during full maintenance: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to perform full maintenance: \(error.localizedDescription)")
        } catch {
            print("❌ Error during full maintenance: \(error)")
            throw error
        }
    }
    
    // MARK: - Delegated / Non-interactive Operations
    
    func maintenanceDelegated() async throws {
        // Schedules maintenance refresh operations without blocking
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Scheduling delegated maintenance via FFI...")
        
        do {
            try await wallet.maintenanceDelegated()
            print("✅ Delegated maintenance scheduled")
        } catch let error as BarkError {
            print("❌ FFI Error scheduling delegated maintenance: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to schedule delegated maintenance: \(error.localizedDescription)")
        } catch {
            print("❌ Error scheduling delegated maintenance: \(error)")
            throw error
        }
    }
    
    func maintenanceWithOnchainDelegated() async throws {
        // Schedules maintenance with onchain wallet sync without blocking
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        guard let onchainWallet = onchainWallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Scheduling delegated maintenance with onchain sync via FFI...")
        
        do {
            try await wallet.maintenanceWithOnchainDelegated(onchainWallet: onchainWallet)
            print("✅ Delegated maintenance with onchain sync scheduled")
        } catch let error as BarkError {
            print("❌ FFI Error scheduling delegated maintenance with onchain: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to schedule delegated maintenance with onchain: \(error.localizedDescription)")
        } catch {
            print("❌ Error scheduling delegated maintenance with onchain: \(error)")
            throw error
        }
    }
}
