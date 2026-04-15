//
//  Clipboard.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Cross-platform clipboard utility
public func copyToClipboard(_ string: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
    #elseif os(iOS)
    UIPasteboard.general.string = string
    #endif
}

