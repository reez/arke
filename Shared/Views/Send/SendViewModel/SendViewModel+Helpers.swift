//
//  SendViewModel+Helpers.swift
//  Ark wallet prototype
//
//  Created by Assistant on 12/8/25.
//
//  Helper methods for payment request classification and validation.
//

import SwiftUI
import ArkeUI
import Bark

extension SendViewModel {
    
    // MARK: - Payment Request Classification
    
    /// Checks if a payment request is "simple" (bare address without metadata)
    func isSimplePaymentRequest(_ paymentRequest: PaymentRequest) -> Bool {
        return !paymentRequest.hasAlternatives &&
               paymentRequest.amount == nil &&
               paymentRequest.label == nil &&
               paymentRequest.message == nil
    }
}
