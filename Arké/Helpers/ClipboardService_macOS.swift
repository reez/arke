//
//  ClipboardService_macOS.swift
//  Ark wallet prototype
//
//  Created by Assistant on 12/8/25.
//

#if os(macOS)
import AppKit

/// macOS implementation of clipboard service using NSPasteboard
final class ClipboardService_macOS: ClipboardServiceProtocol {
    func getCurrentString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
    
    /// Checks if clipboard has string content
    /// On macOS, we can freely read clipboard without permission dialogs
    func hasStrings() -> Bool {
        NSPasteboard.general.string(forType: .string) != nil
    }
}
#endif
