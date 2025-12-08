//
//  ClipboardServiceProtocol.swift
//  Ark wallet prototype
//
//  Created by Assistant on 12/8/25.
//

import Foundation

/// Protocol for platform-agnostic clipboard access
protocol ClipboardServiceProtocol {
    /// Returns the current string content from the system clipboard, if available
    func getCurrentString() -> String?
}
