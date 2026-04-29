//
//  SendView_iOS.swift
//  Arké
//
//  Created by Assistant on 12/8/25.
//
//  Architecture:
//  - Three distinct modes: Manual, Contact, and Quick
//  - Single SendState object that all child views can modify
//  - Mode selection happens once on initialization based on context
//  - Quick mode can transition to Manual (confirmed) when user accepts a bare address
//  - All modes can reset back to Manual (entering) via clearAll()
//

import SwiftUI
import ArkeUI

struct SendOperation_iOS: Identifiable {
    let id = UUID()
    let performSend: () async throws -> Void
}

enum SendInputMethod_iOS {
    case camera
    case input
}

/// iOS implementation of the Send view
struct SendView_iOS: View {
    // MARK: - Initialization Parameters
    let prefilledRecipient: String?
    let prefilledContact: ContactModel?
    let onNavigateToContact: ((ContactModel) -> Void)?
    let onNavigateToActivity: ((ContactModel?) -> Void)?
    let doubleTapTrigger: Int
    
    @Environment(WalletManager.self) private var manager
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State
    @State private var viewModel: SendViewModel?
    @State private var inputMethod: SendInputMethod_iOS = .camera
    @State private var showContactPicker: Bool = false
    @State private var sendOperation: SendOperation_iOS?
    
    // MARK: - Initializers
    init(prefilledRecipient: String? = nil, prefilledContact: ContactModel? = nil, onNavigateToContact: ((ContactModel) -> Void)? = nil, onNavigateToActivity: ((ContactModel?) -> Void)? = nil, doubleTapTrigger: Int = 0) {
        self.prefilledRecipient = prefilledRecipient
        self.prefilledContact = prefilledContact
        self.onNavigateToContact = onNavigateToContact
        self.onNavigateToActivity = onNavigateToActivity
        self.doubleTapTrigger = doubleTapTrigger
    }
    
    var body: some View {
        Group {
            if let viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .task {
                        viewModel = SendViewModel(
                            walletManager: manager,
                            clipboardService: ClipboardService_iOS()
                        )
                        viewModel?.onDismiss = { [weak viewModel] in
                            print("🧹 [SendView_iOS] Clearing form after successful send")
                            viewModel?.clearAll()
                            inputMethod = .camera
                        }
                        await viewModel?.handleInitialSetup(
                            prefilledRecipient: prefilledRecipient,
                            prefilledContact: prefilledContact
                        )
                        print("✅ [SendView_iOS] Initial setup completed")
                        
                        // If we have prefilled data, switch to input mode (similar to QR scanning)
                        if prefilledRecipient != nil || prefilledContact != nil {
                            print("🔄 [SendView_iOS] Switching to input mode (prefilled data)")
                            inputMethod = .input
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private func contentView(viewModel: SendViewModel) -> some View {
        @Bindable var viewModel = viewModel
        
        mainContentStack(viewModel: viewModel)
            .sheet(item: $sendOperation) { operation in
                sendModalSheet(operation: operation)
            }
            .sheet(isPresented: $viewModel.showDestinationPicker) {
                destinationPickerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showContactPicker) {
                contactPickerSheet()
            }
            .onAppear {
                handleViewAppearance(viewModel: viewModel)
                print("👁️ [SendView_iOS] View appeared - inputMethod: \(inputMethod)")
            }
            .onChange(of: doubleTapTrigger) {
                print("🔔 [SendView_iOS] doubleTapTrigger changed to: \(doubleTapTrigger)")
                handleDoubleTap()
            }
            .onChange(of: inputMethod) {
                print("🔄 [SendView_iOS] inputMethod changed to: \(inputMethod)")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Check clipboard availability when app becomes active
                // This doesn't trigger permission dialogs, just updates button visibility
                viewModel.checkClipboardAvailability()
            }
    }
    
    @ViewBuilder
    private func mainContentStack(viewModel: SendViewModel) -> some View {
        @Bindable var viewModel = viewModel
        
        ZStack {
            slidingContentView(viewModel: viewModel)
            
            // Floating controls overlay
            VStack {
                // Input method picker (centered)
                inputMethodPicker()
                    .padding(.top, 16)
                
                Spacer()
                
                // Contact picker button positioned above tab bar on the left
                HStack {
                    contactCollageButton()
                        .padding(.leading, 30)
                        .padding(.bottom, 20) // Space above tab bar
                        .opacity(inputMethod == .camera ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: inputMethod)
                    
                    Spacer()
                    
                    // Paste button positioned above tab bar on the right
                    if viewModel.hasClipboardContent {
                        pasteButton()
                            .padding(.trailing, 30)
                            .padding(.bottom, 20) // Space above tab bar
                            .opacity(inputMethod == .camera ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: inputMethod)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func inputMethodPicker() -> some View {
        SendInputMethodPicker_iOS(inputMethod: $inputMethod)
    }
    
    @ViewBuilder
    private func pasteButton() -> some View {
        PasteButton_iOS {
            handlePasteFromClipboard()
        }
    }
    
    @ViewBuilder
    private func contactCollageButton() -> some View {
        // Get contacts with addresses from the service
        let contactsWithAddresses = ServiceContainer.shared.contactService.contacts.filter { $0.hasAddresses }
        
        ContactCollageButton_iOS(contacts: contactsWithAddresses) {
            showContactPicker = true
        }
    }
    
    @ViewBuilder
    private func slidingContentView(viewModel: SendViewModel) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                cameraView(viewModel: viewModel, width: geometry.size.width)
                inputFormView(viewModel: viewModel, width: geometry.size.width)
            }
            .frame(height: geometry.size.height)
            .offset(x: inputMethod == .camera ? 0 : -geometry.size.width)
            .animation(.easeInOut(duration: 0.3), value: inputMethod)
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func cameraView(viewModel: SendViewModel, width: CGFloat) -> some View {
        QRScannerView_iOS { scannedCode in
            print("📸 [SendView_iOS] QR Code Scanned: '\(scannedCode)'")
            
            // Handle scanned QR code
            Task { @MainActor in
                print("📸 [SendView_iOS] Parsing scanned code...")
                
                // Parse the scanned code into a payment request
                if let paymentRequest = AddressValidator.parsePaymentRequest(scannedCode) {
                    print("✅ [SendView_iOS] Valid payment request parsed: \(paymentRequest)")
                    print("   └─ Amount: \(paymentRequest.amount?.description ?? "none")")
                    print("   └─ Label: \(paymentRequest.label ?? "none")")
                    print("   └─ Message: \(paymentRequest.message ?? "none")")
                    print("   └─ Destinations: \(paymentRequest.destinations.count)")
                    
                    // Determine which mode to use based on payment request complexity
                    if viewModel.isSimplePaymentRequest(paymentRequest) {
                        // Simple bare address - use manual mode for traditional flow
                        print("   └─ Using manual mode (simple address)")
                        viewModel.lockInPaymentRequest(paymentRequest)
                    } else {
                        // Rich payment request with metadata - use quick mode for better UX
                        print("   └─ Using quick mode (rich payment request)")
                        await viewModel.enterQuickMode(paymentRequest: paymentRequest, source: .qrCode)
                    }
                    
                    print("✅ [SendView_iOS] Payment request configured")
                    print("   └─ Current sendMode: \(viewModel.sendMode.description)")
                } else {
                    print("❌ [SendView_iOS] Invalid payment request - showing error")
                    
                    // Invalid QR code - show in manual input with error
                    viewModel.manualInput = scannedCode
                    viewModel.error = "Invalid payment address or QR code"
                }
                
                print("🔄 [SendView_iOS] Switching to input mode...")
                // Switch back to input mode to review the populated data
                inputMethod = .input
                print("✅ [SendView_iOS] Switched to input mode")
                print("   └─ Final sendMode: \(viewModel.sendMode.description)")
            }
        }
        .frame(width: width)
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func inputFormView(viewModel: SendViewModel, width: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Add top padding to account for the floating picker
                Spacer()
                    .frame(height: 80) // Matches picker height
                
                // Three distinct modes
                modeSpecificContent(viewModel: viewModel)
                
                // Error display
                if let error = viewModel.error {
                    errorView(viewModel: viewModel, error: error)
                }
                
                Spacer()
            }
            .frame(maxWidth: 600)
            .padding(.top, 20)
            .padding()
        }
        .frame(width: width)
        .scrollDismissesKeyboard(.interactively)
    }
    
    @ViewBuilder
    private func sendModalSheet(operation: SendOperation_iOS) -> some View {
        NavigationStack {
            SendModalView(
                onDismissEntireView: {
                    print("👋 [SendView_iOS] Dismissing entire SendView")
                    viewModel?.onDismiss?()
                },
                performSend: operation.performSend
            )
        }
        .presentationDetents([.medium, .large])
    }
    
    @ViewBuilder
    private func destinationPickerSheet(viewModel: SendViewModel) -> some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            PaymentDestinationPickerView(rankedDestinations: viewModel.rankedDestinations) { destination in
                viewModel.selectedDestination = destination
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    @ViewBuilder
    private func contactPickerSheet() -> some View {
        ContactsView_iOS(
            onSelectContact: { contact, address in
                handleContactSelection(contact: contact, address: address)
            },
            onNavigateToActivity: { contact in
                // Dismiss the contact picker sheet first
                showContactPicker = false
                // Small delay to ensure sheet dismissal completes before navigation
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    onNavigateToActivity?(contact)
                }
            }
        )
        .environment(manager)
    }
    
    private func handleContactSelection(contact: ContactModel, address: ContactAddressModel) {
        print("👤 [SendView_iOS] Contact selected: \(contact.displayName)")
        print("📍 [SendView_iOS] Address selected: \(address.address)")
        
        // Populate the send form with the contact
        Task {
            print("🔄 [SendView_iOS] Calling handleInitialSetup...")
            await viewModel?.handleInitialSetup(
                prefilledRecipient: address.address,
                prefilledContact: contact
            )
            
            print("✅ [SendView_iOS] handleInitialSetup completed")
            print("   └─ sendMode: \(viewModel?.sendMode.description ?? "nil")")
            print("   └─ selectedDestination: \(viewModel?.selectedDestination?.address ?? "nil")")
            print("   └─ amount: '\(viewModel?.amount ?? "")'")
            
            // Switch to input mode to show the populated form
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    inputMethod = .input
                }
                print("✅ [SendView_iOS] Switched to input mode with contact data")
            }
        }
    }
    
    private func handleViewAppearance(viewModel: SendViewModel) {
        // Check clipboard availability (doesn't trigger permission dialog)
        viewModel.checkClipboardAvailability()
    }
    
    private func handlePasteFromClipboard() {
        print("📋 [SendView_iOS] Paste button tapped")
        
        // Read clipboard content (this may trigger permission dialog on first use)
        Task {
            let success = await viewModel?.checkClipboardForAddress() ?? false
            
            await MainActor.run {
                if success {
                    // Only switch to input mode if clipboard parsing succeeded
                    withAnimation(.easeInOut(duration: 0.3)) {
                        inputMethod = .input
                    }
                    print("✅ [SendView_iOS] Switched to input mode with clipboard data")
                } else {
                    // Show error if clipboard didn't contain valid payment info
                    print("❌ [SendView_iOS] Clipboard paste failed - no valid payment info found")
                    viewModel?.error = "No valid payment address found in clipboard"
                    // Still switch to input mode so user can see the error
                    withAnimation(.easeInOut(duration: 0.3)) {
                        inputMethod = .input
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func modeSpecificContent(viewModel: SendViewModel) -> some View {
        switch viewModel.sendMode {
        case .manual:
            manualModeView(viewModel: viewModel)
            
        case .contact(let contact):
            contactModeView(viewModel: viewModel, contact: contact)
            
        case .quick(let paymentRequest, let source):
            quickModeView(viewModel: viewModel, paymentRequest: paymentRequest, source: source)
        }
    }
    
    // MARK: - Double-Tap Handler
    
    private func handleDoubleTap() {
        print("👆 [SendView_iOS] handleDoubleTap() called")
        print("   └─ Current inputMethod: \(inputMethod)")
        
        // Toggle between camera and input modes
        withAnimation(.easeInOut(duration: 0.3)) {
            let newMethod: SendInputMethod_iOS = inputMethod == .camera ? .input : .camera
            print("   └─ Toggling to: \(newMethod)")
            inputMethod = newMethod
        }
        
        print("   └─ New inputMethod: \(inputMethod)")
    }
    
    @ViewBuilder
    private func manualModeView(viewModel: SendViewModel) -> some View {
        @Bindable var viewModel = viewModel
        
        ManualSendView(
            manualInput: $viewModel.manualInput,
            recipientState: $viewModel.recipientState,
            amount: $viewModel.amount,
            showAddressFormatsPopover: $viewModel.showAddressFormatsPopover,
            selectedDestination: $viewModel.selectedDestination,
            showFeeSelectionSheet: $viewModel.showFeeSelectionSheet,
            selectedFeePriority: $viewModel.selectedFeePriority,
            maxSpendableAmount: viewModel.maxSpendableAmount,
            availableBalanceText: viewModel.availableBalanceText,
            availableBalanceName: viewModel.availableBalanceName,
            availableBalanceAmount: viewModel.availableBalanceAmount,
            feeText: viewModel.feeText ?? "",
            feeAmount: viewModel.feeAmount,
            isAmountLocked: viewModel.isAmountLocked,
            lockedAmountReason: viewModel.lockedAmountReason,
            minimumSendAmount: viewModel.minimumSendAmount,
            paymentContext: viewModel.paymentContext,
            contactLookup: { address in
                let normalizedAddress = address.lowercased()
                let contacts = ServiceContainer.shared.contactService.contacts
                return contacts.first { contact in
                    contact.addresses.contains { $0.normalizedAddress == normalizedAddress }
                }
            },
            shouldShowFeeDisclosure: viewModel.shouldShowFeeDisclosure,
            onchainFeeRates: viewModel.onchainFeeRates,
            onSend: {
                sendOperation = SendOperation_iOS {
                    try await viewModel.executeSend()
                }
            },
            onSwitchToQuickMode: { paymentRequest in
                print("🔄 [SendView_iOS] Switching to quick mode from manual input")
                viewModel.sendMode = .quick(paymentRequest, source: .manual)
            }
        )
        .onChange(of: viewModel.selectedDestination) { oldDestination, newDestination in
            // When destination changes in manual mode, rank it for fee calculation
            if case .manual = viewModel.sendMode,
               let destination = newDestination,
               oldDestination?.id != newDestination?.id {
                print("🔄 [SendView_iOS] Manual destination changed, ranking for fees")
                viewModel.rankManualDestination(destination)
            }
        }
        .popover(isPresented: $viewModel.showAddressFormatsPopover) {
            AddressFormatsInfoView()
        }
    }
    
    @ViewBuilder
    private func contactModeView(viewModel: SendViewModel, contact: ContactModel) -> some View {
        @Bindable var viewModel = viewModel
        
        let _ = print("🏗️ [SendView_iOS] Building contactModeView")
        let _ = print("   └─ contact: \(contact.displayName)")
        let _ = print("   └─ prefilledRecipient: \(prefilledRecipient ?? "nil")")
        let _ = print("   └─ viewModel.selectedDestination: \(viewModel.selectedDestination?.address ?? "nil")")
        let _ = print("   └─ viewModel.amount: '\(viewModel.amount)'")
        
        ContactPaymentView(
            contact: contact,
            contactAddress: viewModel.selectedDestination?.address,
            onClear: {
                viewModel.clearAll()
            },
            onNavigateToContact: onNavigateToContact,
            onSend: {
                sendOperation = SendOperation_iOS {
                    try await viewModel.executeSend()
                }
            },
            amount: $viewModel.amount,
            selectedDestination: $viewModel.selectedDestination,
            showFeeSelectionSheet: $viewModel.showFeeSelectionSheet,
            selectedFeePriority: $viewModel.selectedFeePriority,
            maxSpendableAmount: viewModel.maxSpendableAmount,
            availableBalanceText: viewModel.availableBalanceText,
            availableBalanceName: viewModel.availableBalanceName,
            availableBalanceAmount: viewModel.availableBalanceAmount,
            feeText: viewModel.feeText ?? "",
            feeAmount: viewModel.feeAmount,
            isAmountLocked: viewModel.isAmountLocked,
            lockedAmountReason: viewModel.lockedAmountReason,
            minimumSendAmount: viewModel.minimumSendAmount,
            paymentContext: viewModel.paymentContext,
            shouldShowFeeDisclosure: viewModel.shouldShowFeeDisclosure,
            onchainFeeRates: viewModel.onchainFeeRates
        )
    }
    
    @ViewBuilder
    private func quickModeView(viewModel: SendViewModel, paymentRequest: PaymentRequest, source: PaymentRequestSource) -> some View {
        @Bindable var viewModel = viewModel
        
        QuickPaymentView(
            paymentRequest: paymentRequest,
            onDismiss: {
                viewModel.clearAll()
            },
            onSendImmediately: { destinationId, enteredAmount in
                // Capture values immediately to avoid state race conditions
                let capturedDestinationId = destinationId
                let capturedAmount = enteredAmount
                
                // Determine the amount to send
                let amountToSend: String?
                if let entered = capturedAmount, !entered.isEmpty {
                    amountToSend = entered
                } else if let amount = paymentRequest.amount {
                    amountToSend = "\(amount)"
                } else {
                    amountToSend = nil
                }
                
                sendOperation = SendOperation_iOS {
                    try await viewModel.executeSend(paymentRequest: paymentRequest, destinationId: capturedDestinationId, amount: amountToSend)
                }
            },
            currentNetwork: viewModel.currentNetworkConfig,
            paymentContext: viewModel.paymentContext,
            minimumSendAmount: viewModel.minimumSendAmount,
            contactLookup: { address in
                let normalizedAddress = address.lowercased()
                let contacts = ServiceContainer.shared.contactService.contacts
                return contacts.first { contact in
                    contact.addresses.contains { $0.normalizedAddress == normalizedAddress }
                }
            },
            maxSpendableAmount: viewModel.maxSpendableAmount,
            availableBalanceText: viewModel.availableBalanceText,
            feeText: viewModel.feeText ?? "",
            feeAmount: viewModel.feeAmount,
            shouldShowFeeDisclosure: viewModel.shouldShowFeeDisclosure,
            onchainFeeRates: viewModel.onchainFeeRates,
            showFeeSelectionSheet: $viewModel.showFeeSelectionSheet,
            selectedFeePriority: $viewModel.selectedFeePriority,
            source: source
        )
    }
    
    @ViewBuilder
    private func errorView(viewModel: SendViewModel, error: String) -> some View {
        ErrorView(
            errorMessage: error,
            onRetry: {
                sendOperation = SendOperation_iOS {
                    try await viewModel.executeSend()
                }
            },
            onDismiss: {
                viewModel.error = nil
            }
        )
        .frame(maxWidth: 400)
    }
}

// MARK: - Camera Placeholder View

struct CameraPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.Arke.blue.opacity(0.3)
            
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                Text("label_camera_view")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                Text("send_qr_scanner_placeholder")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("Empty State - Manual Entry") {
    NavigationStack {
        SendView_iOS()
            .environment(WalletManager(useMock: true))
    }
}

#Preview("Pre-filled Bitcoin Address") {
    NavigationStack {
        SendView_iOS(
            prefilledRecipient: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            prefilledContact: nil
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("Pre-filled Contact") {
    NavigationStack {
        SendView_iOS(
            prefilledRecipient: "ark1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            prefilledContact: ContactModel(
                cachedName: "Alice Johnson",
                notes: "Friend from work"
            )
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("BIP-21 with Label and Message") {
    NavigationStack {
        SendView_iOS(
            prefilledRecipient: "bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.001&label=Coffee%20Shop&message=Order%20%2342"
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("BIP-21 with Ark Alternative (Quick Mode)") {
    NavigationStack {
        SendView_iOS(
            prefilledRecipient: "bitcoin:tb1pxks6xl9e05xc3atcewg2tyyzgqm5n6mj6aduss3f0pau27206stsax872h?amount=0.00005&label=Coffee%20Shop&ark=tark1pm6sr0fpzqqpu4k5llkn6wdswx48fwjjujgu4gm679lqwudrzghz7a2rx7wuup9cpqq6ssw20&message=Venti%20White%20Caramel%20Crunch%20Frappuccino%20with%20Almond%20Milk%2C%20Extra%20Hot%2C%20Caramel%20Drizzle%2C%20and%20Extra%20Whip%20Cream"
        )
        .environment(WalletManager(useMock: true))
    }
}

#Preview("Lightning Invoice") {
    NavigationStack {
        SendView_iOS(
            prefilledRecipient: "lnbc1000n1pj9x7zmpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpu"
        )
        .environment(WalletManager(useMock: true))
    }
}
