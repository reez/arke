//
//  SendView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import AppKit

struct ModalState: Identifiable {
    let id = UUID()
    let state: SendModalState
}

struct SendView: View {
    // MARK: - Initialization Parameters
    let prefilledRecipient: String?
    let prefilledContact: ContactModel?
    
    @Environment(WalletManager.self) private var manager
    @Environment(\.dismiss) var dismiss
    
    @State private var recipient = ""
    @State private var amount = ""
    @State private var error: String?
    @State private var sendModalState: SendModalState?
    @State private var clipboardAddress: ParsedAddress?
    @State private var showContactBanner = true
    
    // MARK: - Initializers
    init(prefilledRecipient: String? = nil, prefilledContact: ContactModel? = nil) {
        self.prefilledRecipient = prefilledRecipient
        self.prefilledContact = prefilledContact
    }
    
    // MARK: - Computed Properties for Balance Display
    
    /// Checks if the current recipient is a Lightning invoice with an embedded amount
    private var isLightningInvoiceWithAmount: Bool {
        guard AddressValidator.isLightningInvoice(recipient) else { return false }
        let parsedAddress = AddressValidator.parseAddress(recipient)
        return parsedAddress?.amount != nil
    }
    
    /// Returns the maximum spendable amount based on the recipient address type
    private var maxSpendableAmount: Int {
        if recipient.isEmpty {
            return manager.totalBalance?.totalSpendableSat ?? 0
        } else if AddressValidator.isBitcoinAddress(recipient) {
            return manager.onchainBalance?.trustedSpendableSat ?? 0
        } else {
            return manager.arkBalance?.spendableSat ?? 0
        }
    }
    
    /// Returns the appropriate balance text based on the recipient address type
    private var availableBalanceText: String {
        if recipient.isEmpty {
            let formattedBalance = BitcoinFormatter.formatAmount(manager.totalBalance?.totalSpendableSat ?? 0)
            return "Available: \(formattedBalance) (Total balance)"
        } else if AddressValidator.isBitcoinAddress(recipient) {
            let balance = manager.onchainBalance?.trustedSpendableSat ?? 0
            let formattedBalance = BitcoinFormatter.formatAmount(balance)
            return "Available: \(formattedBalance) (Savings balance)"
        } else {
            let balance = manager.arkBalance?.spendableSat ?? 0
            let formattedBalance = BitcoinFormatter.formatAmount(balance)
            return "Available: \(formattedBalance) (Spending balance)"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Contact info banner (when sending to a known contact)
                if let contact = prefilledContact, showContactBanner {
                    ContactInfoBanner(contact: contact, onClear: {
                        showContactBanner = false
                        recipient = ""
                    })
                }
                
                // Clipboard prompt banner
                if let parsedAddress = clipboardAddress {
                    ClipboardAddressBanner(
                        parsedAddress: parsedAddress,
                        onUseAddress: {
                            recipient = parsedAddress.address
                            // Pre-fill amount if it's a BIP-21 URI or Lightning invoice with amount
                            if let addressAmount = parsedAddress.amount {
                                amount = "\(addressAmount)"
                            }
                            clipboardAddress = nil
                        },
                        onDismiss: {
                            clipboardAddress = nil
                        }
                    )
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient")
                        .font(.title2)
                    
                    TextField("ark1q..., bc1q..., user@domain.com, or ₿user.domain.com", text: $recipient)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        .font(.system(.title2, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: recipient) { _, newValue in
                            handleRecipientChange(newValue)
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Amount in satoshis (at least 330)")
                            .font(.title2)
                        
                        if isLightningInvoiceWithAmount {
                            Text("(amount set by invoice)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        TextField("0", text: $amount)
                            .textFieldStyle(.plain)
                            .font(.title2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(isLightningInvoiceWithAmount ? 0.05 : 0.1))
                            .cornerRadius(16)
                            .disabled(isLightningInvoiceWithAmount)
                        Text("₿")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        if !isLightningInvoiceWithAmount {
                            Button(availableBalanceText) {
                                amount = "\(maxSpendableAmount)"
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                            .disabled(maxSpendableAmount == 0)
                        } else {
                            Text("Amount is fixed by the Lightning invoice")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                if let error = error {
                    ErrorView(
                        errorMessage: error,
                        onRetry: {
                            sendPayment()
                        },
                        onDismiss: {
                            self.error = nil
                        }
                    )
                }
                
                Button("Send") {
                    sendPayment()
                }
                .buttonStyle(ArkeButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(sendModalState != nil || recipient.isEmpty || (amount.isEmpty && !isLightningInvoiceWithAmount))
                .padding(.top, 16)
                
                Text("Fee calculation is not implemented yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .frame(maxWidth: 600)
            .padding()
        }
        .navigationTitle("Send bitcoin")
        .onAppear {
            // Prefill recipient if provided
            if let prefilledRecipient = prefilledRecipient {
                recipient = prefilledRecipient
                // Handle amount pre-filling for pre-filled recipients
                handleRecipientChange(prefilledRecipient)
            } else {
                checkClipboardForAddress()
            }
        }

        .sheet(item: Binding(
            get: { sendModalState.map { ModalState(state: $0) } },
            set: { _ in sendModalState = nil }
        )) { modalState in
            SendModalView(state: modalState.state)
        }
    }
    
    func sendPayment() {
        // For Lightning invoices with embedded amounts, we don't need to validate the amount field
        if isLightningInvoiceWithAmount {
            // Amount is already set by the invoice, proceed directly
            sendModalState = .sending
            error = nil
            
            Task {
                do {
                    // Pay the Lightning invoice without passing an amount
                    _ = try await manager.payLightningInvoice(invoice: recipient, amount: nil)
                    sendModalState = .success
                    // Dismiss after a brief delay to show success state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                } catch {
                    sendModalState = .error(error.localizedDescription)
                    self.error = error.localizedDescription
                }
            }
            return
        }
        
        // For all other cases, validate the amount field
        guard let amountInt = Int(amount) else {
            error = "Invalid amount"
            return
        }
        
        // Validate against the appropriate balance
        if amountInt > maxSpendableAmount {
            if AddressValidator.isBitcoinAddress(recipient) {
                error = "Amount exceeds onchain balance (\(maxSpendableAmount.formatted()) sats)"
            } else {
                error = "Amount exceeds ark balance (\(maxSpendableAmount.formatted()) sats)"
            }
            return
        }
        
        sendModalState = .sending
        error = nil
        
        Task {
            do {
                if AddressValidator.isBitcoinAddress(recipient) {
                    _ = try await manager.sendOnchain(to: recipient, amount: amountInt)
                } else if AddressValidator.isLightningInvoice(recipient) {
                    // Check if the invoice already has an embedded amount
                    let parsedAddress = AddressValidator.parseAddress(recipient)
                    let invoiceHasAmount = parsedAddress?.amount != nil
                    
                    if invoiceHasAmount {
                        // Don't pass amount if invoice already has one
                        _ = try await manager.payLightningInvoice(invoice: recipient, amount: nil)
                    } else {
                        // Pass the amount for invoices without embedded amounts
                        _ = try await manager.payLightningInvoice(invoice: recipient, amount: amountInt)
                    }
                } else {
                    _ = try await manager.send(to: recipient, amount: amountInt)
                }
                sendModalState = .success
                // Dismiss after a brief delay to show success state
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch {
                sendModalState = .error(error.localizedDescription)
                self.error = error.localizedDescription
            }
        }
    }
    
    /// Handles recipient field changes to pre-fill amount for Lightning invoices
    private func handleRecipientChange(_ newRecipient: String) {
        // Only process if we have a non-empty recipient
        guard !newRecipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Parse the address to see if it's a Lightning invoice with an amount
        if let parsedAddress = AddressValidator.parseAddress(newRecipient) {
            // Debug log all parsed address details
            print("🔍 [SendView] Parsed address details:")
            print("   Format: \(parsedAddress.format.rawValue) (\(parsedAddress.format.displayName))")
            print("   Network: \(parsedAddress.network?.displayName ?? "N/A")")
            print("   Original string: \(parsedAddress.originalString)")
            print("   Address: \(parsedAddress.address)")
            print("   Amount: \(parsedAddress.amount?.description ?? "N/A") sats")
            print("   Label: \(parsedAddress.label ?? "N/A")")
            print("   Message: \(parsedAddress.message ?? "N/A")")
            print("   Scan public key: \(parsedAddress.scanPublicKey?.base64EncodedString() ?? "N/A")")
            print("   Spend public key: \(parsedAddress.spendPublicKey?.base64EncodedString() ?? "N/A")")
            print("   Display name: \(parsedAddress.displayName)")
            print("   Is Bitcoin: \(parsedAddress.isBitcoin)")
            
            // Pre-fill amount for Lightning invoices
            if parsedAddress.format == .lightningInvoice,
               let invoiceAmount = parsedAddress.amount {
                print("   → Pre-filling amount: \(invoiceAmount) sats")
                amount = "\(invoiceAmount)"
            }
        } else {
            print("🔍 [SendView] Could not parse recipient address: \(newRecipient)")
        }
    }
    
    /// Checks clipboard for valid Bitcoin, Ark, Lightning, BIP-353, or BIP-21 addresses
    private func checkClipboardForAddress() {
        // Only check if recipient field is empty
        guard recipient.isEmpty else { return }
        
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { 
            print("🔍 [SendView] No clipboard content found")
            return 
        }
        
        let trimmedString = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 [SendView] Checking clipboard content: \(trimmedString)")
        
        // Check if clipboard contains a valid address
        if let parsedAddress = AddressValidator.parseAddress(trimmedString) {
            // Debug log all parsed address details from clipboard
            print("🔍 [SendView] Found valid address in clipboard:")
            print("   Format: \(parsedAddress.format.rawValue) (\(parsedAddress.format.displayName))")
            print("   Network: \(parsedAddress.network?.displayName ?? "N/A")")
            print("   Original string: \(parsedAddress.originalString)")
            print("   Address: \(parsedAddress.address)")
            print("   Amount: \(parsedAddress.amount?.description ?? "N/A") sats")
            print("   Label: \(parsedAddress.label ?? "N/A")")
            print("   Message: \(parsedAddress.message ?? "N/A")")
            print("   Scan public key: \(parsedAddress.scanPublicKey?.base64EncodedString() ?? "N/A")")
            print("   Spend public key: \(parsedAddress.spendPublicKey?.base64EncodedString() ?? "N/A")")
            print("   Display name: \(parsedAddress.displayName)")
            print("   Is Bitcoin: \(parsedAddress.isBitcoin)")
            
            clipboardAddress = parsedAddress
        } else {
            print("🔍 [SendView] Clipboard content is not a valid address: \(trimmedString)")
        }
    }
}

#Preview {
    NavigationStack {
        SendView(
            prefilledRecipient: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            prefilledContact: ContactModel(cachedName: "John Doe")
        )
            .environment(WalletManager())
    }
}
