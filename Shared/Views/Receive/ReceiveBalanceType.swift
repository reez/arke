//
//  ReceiveBalanceType.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/21/25.
//

import Foundation

enum ReceiveBalanceType: String, CaseIterable {
    case paymentsAndSavings = "Payments + Savings"
    case payments = "Payments"
    case savings = "Savings"
    case lightning = "Lightning request"
    
    var description: String {
        switch self {
        case .paymentsAndSavings:
            return "Share both, let the sender choose"
        case .payments:
            return "Fast & low fees · Ark network"
        case .savings:
            return "Best security · Bitcoin network"
        case .lightning:
            return "Fast & low fees · Lightning network"
        }
    }
    
    var receiveDescription: String {
        switch self {
        case .payments:
            return "Fast & low fees · Ark network"
        case .savings:
            return "Slower & higher fees · Bitcoin network"
        case .paymentsAndSavings:
            return "Share both, let the sender choose"
        case .lightning:
            return "Fast & low fees · Lightning network"
        }
    }
}
