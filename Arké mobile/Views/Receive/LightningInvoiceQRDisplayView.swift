//
//  LightningInvoiceQRDisplayView.swift
//  Arké
//
//  Created by Assistant on 1/28/26.
//

import SwiftUI
import ArkeUI

/// QR code display view for Lightning invoices (used in QR Code mode)
struct LightningInvoiceQRDisplayView: View {
    let invoice: String
    let extractInvoiceFromJSON: (String) -> String
    let onCopyInvoice: () -> Void
    let showCopySuccess: Bool
    
    private var actualInvoice: String {
        extractInvoiceFromJSON(invoice)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // QR Code
            ReceiveQRCodeDisplaySection_iOS(
                content: actualInvoice,
                title: "Lightning Invoice"
            )
            
            // Invoice details card
            VStack(spacing: 12) {
                // Copyable invoice string
                VStack(spacing: 8) {
                    Text("label_invoice")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        Text(truncatedInvoice)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button {
                            onCopyInvoice()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showCopySuccess ? "checkmark" : "doc.on.doc")
                                    .font(.caption)
                                Text(showCopySuccess ? "Copied!" : "Copy")
                                    .font(.caption)
                            }
                            .foregroundStyle(showCopySuccess ? Color.Arke.green : Color.Arke.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(.regularMaterial)
                .cornerRadius(8)
                
                // Expiration notice
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text("status_expires_1_hour")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var truncatedInvoice: String {
        let invoice = actualInvoice
        guard invoice.count > 40 else { return invoice }
        let start = invoice.prefix(20)
        let end = invoice.suffix(20)
        return "\(start)...\(end)"
    }
}

/// Empty state for when no Lightning invoice has been generated
struct LightningInvoiceQREmptyStateView: View {
    let onSwitchToAddresses: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode")
                .font(.system(size: 40))
                .foregroundStyle(Color.secondary)
            
            Text("Create a lightning request to see and share it here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 40)
            
            Button {
                onSwitchToAddresses()
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.Arke.gold3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glass)
            .tint(Color.Arke.gold)
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
        .background(.regularMaterial)
        .cornerRadius(8)
        .frame(maxHeight: .infinity)
    }
}

#Preview("Invoice Display") {
    LightningInvoiceQRDisplayView(
        invoice: "{\"invoice\":\"lnbc500000n1pjqxj2zpp5qxm6lk4j8rz3z8kyhywvlrxs52nz4k3x7v8x9n2m4j5k6l7m8p9q0qsp5z2y4x6w8v0u2t4s6r8p0n2m4k6j8h0g2f4e6d8c0b2a4x6y8zqrzjqfqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq9qy9qsqsp5qvx0xsjfxp3j8nzwhgnmqx6v7wd3yxklj4hwx7rwvg4tjgekrsq9qrsgqdp4g9qy9qsqsp5qvx0xsjfxp3j8nzwhgnmqx6v7wd3yxklj4hwx7rwvg4tjgekrsq\"}",
        extractInvoiceFromJSON: { input in
            if let data = input.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let invoice = json["invoice"] as? String {
                return invoice
            }
            return input
        },
        onCopyInvoice: {},
        showCopySuccess: false
    )
    .padding()
}

#Preview("Copy Success") {
    LightningInvoiceQRDisplayView(
        invoice: "{\"invoice\":\"lnbc500000n1pjqxj2zpp5qxm6lk4j8rz3z8kyhywvlrxs52nz4k3x7v8x9n2m4j5k6l7m8p9q0qsp5z2y4x6w8v0u2t4s6r8p0n2m4k6j8h0g2f4e6d8c0b2a4x6y8zqrzjqfqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq9qy9qsqsp5qvx0xsjfxp3j8nzwhgnmqx6v7wd3yxklj4hwx7rwvg4tjgekrsq9qrsgqdp4g9qy9qsqsp5qvx0xsjfxp3j8nzwhgnmqx6v7wd3yxklj4hwx7rwvg4tjgekrsq\"}",
        extractInvoiceFromJSON: { input in
            if let data = input.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let invoice = json["invoice"] as? String {
                return invoice
            }
            return input
        },
        onCopyInvoice: {},
        showCopySuccess: true
    )
    .padding()
}

#Preview("Empty State") {
    LightningInvoiceQREmptyStateView(onSwitchToAddresses: {})
        .frame(width: 400, height: 600)
}
