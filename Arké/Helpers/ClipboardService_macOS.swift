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
}
#endif
