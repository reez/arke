//
//  PaymentRequestInfoBanner.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/18/25.
//

import SwiftUI

struct PaymentRequestInfoBanner: View {
    let paymentRequest: PaymentRequest
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on payment format
            iconView
            
            VStack(alignment: .leading, spacing: 2) {
                Text(headerText)
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text(displayTitle)
                    .font(.title2)
                    .fontWeight(.medium)
                
                if let message = paymentRequest.message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear payment request")
        }
    }
    
    // MARK: - Computed Properties
    
    private var headerText: String {
        if paymentRequest.label != nil {
            return "Payment to"
        } else {
            return "Payment via"
        }
    }
    
    private var displayTitle: String {
        // Priority: label > primary destination format > fallback
        if let label = paymentRequest.label {
            return label
        } else if let primary = paymentRequest.primaryDestination {
            return primary.format.displayName
        } else {
            return "Payment Request"
        }
    }
    
    @ViewBuilder
    private var iconView: some View {
        if let primary = paymentRequest.primaryDestination {
            Image(systemName: iconForFormat(primary.format))
                .font(.title3)
                .frame(width: 48, height: 48)
                .background(colorForFormat(primary.format).opacity(0.15))
                .foregroundColor(colorForFormat(primary.format))
                .clipShape(Circle())
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                )
        } else {
            // Fallback icon
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .frame(width: 48, height: 48)
                .background(Color.gray.opacity(0.1))
                .foregroundColor(.gray)
                .clipShape(Circle())
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                )
        }
    }
    
    // MARK: - Helper Functions
    
    private func iconForFormat(_ format: AddressFormat) -> String {
        switch format {
        case .bitcoin:
            return "bitcoinsign.circle.fill"
        case .ark:
            return "cube.fill"
        case .lightning, .lightningInvoice:
            return "bolt.fill"
        case .silentPayments:
            return "eye.slash.fill"
        case .bip353:
            return "at.circle.fill"
        case .bip21:
            return "qrcode"
        case .bolt12:
            return "bolt.fill"
        }
    }
    
    private func colorForFormat(_ format: AddressFormat) -> Color {
        switch format {
        case .bitcoin:
            return .orange
        case .ark:
            return .purple
        case .lightning, .lightningInvoice:
            return .yellow
        case .silentPayments:
            return .blue
        case .bip353:
            return .green
        case .bip21:
            return .gray
        case .bolt12:
            return .orange
        }
    }
}

// MARK: - Previews

#Preview("Merchant with Label and Message") {
    VStack(spacing: 20) {
        if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.001&label=Coffee%20Shop&message=Order%20%2342") {
            PaymentRequestInfoBanner(
                paymentRequest: request,
                onClear: {}
            )
        }
    }
    .padding()
    .frame(width: 600)
}

#Preview("Merchant with Label Only") {
    VStack(spacing: 20) {
        if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?label=Alice") {
            PaymentRequestInfoBanner(
                paymentRequest: request,
                onClear: {}
            )
        }
    }
    .padding()
    .frame(width: 600)
}

#Preview("Ark Address (No Label)") {
    VStack(spacing: 20) {
        if let request = AddressValidator.parsePaymentRequest("bitcoin:tb1pxks6xl9e05xc3atcewg2tyyzgqm5n6mj6aduss3f0pau27206stsax872h?ark=tark1pm6sr0fpzqqpu4k5llkn6wdswx48fwjjujgu4gm679lqwudrzghz7a2rx7wuup9cpqq6ssw20") {
            PaymentRequestInfoBanner(
                paymentRequest: request,
                onClear: {}
            )
        }
    }
    .padding()
    .frame(width: 600)
}

#Preview("Lightning Invoice") {
    VStack(spacing: 20) {
        if let request = AddressValidator.parsePaymentRequest("lnbc1000n1pj9x7zmpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpusp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygs9qrsgqwfqlw6qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqgpxwxh3") {
            PaymentRequestInfoBanner(
                paymentRequest: request,
                onClear: {}
            )
        }
    }
    .padding()
    .frame(width: 600)
}

#Preview("Bitcoin Address (No Label)") {
    VStack(spacing: 20) {
        if let request = AddressValidator.parsePaymentRequest("bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
            PaymentRequestInfoBanner(
                paymentRequest: request,
                onClear: {}
            )
        }
    }
    .padding()
    .frame(width: 600)
}

#Preview("BIP-21 with Multiple Destinations") {
    VStack(spacing: 20) {
        if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.001&label=Multi-Payment&ark=tark1test&lightning=lnbc1") {
            PaymentRequestInfoBanner(
                paymentRequest: request,
                onClear: {}
            )
        }
    }
    .padding()
    .frame(width: 600)
}

#Preview("Silent Payments") {
    VStack(spacing: 20) {
        if let request = AddressValidator.parsePaymentRequest("sp1qqgste7k9hx0qftg6qmwlkqtwuy6cycyavzmzj85c6qdfhjdpdjtdgqjuexzk6murw56suy3e0rd2cgqvycxttddwsvgxe2usfpxumr70xc9pkqwv") {
            PaymentRequestInfoBanner(
                paymentRequest: request,
                onClear: {}
            )
        }
    }
    .padding()
    .frame(width: 600)
}

#Preview("Long Merchant Name") {
    VStack(spacing: 20) {
        if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?label=The%20Really%20Long%20Coffee%20Shop%20Name%20Downtown&message=Your%20delicious%20coffee%20is%20ready") {
            PaymentRequestInfoBanner(
                paymentRequest: request,
                onClear: {}
            )
        }
    }
    .padding()
    .frame(width: 600)
}
