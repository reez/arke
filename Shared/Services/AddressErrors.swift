//
//  AddressErrors.swift
//  Ark wallet prototype
//
//  Created by Assistant on 1/12/26.
//

import Foundation

/// Errors related to address generation and management
enum AddressError: LocalizedError {
    case gapLimitExceeded(unusedCount: Int)
    case invalidAddressType
    case addressNotFound(String)
    case duplicateAddress(String)
    
    var errorDescription: String? {
        switch self {
        case .gapLimitExceeded(let count):
            return "Gap limit exceeded: \(count) unused addresses. Please use an existing address before generating more."
        case .invalidAddressType:
            return "Invalid address type specified."
        case .addressNotFound(let address):
            return "Address not found: \(address)"
        case .duplicateAddress(let address):
            return "Address already exists: \(address)"
        }
    }
}
