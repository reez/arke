//
//  SendViewModel+FeeCalculation.swift
//  Ark wallet prototype
//
//  Created by Assistant on 12/8/25.
//
//  Fee calculation with caching for Lightning payments to avoid
//  repeated API calls during amount entry.
//

import SwiftUI
import ArkeUI
import Bark

extension SendViewModel {
    
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
