//
//  ActionButtonsView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/21/25.
//

import SwiftUI

struct ActionButtonsView: View {
    let selectedBalance: ReceiveBalanceType
    let shareContent: String?
    let hasQRContent: Bool
    let onShowQRCode: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Share button
            if let shareContent = shareContent {
                ShareLink(item: shareContent) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                }
                .buttonStyle(ArkeButtonStyle(size: .medium))
                .controlSize(.large)
            }
            
            // QR Code button
            if hasQRContent {
                Button {
                    onShowQRCode()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "qrcode")
                    }
                }
                .buttonStyle(ArkeIconButtonStyle(size: .medium, variant: .ghost))
            }
        }
    }
}
