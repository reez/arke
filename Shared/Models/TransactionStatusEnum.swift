//
//  TransactionTypeModel.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import ArkeUI

enum TransactionStatusEnum: Codable, Equatable, Sendable {
    case confirmed
    case pending
    case failed
    
    var displayName: String {
        switch self {
        case .confirmed: return "Confirmed"
        case .pending: return "Pending"
        case .failed: return "Failed"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .confirmed: return .Arke.green.opacity(0.2)
        case .pending: return .Arke.orange.opacity(0.2)
        case .failed: return .Arke.red.opacity(0.2)
        }
    }
    
    var textColor: Color {
        switch self {
        case .confirmed: return .Arke.green
        case .pending: return .Arke.orange
        case .failed: return .Arke.red
        }
    }
}
