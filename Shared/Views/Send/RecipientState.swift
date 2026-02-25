//
//  RecipientState.swift
//  Arké
//
//  Created by Christoph on 12/8/25.
//

enum RecipientState: Equatable {
    case idle
    case typing
    case valid                          // Non-BIP-353 valid addresses
    case validBIP353Format              // BIP-353 format detected, awaiting resolution
    case resolvingBIP353                // DNS lookup in progress
    case bip353Resolved(String)         // Successfully resolved (stores original BIP-353 address)
    case invalid(String)
    
    static func == (lhs: RecipientState, rhs: RecipientState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.typing, .typing), (.valid, .valid):
            return true
        case (.validBIP353Format, .validBIP353Format), (.resolvingBIP353, .resolvingBIP353):
            return true
        case (.bip353Resolved(let lhsAddr), .bip353Resolved(let rhsAddr)):
            return lhsAddr == rhsAddr
        case (.invalid(let lhsError), .invalid(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}
