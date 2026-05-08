//
//  PaymentInfoReceivedSheet.swift
//  Arké
//
//  Sheet displayed when payment info is received via proximity exchange
//

import SwiftUI
import SwiftData
import ArkeUI

struct PaymentInfoReceivedSheet: View {
    let receivedInfo: ReceivedPaymentInfo
    let onPay: (String) -> Void
    let onAddToContacts: (String, String, Data?) -> Void
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Query private var contacts: [PersistentContact]
    
    // Parse BIP-21 URI to extract address and label
    private var parsedURI: ParsedBIP21URI {
        BIP21URIHelper.parseBIP21URI(receivedInfo.bip21URI)
    }
    
    // Check if this address already exists in contacts
    private var existingContact: PersistentContact? {
        contacts.first { contact in
            contact.addresses?.contains { address in
                address.normalizedAddress == parsedURI.address.lowercased()
            } ?? false
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    // Avatar or default icon
                    if let avatarData = receivedInfo.avatarData,
                       let uiImage = UIImage(data: avatarData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.Arke.blue.opacity(0.3), lineWidth: 3)
                            )
                            .padding(.top, 24)
                    } else {
                        Image(systemName: "wave.3.right.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.Arke.blue)
                            .padding(.top, 24)
                    }
                    
                    Text("Payment Info Received")
                        .font(.system(size: 30, design: .serif))
                    
                    if let label = parsedURI.label, !label.isEmpty {
                        Text("From \(label)")
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.bottom, 32)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Contact info if exists
                        if let contact = existingContact {
                            contactInfoSection(contact: contact)
                        }
                        
                        // Ark Address section (if present in BIP-21 URI)
                        if let arkAddress = parsedURI.arkAddress, !arkAddress.isEmpty {
                            arkAddressSection(arkAddress: arkAddress)
                        }
                        
                        // Bitcoin Address section
                        addressSection
                        
                        /*
                        // Label section (if present in BIP-21 URI)
                        if let label = parsedURI.label, !label.isEmpty {
                            labelSection(label: label)
                        }
                        */
                        
                        // Amount section (if present in BIP-21 URI)
                        if let amount = parsedURI.amount {
                            amountSection(amount: amount)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    // Pay button
                    Button {
                        onPay(receivedInfo.bip21URI)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.Arke.gold3)
                            Text("Pay")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(Color.Arke.gold3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(Color.Arke.gold)
                    
                    // Add to Contacts button (only if not already in contacts)
                    if existingContact == nil {
                        Button {
                            onAddToContacts(parsedURI.address, parsedURI.label ?? "", receivedInfo.avatarData)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.Arke.gold3)
                                Text("Add to Contacts")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle(Color.Arke.gold3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .tint(Color.Arke.gold)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(uiColor: .systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.Arke.gold)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private func contactInfoSection(contact: PersistentContact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contact")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            HStack(spacing: 12) {
                // Avatar
                if let avatarData = contact.avatarData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Text(String(contact.cachedName.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.cachedName)
                        .font(.headline)
                    
                    if let notes = contact.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .padding(12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func arkAddressSection(arkAddress: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ark Address")
                .font(.body)
                .foregroundStyle(.secondary)
            
            ExpandableAddressView(address: arkAddress, isExpanded: .constant(false), animated: false)
        }
    }
    
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bitcoin Address")
                .font(.body)
                .foregroundStyle(.secondary)
            
            ExpandableAddressView(address: parsedURI.address, isExpanded: .constant(false), animated: false)
        }
    }
    
    private func labelSection(label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Label")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Text(label)
                .font(.title3)
        }
    }
    
    private func amountSection(amount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Text(BitcoinFormatter.shared.formatAccountingAmount(amount, transactionType: .sent))
                .font(.title3)
        }
    }
}

// MARK: - Helper for BIP-21 URI Parsing

struct ParsedBIP21URI {
    let address: String
    let arkAddress: String?
    let label: String?
    let amount: Int?
    let message: String?
}

extension BIP21URIHelper {
    static func parseBIP21URI(_ uri: String) -> ParsedBIP21URI {
        // Strip the bitcoin: scheme if present
        let cleanedURI = uri.replacingOccurrences(of: "bitcoin:", with: "")
        
        // Split address from parameters
        let components = cleanedURI.components(separatedBy: "?")
        let address = components.first ?? uri
        
        var arkAddress: String?
        var label: String?
        var amount: Int?
        var message: String?
        
        // Parse query parameters if present
        if components.count > 1, let queryString = components.last {
            let params = queryString.components(separatedBy: "&")
            for param in params {
                let keyValue = param.components(separatedBy: "=")
                guard keyValue.count == 2 else { continue }
                
                let key = keyValue[0]
                let value = keyValue[1].removingPercentEncoding ?? keyValue[1]
                
                switch key {
                case "ark":
                    arkAddress = value
                case "label":
                    label = value
                case "amount":
                    // BIP-21 amount is in BTC, convert to sats
                    if let btcAmount = Double(value) {
                        amount = Int(btcAmount * 100_000_000)
                    }
                case "message":
                    message = value
                default:
                    break
                }
            }
        }
        
        return ParsedBIP21URI(address: address, arkAddress: arkAddress, label: label, amount: amount, message: message)
    }
}

// MARK: - Preview

#Preview {
    PaymentInfoReceivedSheet(
        receivedInfo: ReceivedPaymentInfo(
            bip21URI: "bitcoin:tb1prnskpsl46vmp6twzw34gfg79w2el8fs7j9s7fm3fqkyf7casglaqlmatu6?ark=tark1pem36wcfzqqpuah6pxtgr7qwcrywd8xtcjxx6djtaht7907juc8pvs0jqqdx0rc3zqyp204tn8cf6cxg7m6k73vjj6d85350r8wfhdlmza8qce5ye4hd9kxg4zwtph&label=Christoph",
            avatarData: nil
        ),
        onPay: { _ in },
        onAddToContacts: { _, _, _ in },
        onDismiss: { }
    )
}
