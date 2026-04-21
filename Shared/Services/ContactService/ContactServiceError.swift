//
//  ContactServiceError.swift
//  Arké
//
//  Error types for ContactService operations
//

import Foundation

/// Errors that can occur during contact service operations
enum ContactServiceError: LocalizedError {
    case noModelContext
    case contactNotFound(UUID)
    case transactionNotFound(String)
    case contactAlreadyExists(String)
    case contactAlreadyAssigned
    case assignmentNotFound
    case invalidAddress(String)
    case duplicateAddress(String)
    case addressNotFound(UUID)
    case multiplePrimaryAddresses(UUID)
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "Database context not available"
        case .contactNotFound(let id):
            return "Contact with ID \(id) not found"
        case .transactionNotFound(let txid):
            return "Transaction with ID \(txid) not found"
        case .contactAlreadyExists(let name):
            return "Contact '\(name)' already exists"
        case .contactAlreadyAssigned:
            return "Contact is already assigned to this transaction"
        case .assignmentNotFound:
            return "Contact assignment not found"
        case .invalidAddress(let address):
            return "Invalid address format: \(address)"
        case .duplicateAddress(let address):
            return "Address already exists: \(address)"
        case .addressNotFound(let id):
            return "Address with ID \(id) not found"
        case .multiplePrimaryAddresses(let contactId):
            return "Multiple primary addresses found for contact \(contactId)"
        case .custom(let message):
            return message
        }
    }
}
