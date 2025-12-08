//
//  ClipboardService_iOS.swift
//  Ark wallet prototype
//
//  Created by Assistant on 12/8/25.
//

#if os(iOS)
import UIKit

/// iOS implementation of clipboard service using UIPasteboard
final class ClipboardService_iOS: ClipboardServiceProtocol {
    func getCurrentString() -> String? {
        UIPasteboard.general.string
    }
}
#endif
