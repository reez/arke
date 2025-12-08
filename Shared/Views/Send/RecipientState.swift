//
//  RecipientState.swift
//  Arké
//
//  Created by Christoph on 12/8/25.
//

enum RecipientState: Equatable {
    case idle
    case typing
    case valid
    case invalid(String)
    
    static func == (lhs: RecipientState, rhs: RecipientState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.typing, .typing), (.valid, .valid):
            return true
        case (.invalid(let lhsError), .invalid(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}
