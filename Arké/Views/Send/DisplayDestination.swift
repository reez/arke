//
//  DisplayDestination.swift
//  Arké
//
//  Created by Christoph on 11/19/25.
//

/// Helper struct to unify destination display data
struct DisplayDestination {
    let destination: PaymentDestination
    let estimatedFee: Int?
    let balanceSourceName: String?
    let matchedContact: ContactModel?
}
