//
//  ReceiveView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import AppKit

struct ReceiveView: View {
    @Environment(WalletManager.self) private var manager
    @State private var selectedBalance: BalanceType = .paymentsAndSavings
    @State private var showingQRCode = false
    @State private var showingAmountAndNote = false
    @State private var amount = ""
    @State private var note = ""
    
    // Lightning-specific state
    @State private var lightningInvoice: String?
    @State private var isGeneratingInvoice = false
    @State private var invoiceError: String?
    @State private var showCopySuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                headerSection
                VStack(spacing: 0) {
                    addressContentSection
                    Divider()
                        .padding(.leading, 25)
                        .padding(.trailing, 25)
                    amountAndNoteSection
                }
                .background(.ultraThinMaterial)
                .cornerRadius(25)
                .frame(maxWidth: 400)
                actionButtonsSection
            }
            .padding(.top, 30)
        }
        .navigationTitle("Receive bitcoin")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                balanceTypeMenu
            }
        }
        .sheet(isPresented: $showingQRCode) {
            qrCodeSheet
        }
        .onChange(of: selectedBalance) { oldValue, newValue in
            // Clear Lightning state when switching balance types
            clearLightningInvoice()
            
            // Clear amount and note when switching to/from Lightning
            // since Lightning has different requirements
            if (oldValue == .lightning) != (newValue == .lightning) {
                amount = ""
                note = ""
                showingAmountAndNote = false
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Share your payment info")
                .font(.system(size: 24, design: .serif))
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var balanceTypeMenu: some View {
        Menu {
            ForEach(BalanceType.allCases, id: \.self) { balanceType in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedBalance = balanceType
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(balanceType.rawValue)
                                .font(.body)
                            if selectedBalance == balanceType {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .foregroundStyle(.blue)
                            }
                        }
                        Text(balanceType.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(balanceTypeLabel)
                    .font(.body)
                    .padding(.horizontal, 14)
            }
            .background(Color.clear)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .help("Switch balance type")
    }
    
    private var balanceTypeLabel: String {
        switch selectedBalance {
        case .payments: return "Payments"
        case .savings: return "Savings"
        case .lightning: return "Lightning"
        case .paymentsAndSavings: return "Payments and Savings"
        }
    }
    
    @ViewBuilder
    private var addressContentSection: some View {
        if selectedBalance != .lightning {
            AddressDisplayView(
                selectedBalance: selectedBalance,
                amount: amount,
                note: note
            )
        } else {
            if lightningInvoice == nil {
                VStack(spacing: 8) {
                    Text("Lightning Invoice")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                    Text("Enter an amount to generate a Lightning invoice")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 30)
            }
        }
    }
    
    @ViewBuilder
    private var amountAndNoteSection: some View {
        if selectedBalance == .lightning {
            lightningAmountInputSection
        } else {
            AmountAndNoteInputView(
                amount: $amount,
                note: $note,
                showingAmountAndNote: $showingAmountAndNote
            )
        }
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        if selectedBalance == .lightning {
            lightningActionSection
        } else {
            ActionButtonsView(
                selectedBalance: selectedBalance,
                shareContent: getShareContent(),
                hasQRContent: getCurrentQRContent() != nil,
                onShowQRCode: { showingQRCode = true }
            )
        }
    }
    
    @ViewBuilder
    private var qrCodeSheet: some View {
        if let qrContent = getCurrentQRContent() {
            QRCodeView(
                content: qrContent.content,
                title: qrContent.title,
                onClose: { showingQRCode = false }
            )
            .frame(minWidth: 300, minHeight: 300)
        }
    }
    
    // MARK: - Lightning-specific UI Components
    
    @ViewBuilder
    private var lightningAmountInputSection: some View {
        VStack(spacing: 12) {
            if lightningInvoice == nil {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        TextField("Enter amount (required)", text: $amount)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.plain)
                            .padding(.leading, 25)
                            .padding(.vertical, 12)
                            .onChange(of: amount) { _, _ in
                                // Clear previous invoice when amount changes
                                clearLightningInvoice()
                            }
                        Spacer()
                        Text("₿")
                            .font(.system(.body, design: .monospaced))
                            .padding(.trailing, 25)
                    }
                    
                    if !note.isEmpty || lightningInvoice == nil {
                        Divider()
                            .padding(.horizontal, 25)
                        
                        HStack(spacing: 8) {
                            TextField("Add note (optional)", text: $note)
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 25)
                                .padding(.vertical, 12)
                                .onChange(of: note) { _, _ in
                                    // Clear previous invoice when note changes
                                    clearLightningInvoice()
                                }
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            
            // Show generated invoice if available
            if let invoice = lightningInvoice {
                lightningInvoiceDisplay(invoice)
                    .transition(.opacity.combined(with: .slide))
            }
            
            // Show error if any
            if let error = invoiceError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var lightningActionSection: some View {
        VStack(spacing: 12) {
            if lightningInvoice == nil {
                // Create Invoice button
                Button {
                    Task {
                        await generateLightningInvoice()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isGeneratingInvoice {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text(isGeneratingInvoice ? "Creating Invoice..." : "Create Invoice")
                    }
                }
                .buttonStyle(ArkeButtonStyle(size: .medium))
                .controlSize(.large)
                .disabled(amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGeneratingInvoice)
            } else {
                // Share and QR buttons for generated invoice
                HStack(spacing: 12) {
                    Button {
                        if let rawInvoice = lightningInvoice {
                            let actualInvoice = extractInvoiceFromJSON(rawInvoice)
                            shareAction(content: actualInvoice)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                    }
                    .buttonStyle(ArkeButtonStyle(size: .medium))
                    .controlSize(.large)
                    
                    Button {
                        showingQRCode = true
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
    
    @ViewBuilder
    private func lightningInvoiceDisplay(_ invoice: String) -> some View {
        let actualInvoice = extractInvoiceFromJSON(invoice)
        
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Lightning Invoice Generated")
                    .font(.title2)
                    .multilineTextAlignment(.center)
            }
            
            Text(actualInvoice)
                .font(.system(.caption, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .cornerRadius(6)
                .onTapGesture {
                    copyToClipboard(actualInvoice)
                }
            
            Text(showCopySuccess ? "Copied!" : "Tap to copy")
                .font(.caption2)
                .foregroundColor(showCopySuccess ? .green : .secondary)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 20)
    }
    
    // MARK: - Helper Methods
    
    private func extractInvoiceFromJSON(_ input: String) -> String {
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
    
    private func getCurrentQRContent() -> (content: String, title: String)? {
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
            arkAddress: manager.arkAddress,
            onchainAddress: manager.onchainAddress
        )
    }
    
    private func getShareContent() -> String? {
        // For Lightning, use the generated invoice (extract from JSON if needed)
        if selectedBalance == .lightning {
            guard let rawInvoice = lightningInvoice else { return nil }
            return extractInvoiceFromJSON(rawInvoice)
        }
        
        return ReceiveQRContentHelper.getShareContent(
            selectedBalance: selectedBalance,
            amount: amount,
            note: note,
            arkAddress: manager.arkAddress,
            onchainAddress: manager.onchainAddress
        )
    }
    
    // MARK: - Lightning Helper Methods
    
    private func generateLightningInvoice() async {
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
            let invoice = try await manager.getLightningInvoice(amount: amountInt)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.lightningInvoice = invoice
                }
                self.isGeneratingInvoice = false
            }
        } catch {
            await MainActor.run {
                self.invoiceError = "Failed to generate invoice: \(error.localizedDescription)"
                self.isGeneratingInvoice = false
            }
        }
    }
    
    private func clearLightningInvoice() {
        lightningInvoice = nil
        invoiceError = nil
        showCopySuccess = false
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
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
    
    private func shareAction(content: String) {
        let sharingPicker = NSSharingServicePicker(items: [content])
        if let window = NSApp.keyWindow {
            sharingPicker.show(relativeTo: .zero, of: window.contentView ?? NSView(), preferredEdge: .maxY)
        }
    }
}

#Preview("Loading State") {
    ReceiveView()
        .environment(WalletManager(useMock: true))
        .frame(width: 600, height: 600)
}

#Preview("Loaded State") {
    @Previewable @State var mockManager = WalletManager(useMock: true)
    
    ReceiveView()
        .environment(mockManager)
        .frame(width: 600, height: 600)
        .task {
            // Initialize the mock manager to load mock addresses
            await mockManager.initialize()
        }
}
