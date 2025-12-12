//
//  SafeAreaExtensions.swift
//  Arké
//
//  Created by Assistant on 12/12/25.
//

import SwiftUI
import UIKit

extension View {
    var safeAreaInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .keyWindow?
            .safeAreaInsets ?? .zero
    }
}
