//
//  SendModalState.swift
//  Arké
//
//  Created by Christoph on 12/8/25.
//

enum SendModalState: Equatable {
    case sending
    case success
    case error(String)
}
