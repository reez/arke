//
//  ShareHelper.swift
//  Arké
//
//  Created by Assistant on 4/23/26.
//

import SwiftUI
import UIKit

/// Helper for sharing multiple items using UIActivityViewController
struct ShareHelper {
    
    /// Presents the share sheet with multiple items
    /// - Parameters:
    ///   - items: The items to share (can be String, URL, Data, etc.)
    ///   - completion: Optional completion handler
    static func share(items: [Any], from viewController: UIViewController? = nil, completion: (() -> Void)? = nil) {
        guard !items.isEmpty else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Get the appropriate view controller to present from
        let presentingVC = viewController ?? UIApplication.shared.windows.first?.rootViewController
        
        // For iPad, configure popover presentation
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = presentingVC?.view
            popover.sourceRect = CGRect(
                x: presentingVC?.view.bounds.midX ?? 0,
                y: presentingVC?.view.bounds.midY ?? 0,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        activityViewController.completionWithItemsHandler = { _, _, _, _ in
            completion?()
        }
        
        presentingVC?.present(activityViewController, animated: true)
    }
}

/// A view modifier that adds a share action to a view
struct ShareButton: View {
    let items: [Any]
    let label: () -> AnyView
    
    init(items: [Any], @ViewBuilder label: @escaping () -> some View) {
        self.items = items
        self.label = { AnyView(label()) }
    }
    
    var body: some View {
        Button {
            ShareHelper.share(items: items)
        } label: {
            label()
        }
    }
}
