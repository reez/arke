//
//  AddressFormatsInfoView.swift
//  Arké
//
//  Created by Christoph on 11/17/25.
//

import SwiftUI

struct AddressFormatsInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supported Address Formats")
                .font(.headline)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                AddressFormatRow(
                    title: "Bitcoin Address",
                    examples: ["bc1q...", "1...", "3...", "tb1q..."],
                    description: "Standard Bitcoin addresses (P2PKH, P2SH, Bech32)"
                )
                
                AddressFormatRow(
                    title: "Silent Payments (BIP-352)",
                    examples: ["sp1...", "tsp1..."],
                    description: "Privacy-enhanced reusable Bitcoin addresses"
                )
                
                AddressFormatRow(
                    title: "Ark Address",
                    examples: ["ark1q...", "tark1q..."],
                    description: "Ark protocol addresses for off-chain payments"
                )
                
                AddressFormatRow(
                    title: "Lightning Address",
                    examples: ["user@domain.com"],
                    description: "Human-readable Lightning payment addresses"
                )
                
                AddressFormatRow(
                    title: "Lightning Invoice",
                    examples: ["lnbc...", "lntb..."],
                    description: "Lightning network payment requests"
                )
                
                AddressFormatRow(
                    title: "BIP-353 Address",
                    examples: ["₿user.domain.com"],
                    description: "Human-readable Bitcoin addresses using DNS"
                )
                
                AddressFormatRow(
                    title: "BIP-21 Payment URI",
                    examples: ["bitcoin:bc1q...?amount=0.001"],
                    description: "Bitcoin URIs with embedded payment details"
                )
            }
            
            Text("Note: Network support includes mainnet, testnet, signet, and regtest where applicable.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .frame(width: 500)
    }
}

struct AddressFormatRow: View {
    let title: String
    let examples: [String]
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 6) {
                ForEach(examples, id: \.self) { example in
                    Text(example)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview("Address Formats Info") {
    AddressFormatsInfoView()
}

#Preview("Single Address Format Row") {
    AddressFormatRow(
        title: "Bitcoin Address",
        examples: ["bc1q...", "1...", "3...", "tb1q..."],
        description: "Standard Bitcoin addresses (P2PKH, P2SH, Bech32)"
    )
    .padding()
}
