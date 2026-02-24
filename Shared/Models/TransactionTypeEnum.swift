//
//  TransactionTypeModel.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import ArkeUI

enum TransactionTypeEnum: Codable, Equatable, Sendable {
    case sent
    case received
    case transfer
    case pending
    
    var displayName: String {
        switch self {
        case .sent: return "Sent"
        case .received: return "Received"
        case .transfer: return "Transfer"
        case .pending: return "Pending"
        }
    }
    
    var iconName: String {
        switch self {
        case .sent: return "arrow.up"
        case .received: return "arrow.down"
        case .transfer: return "repeat"
        case .pending: return "clock"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .sent: return .gray
        case .received: return .Arke.green
        case .transfer: return .gray
        case .pending: return .Arke.blue
        }
    }
    
    var amountColor: Color {
        switch self {
        case .sent: return .primary
        case .received: return .Arke.green
        case .transfer: return .gray
        case .pending: return .Arke.blue
        }
    }
}
