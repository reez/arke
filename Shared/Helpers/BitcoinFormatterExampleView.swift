//
//  BitcoinFormatterExampleView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/13/25.
//

import SwiftUI

/// A demonstration view showing how different Bitcoin amounts are formatted
/// across all four format types. Useful for testing and documentation.
struct BitcoinFormatterExampleView: View {
    
    @AppStorage(BitcoinAmountFormat.userDefaultsKey)
    private var selectedFormat: BitcoinAmountFormat = .defaultFormat
    
    private let exampleAmounts: [(label: String, sats: Int)] = [
        ("1 satoshi", 1),
        ("100 sats", 100),
        ("1,000 sats", 1_000),
        ("10,000 sats", 10_000),
        ("100,000 sats (0.001 BTC)", 100_000),
        ("1,000,000 sats (0.01 BTC)", 1_000_000),
        ("10,000,000 sats (0.1 BTC)", 10_000_000),
        ("1 BTC", 100_000_000),
        ("21 BTC", 2_100_000_000),
        ("21 Million BTC (max supply)", 2_100_000_000_000_000),
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                
                Divider()
                
                currentFormatSection
                
                Divider()
                
                examplesSection
                
                Divider()
                
                transactionExamplesSection
            }
            .padding()
        }
        .navigationTitle("Bitcoin Formatter Examples")
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bitcoin Formatter Demo")
                .font(.system(size: 28, weight: .bold, design: .serif))
            
            Text("This view demonstrates how Bitcoin amounts are formatted based on your selected format preference and system locale.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Current Format Section
    
    private var currentFormatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Format")
                .font(.headline)
            
            HStack {
                Text("Selected:")
                    .foregroundColor(.secondary)
                Text(selectedFormat.displayName)
                    .fontWeight(.semibold)
                Spacer()
                Text("Example: \(selectedFormat.exampleFormat)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Change in Settings to see different formats")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Examples Section
    
    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount Examples")
                .font(.headline)
            
            ForEach(exampleAmounts, id: \.sats) { example in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(example.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(BitcoinFormatter.shared.formatAmount(example.sats))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Transaction Examples Section
    
    private var transactionExamplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transaction Formatting Examples")
                .font(.headline)
            
            Text("With Sign Prefixes")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Group {
                HStack {
                    Text("Received:")
                        .frame(width: 100, alignment: .leading)
                    Text(BitcoinFormatter.shared.formatTransactionAmount(
                        1_000_000,
                        transactionType: .received
                    ))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                    Spacer()
                }
                
                HStack {
                    Text("Sent:")
                        .frame(width: 100, alignment: .leading)
                    Text(BitcoinFormatter.shared.formatTransactionAmount(
                        1_000_000,
                        transactionType: .sent
                    ))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red)
                    Spacer()
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            Text("Accounting Style (Symbol at End)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Group {
                HStack {
                    Text("Received:")
                        .frame(width: 100, alignment: .leading)
                    Text(BitcoinFormatter.shared.formatAccountingAmount(
                        5_000_000,
                        transactionType: .received
                    ))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                    Spacer()
                }
                
                HStack {
                    Text("Sent:")
                        .frame(width: 100, alignment: .leading)
                    Text(BitcoinFormatter.shared.formatAccountingAmount(
                        5_000_000,
                        transactionType: .sent
                    ))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BitcoinFormatterExampleView()
    }
}

#Preview("With Different Format") {
    NavigationStack {
        BitcoinFormatterExampleView()
    }
    .onAppear {
        UserDefaults.standard.set(
            BitcoinAmountFormat.satoshis.rawValue,
            forKey: BitcoinAmountFormat.userDefaultsKey
        )
    }
}
