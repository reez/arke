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
    @State private var clipboardPaymentRequest: PaymentRequest?
    @State private var showContactBanner = true
    @State private var showAddressFormatsPopover = false
    
    // MARK: - Initializers
    init(prefilledRecipient: String? = nil, prefilledContact: ContactModel? = nil) {
        self.prefilledRecipient = prefilledRecipient
        self.prefilledContact = prefilledContact
    }
    
    // MARK: - Computed Properties
    
    /// Returns the current network configuration based on arkInfo
    private var currentNetworkConfig: NetworkConfig? {
        // Try to get the network from arkInfo
        guard let arkInfo = manager.arkInfo,
              let bitcoinNetwork = arkInfo.bitcoinNetwork else {
            // Fallback to networkConfig if available
            return manager.networkConfig
        }
        
        // Map BitcoinNetwork to NetworkConfig
        switch bitcoinNetwork {
        case .mainnet:
            return .mainnet
        case .testnet:
            return .testnet
        case .signet:
            return .signet
        case .regtest:
            // No predefined regtest config, use signet as fallback
            return .signet
        }
    }
    
    // MARK: - Computed Properties for Balance Display
    
    /// Checks if the current recipient is a Lightning invoice with an embedded amount
    private var isLightningInvoiceWithAmount: Bool {
        guard AddressValidator.isLightningInvoice(recipient) else { return false }
        let paymentRequest = AddressValidator.parsePaymentRequest(recipient)
        return paymentRequest?.amount != nil
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
            let formattedBalance = BitcoinFormatter.shared.formatAmount(manager.totalBalance?.totalSpendableSat ?? 0)
            return "Available: \(formattedBalance) (Total balance)"
        } else if AddressValidator.isBitcoinAddress(recipient) {
            let balance = manager.onchainBalance?.trustedSpendableSat ?? 0
            let formattedBalance = BitcoinFormatter.shared.formatAmount(balance)
            return "Available: \(formattedBalance) (Savings balance)"
        } else {
            let balance = manager.arkBalance?.spendableSat ?? 0
            let formattedBalance = BitcoinFormatter.shared.formatAmount(balance)
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
                if let paymentRequest = clipboardPaymentRequest {
                    ClipboardAddressBanner(
                        paymentRequest: paymentRequest,
                        onUseAddress: {
                            recipient = paymentRequest.primaryAddress ?? ""
                            // Pre-fill amount if it's a payment request with amount
                            if let requestAmount = paymentRequest.amount {
                                amount = "\(requestAmount)"
                            }
                            clipboardPaymentRequest = nil
                        },
                        onDismiss: {
                            clipboardPaymentRequest = nil
                        },
                        currentNetwork: currentNetworkConfig
                    )
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Address")
                            .font(.title2)
                        
                        Button(action: {
                            showAddressFormatsPopover.toggle()
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .help("Show supported address formats")
                        .popover(isPresented: $showAddressFormatsPopover) {
                            AddressFormatsInfoView()
                        }
                    }
                    
                    TextField("Enter address...", text: $recipient)
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
                        Text("Amount in satoshis")
                            .font(.title2)
                        
                        if isLightningInvoiceWithAmount {
                            Text("(amount set by invoice)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    TextField("0", text: $amount)
                        .textFieldStyle(.plain)
                        .font(.title2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(isLightningInvoiceWithAmount ? 0.05 : 0.1))
                        .cornerRadius(16)
                        .disabled(isLightningInvoiceWithAmount)
                    
                    HStack(spacing: 0) {
                        Text(BitcoinFormatter.shared.formatAmount(330) + " minimum · ")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if !isLightningInvoiceWithAmount {
                            Button(availableBalanceText) {
                                amount = "\(maxSpendableAmount)"
                            }
                            .font(.body)
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
            .padding(.top, 20)
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
                    let paymentRequest = AddressValidator.parsePaymentRequest(recipient)
                    let invoiceHasAmount = paymentRequest?.amount != nil
                    
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
        
        // Parse the payment request
        if let paymentRequest = AddressValidator.parsePaymentRequest(newRecipient) {
            // Debug log all payment request details
            print("🔍 [SendView] Parsed payment request details:")
            print("   Destinations: \(paymentRequest.destinations.count)")
            if let primary = paymentRequest.primaryDestination {
                print("   Primary format: \(primary.format.rawValue) (\(primary.format.displayName))")
                print("   Primary network: \(primary.network?.displayName ?? "N/A")")
                print("   Primary address: \(primary.address)")
            }
            print("   Amount: \(paymentRequest.amount?.description ?? "N/A") sats")
            print("   Label: \(paymentRequest.label ?? "N/A")")
            print("   Message: \(paymentRequest.message ?? "N/A")")
            print("   Has alternatives: \(paymentRequest.hasAlternatives)")
            
            if paymentRequest.hasAlternatives {
                print("   Alternative destinations:")
                for (index, dest) in paymentRequest.alternativeDestinations.enumerated() {
                    print("     [\(index + 1)] \(dest.format.displayName): \(dest.shortAddress)")
                }
            }
            
            // Pre-fill amount for payment requests with embedded amounts
            if let requestAmount = paymentRequest.amount {
                print("   → Pre-filling amount: \(requestAmount) sats")
                amount = "\(requestAmount)"
            }
        } else {
            print("🔍 [SendView] Could not parse recipient as payment request: \(newRecipient)")
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
        
        // Check if clipboard contains a valid payment request
        if let paymentRequest = AddressValidator.parsePaymentRequest(trimmedString) {
            // Debug log all payment request details from clipboard
            print("🔍 [SendView] Found valid payment request in clipboard:")
            print("   Destinations: \(paymentRequest.destinations.count)")
            if let primary = paymentRequest.primaryDestination {
                print("   Primary format: \(primary.format.rawValue) (\(primary.format.displayName))")
                print("   Primary network: \(primary.network?.displayName ?? "N/A")")
                print("   Primary address: \(primary.address)")
            }
            print("   Amount: \(paymentRequest.amount?.description ?? "N/A") sats")
            print("   Label: \(paymentRequest.label ?? "N/A")")
            print("   Message: \(paymentRequest.message ?? "N/A")")
            print("   Has alternatives: \(paymentRequest.hasAlternatives)")
            
            if paymentRequest.hasAlternatives {
                print("   Alternative destinations:")
                for (index, dest) in paymentRequest.alternativeDestinations.enumerated() {
                    print("     [\(index + 1)] \(dest.format.displayName): \(dest.shortAddress)")
                }
            }
            
            clipboardPaymentRequest = paymentRequest
        } else {
            print("🔍 [SendView] Clipboard content is not a valid payment request: \(trimmedString)")
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
