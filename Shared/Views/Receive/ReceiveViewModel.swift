//
//  ReceiveViewModel.swift
//  Ark wallet prototype
//
//  Created by Assistant on 12/3/25.
//

import SwiftUI

/// Shared view model for receive functionality across macOS and iOS
@Observable
@MainActor
final class ReceiveViewModel {
    
    // MARK: - Dependencies
    
    private let walletManager: WalletManager
    
    // MARK: - State
    
    var selectedBalance: ReceiveBalanceType = .paymentsAndSavings
    var showingQRCode = false
    var showingAmountAndNote = false
    var amount = ""
    var note = ""
    
    // Lightning-specific state
    var lightningInvoice: String?
    var isGeneratingInvoice = false
    var invoiceError: String?
    var showCopySuccess = false
    
    // MARK: - Initialization
    
    init(walletManager: WalletManager) {
        self.walletManager = walletManager
    }
    
    // MARK: - Computed Properties
    
    var balanceTypeLabel: String {
        switch selectedBalance {
        case .payments: return "Payments"
        case .savings: return "Savings"
        case .lightning: return "Lightning"
        case .paymentsAndSavings: return "Payments and Savings"
        }
    }
    
    var hasQRContent: Bool {
        getCurrentQRContent() != nil
    }
    
    // MARK: - Public Methods
    
    /// Changes the selected balance type and clears state as needed
    func changeBalanceType(to newType: ReceiveBalanceType) {
        let oldType = selectedBalance
        selectedBalance = newType
        
        // Clear Lightning state when switching balance types
        clearLightningInvoice()
        
        // Clear amount and note when switching to/from Lightning
        // since Lightning has different requirements
        if (oldType == .lightning) != (newType == .lightning) {
            amount = ""
            note = ""
            showingAmountAndNote = false
        }
    }
    
    /// Generates a Lightning invoice for the current amount
    func generateLightningInvoice() async {
        let trimmedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAmount.isEmpty, let amountInt = Int(trimmedAmount), amountInt > 0 else {
            invoiceError = "Please enter a valid amount greater than 0"
            return
        }
        
        // Add reasonable limits for Lightning invoices
        guard amountInt <= 10_000_000 else { // 0.1 BTC limit
            invoiceError = "Amount too large. Maximum is 10,000,000 sats"
            return
        }
        
        isGeneratingInvoice = true
        invoiceError = nil
        
        do {
            let invoice = try await walletManager.getLightningInvoice(amount: amountInt)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.lightningInvoice = invoice
            }
            self.isGeneratingInvoice = false
        } catch {
            self.invoiceError = "Failed to generate invoice: \(error.localizedDescription)"
            self.isGeneratingInvoice = false
        }
    }
    
    /// Clears the Lightning invoice and related state
    func clearLightningInvoice() {
        lightningInvoice = nil
        invoiceError = nil
        showCopySuccess = false
    }
    
    /// Copies text to clipboard and shows success feedback
    func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
        
        // Show success feedback
        withAnimation {
            showCopySuccess = true
        }
        
        // Hide success feedback after 2 seconds
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation {
                    showCopySuccess = false
                }
            }
        }
    }
    
    /// Extracts the invoice string from JSON or returns the input if it's plain text
    func extractInvoiceFromJSON(_ input: String) -> String {
        // First, try to parse as JSON
        if let data = input.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let invoice = json["invoice"] as? String {
                    return invoice
                }
            } catch {
                // If JSON parsing fails, treat as plain string
                print("Failed to parse Lightning invoice as JSON, using as plain string: \(error)")
            }
        }
        
        // If not JSON or parsing failed, return the original string
        return input
    }
    
    /// Gets the current QR code content and title based on selected balance type
    func getCurrentQRContent() -> (content: String, title: String)? {
        // For Lightning, use the generated invoice (extract from JSON if needed)
        if selectedBalance == .lightning {
            guard let rawInvoice = lightningInvoice else { return nil }
            let actualInvoice = extractInvoiceFromJSON(rawInvoice)
            return (content: actualInvoice, title: "Lightning Invoice")
        }
        
        return ReceiveQRContentHelper.getCurrentQRContent(
            selectedBalance: selectedBalance,
            amount: amount,
            note: note,
            arkAddress: walletManager.arkAddress,
            onchainAddress: walletManager.onchainAddress
        )
    }
    
    /// Gets the share content based on selected balance type
    func getShareContent() -> String? {
        // For Lightning, use the generated invoice (extract from JSON if needed)
        if selectedBalance == .lightning {
            guard let rawInvoice = lightningInvoice else { return nil }
            return extractInvoiceFromJSON(rawInvoice)
        }
        
        return ReceiveQRContentHelper.getShareContent(
            selectedBalance: selectedBalance,
            amount: amount,
            note: note,
            arkAddress: walletManager.arkAddress,
            onchainAddress: walletManager.onchainAddress
        )
    }
    
    // MARK: - Sheet Management
    
    func showQRCode() {
        showingQRCode = true
    }
    
    func hideQRCode() {
        showingQRCode = false
    }
    
    func toggleAmountAndNote() {
        showingAmountAndNote.toggle()
    }
}
