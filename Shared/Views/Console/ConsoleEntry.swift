//
//  ConsoleEntry.swift
//  Arké
//
//  Created by Christoph on 1/5/26.
//

import Foundation

/// Represents a single entry in the console history
struct ConsoleEntry: Identifiable {
    let id = UUID()
    let command: String
    let result: String
    let isError: Bool
    let timestamp: Date
}
