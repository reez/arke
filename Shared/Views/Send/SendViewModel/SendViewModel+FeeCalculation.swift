//
//  SendViewModel+FeeCalculation.swift
//  Ark wallet prototype
//
//  Created by Assistant on 12/8/25.
//
//  Fee calculation with caching for Lightning and Ark payments to avoid
//  repeated API calls during amount entry.
//

import SwiftUI
import ArkeUI
import Bark

extension SendViewModel {
    
    // MARK: - Ark Fee Estimation
    
    /// Calculates Ark payment fee for the current amount and destination
    /// Caches the result to avoid repeated API calls for the same amount
    func calculateArkFee() async {
        print("🏛️ [SendViewModel] calculateArkFee() called")
        print("   → isArkDestination: \(isArkDestination)")
        print("   → selectedDestination: \(selectedDestination?.format.rawValue ?? "nil")")
        
        guard isArkDestination else {
            print("   → Not an Ark destination, clearing cache")
            cachedArkFee = nil
            cachedArkFeeAmount = nil
            return
        }
        
        // Determine the amount to use for fee estimation
        let amountToEstimate: Int
        if let paymentAmount = currentPaymentRequest?.amount {
            // Use embedded payment request amount
            print("   → Using payment request amount: \(paymentAmount) sats")
            amountToEstimate = paymentAmount
        } else if let enteredAmount = Int(amount), enteredAmount > 0 {
            // Use manually entered amount
            print("   → Using entered amount: \(enteredAmount) sats")
            amountToEstimate = enteredAmount
        } else {
            // No amount available, clear cache and return
            print("   → No amount available (paymentRequest: \(currentPaymentRequest?.amount?.description ?? "nil"), entered: '\(amount)')")
            cachedArkFee = nil
            cachedArkFeeAmount = nil
            return
        }
        
        // Check if we already have a cached fee for this amount
        if cachedArkFee != nil, cachedArkFeeAmount == amountToEstimate {
            print("   → Using cached fee: \(cachedArkFee!) sats")
            return
        }
        
        print("   → Calling walletManager.estimateArkoorPaymentFee(amountSats: \(amountToEstimate))")
        do {
            let feeEstimate = try await walletManager.estimateArkoorPaymentFee(amountSats: UInt64(amountToEstimate))
            cachedArkFee = Int(feeEstimate.feeSats)
            cachedArkFeeAmount = amountToEstimate
            print("   ✅ Ark fee estimated: \(feeEstimate.feeSats) sats for \(amountToEstimate) sats")
        } catch {
            print("   ❌ Failed to estimate Ark fee: \(error)")
            // Fall back to zero fee on error (Ark payments typically have no fee)
            cachedArkFee = nil
            cachedArkFeeAmount = nil
        }
    }
    
    // MARK: - Lightning Fee Estimation
    
    /// Calculates Lightning send fee for the current amount and destination
    /// Caches the result to avoid repeated API calls for the same amount
    func calculateLightningFee() async {
        print("⚡️ [SendViewModel] calculateLightningFee() called")
        print("   → isLightningDestination: \(isLightningDestination)")
        print("   → selectedDestination: \(selectedDestination?.format.rawValue ?? "nil")")
        
        guard isLightningDestination else {
            print("   → Not a Lightning destination, clearing cache")
            cachedLightningFee = nil
            cachedLightningFeeAmount = nil
            return
        }
        
        // Determine the amount to use for fee estimation
        let amountToEstimate: Int
        if let paymentAmount = currentPaymentRequest?.amount {
            // Use embedded payment request amount (e.g., Lightning invoice)
            print("   → Using payment request amount: \(paymentAmount) sats")
            amountToEstimate = paymentAmount
        } else if let enteredAmount = Int(amount), enteredAmount > 0 {
            // Use manually entered amount
            print("   → Using entered amount: \(enteredAmount) sats")
            amountToEstimate = enteredAmount
        } else {
            // No amount available, clear cache and return
            print("   → No amount available (paymentRequest: \(currentPaymentRequest?.amount?.description ?? "nil"), entered: '\(amount)')")
            cachedLightningFee = nil
            cachedLightningFeeAmount = nil
            return
        }
        
        // Check if we already have a cached fee for this amount
        if cachedLightningFee != nil, cachedLightningFeeAmount == amountToEstimate {
            print("   → Using cached fee: \(cachedLightningFee!) sats")
            return
        }
        
        print("   → Calling walletManager.estimateLightningSendFee(amountSats: \(amountToEstimate))")
        do {
            let feeEstimate = try await walletManager.estimateLightningSendFee(amountSats: UInt64(amountToEstimate))
            cachedLightningFee = Int(feeEstimate.feeSats)
            cachedLightningFeeAmount = amountToEstimate
            print("   ✅ Lightning fee estimated: \(feeEstimate) sats for \(amountToEstimate) sats")
        } catch {
            print("   ❌ Failed to estimate Lightning fee: \(error)")
            // Fall back to static estimate on error
            cachedLightningFee = nil
            cachedLightningFeeAmount = nil
        }
    }
}
