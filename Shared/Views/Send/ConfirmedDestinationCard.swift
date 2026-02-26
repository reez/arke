//
//  ConfirmedDestinationCard.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/18/25.
//

import SwiftUI
import ArkeUI

struct ConfirmedDestinationCard: View {
    let paymentRequest: PaymentRequest
    @Binding var selectedDestination: PaymentDestination?
    let rankedDestinations: [PaymentDestinationSelector.RankedDestination]
    let onClear: (() -> Void)?
    let onChangeDestination: () -> Void
    
    // MARK: - Computed Properties
    
    private var hasMultipleViableDestinations: Bool {
        rankedDestinations.filter { $0.viable }.count > 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Address")
                    .font(.title2)
                
                Spacer()
                
                if let onClear {
                    Button(action: onClear) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Selected destination display
            if let destination = selectedDestination {
                VStack(spacing: 12) {
                    // Address card
                    HStack(spacing: 12) {
                        // Icon
                        Image(systemName: iconForDestination(destination))
                            .font(.title2)
                            .foregroundStyle(colorForDestination(destination))
                            .frame(width: 40, height: 40)
                            .background(colorForDestination(destination).opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(destination.format.displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(destination.shortAddress)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorForDestination(destination).opacity(0.3), lineWidth: 1)
                    )
                    
                    // Payment metadata (if available)
                    /*
                    if paymentRequest.label != nil || paymentRequest.message != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            if let label = paymentRequest.label {
                                HStack(spacing: 6) {
                                    Image(systemName: "tag.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(label)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            if let message = paymentRequest.message {
                                HStack(spacing: 6) {
                                    Image(systemName: "message.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    */
                    
                    // Payment method selector (when multiple viable destinations)
                    if hasMultipleViableDestinations {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.subheadline)
                                .foregroundColor(.Arke.blue)
                            
                            Text("\(rankedDestinations.filter { $0.viable }.count) payment options available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: onChangeDestination) {
                                HStack(spacing: 4) {
                                    Text("Change")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline)
                                .foregroundColor(.Arke.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.Arke.blue.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
            } else {
                // No destination selected (error state)
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("No viable payment destination selected")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.Arke.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func iconForDestination(_ destination: PaymentDestination) -> String {
        switch destination.format {
        case .ark:
            return "cube.fill"
        case .lightning, .lightningInvoice:
            return "bolt.fill"
        case .bolt12:
            return "bolt.fill"
        case .bitcoin:
            return "bitcoinsign.circle.fill"
        case .silentPayments:
            return "eye.slash.fill"
        case .bip353:
            return "at.circle.fill"
        case .bip21:
            return "qrcode"
        }
    }
    
    private func colorForDestination(_ destination: PaymentDestination) -> Color {
        switch destination.format {
        case .ark:
            return .Arke.purple
        case .lightning, .lightningInvoice:
            return .Arke.orange
        case .bolt12:
            return .Arke.orange
        case .bitcoin:
            return .Arke.orange
        case .silentPayments:
            return .Arke.blue
        case .bip353:
            return .Arke.green
        case .bip21:
            return .gray
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        // Single destination (Bitcoin)
        if let request = AddressValidator.parsePaymentRequest("bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh") {
            ConfirmedDestinationCard(
                paymentRequest: request,
                selectedDestination: .constant(request.primaryDestination),
                rankedDestinations: [],
                onClear: { print("Clear") },
                onChangeDestination: { print("Change") }
            )
        }
        
        // BIP-21 with label and message
        if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.001&label=Coffee%20Shop&message=Thanks%20for%20your%20order") {
            ConfirmedDestinationCard(
                paymentRequest: request,
                selectedDestination: .constant(request.primaryDestination),
                rankedDestinations: [],
                onClear: { print("Clear") },
                onChangeDestination: { print("Change") }
            )
        }
        
        // Multiple destinations (show change option)
        if let request = AddressValidator.parsePaymentRequest("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?ark=tark1signetaddress&lightning=lnbc1") {
            let mockRanked = request.destinations.enumerated().map { (index, dest) in
                PaymentDestinationSelector.RankedDestination(
                    destination: dest,
                    balanceSource: .ark,
                    availableBalance: 100000,
                    estimatedFee: 100,
                    viable: true,
                    reason: "Available",
                    priority: index
                )
            }
            
            ConfirmedDestinationCard(
                paymentRequest: request,
                selectedDestination: .constant(request.primaryDestination),
                rankedDestinations: mockRanked,
                onClear: { print("Clear") },
                onChangeDestination: { print("Change") }
            )
        }
    }
    .padding()
    .frame(width: 600)
}
