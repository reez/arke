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

struct ModalState_iOS: Identifiable {
    let state: SendModalState
    
    var id: String {
        // Generate a stable ID based on the state to avoid recreating the modal
        switch state {
        case .sending:
            return "sending"
        case .success:
            return "success"
        case .error(let message):
            return "error_\(message)"
        }
    }
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
    let doubleTapTrigger: Int
    
    @Environment(WalletManager.self) private var manager
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State
    @State private var viewModel: SendViewModel?
    @State private var inputMethod: SendInputMethod_iOS = .camera
    @State private var showContactPicker: Bool = false
    
    // MARK: - Initializers
    init(prefilledRecipient: String? = nil, prefilledContact: ContactModel? = nil, onNavigateToContact: ((ContactModel) -> Void)? = nil, doubleTapTrigger: Int = 0) {
        self.prefilledRecipient = prefilledRecipient
        self.prefilledContact = prefilledContact
        self.onNavigateToContact = onNavigateToContact
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
                        viewModel?.onDismiss = { dismiss() }
                        await viewModel?.handleInitialSetup(
                            prefilledRecipient: prefilledRecipient,
                            prefilledContact: prefilledContact
                        )
                        print("✅ [SendView_iOS] Initial setup completed")
                    }
            }
        }
    }
    
    @ViewBuilder
    private func contentView(viewModel: SendViewModel) -> some View {
        @Bindable var viewModel = viewModel
        
        mainContentStack(viewModel: viewModel)
            .sheet(item: modalStateBinding(for: viewModel)) { modalState in
                modalSheetContent(for: modalState)
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
            .onChange(of: viewModel.sendModalState) {
                print("🔄 [SendView_iOS] sendModalState changed to: \(String(describing: viewModel.sendModalState))")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // On iOS, we don't auto-check clipboard on app focus (Option C)
                // This avoids spamming the user with permission dialogs
                // If needed in the future, could add a manual "Check Clipboard" button
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
                }
            }
        }
    }
    
    @ViewBuilder
    private func inputMethodPicker() -> some View {
        SendInputMethodPicker_iOS(inputMethod: $inputMethod)
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
            Task {
                print("📸 [SendView_iOS] Parsing scanned code...")
                
                // Parse the scanned code into a payment request
                if let paymentRequest = AddressValidator.parsePaymentRequest(scannedCode) {
                    print("✅ [SendView_iOS] Valid payment request parsed: \(paymentRequest)")
                    print("   └─ Amount: \(paymentRequest.amount?.description ?? "none")")
                    
                    // Lock in the payment request to populate the form
                    viewModel.lockInPaymentRequest(paymentRequest)
                    print("✅ [SendView_iOS] Payment request locked in")
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
    }
    
    private func modalStateBinding(for viewModel: SendViewModel) -> Binding<ModalState_iOS?> {
        Binding(
            get: { 
                let state = viewModel.sendModalState.map { ModalState_iOS(state: $0) }
                print("🔍 [SendView_iOS] modalStateBinding GET: \(String(describing: state?.state))")
                return state
            },
            set: { newValue in
                print("🔍 [SendView_iOS] modalStateBinding SET: \(String(describing: newValue?.state)) → nil")
                viewModel.sendModalState = nil
            }
        )
    }
    
    @ViewBuilder
    private func modalSheetContent(for modalState: ModalState_iOS) -> some View {
        NavigationStack {
            SendModalView(
                state: modalState.state,
                onClearModalState: {
                    print("🧹 [SendView_iOS] Clearing sendModalState")
                    viewModel?.sendModalState = nil
                },
                onDismissEntireView: {
                    print("👋 [SendView_iOS] Dismissing entire SendView")
                    viewModel?.onDismiss?()
                }
            )
            .onAppear {
                print("📄 [SendView_iOS] SendModalView appeared with state: \(String(describing: modalState.state))")
            }
            .onDisappear {
                print("📄 [SendView_iOS] SendModalView disappeared")
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            print("📋 [SendView_iOS] Modal sheet appeared")
        }
        .onDisappear {
            print("📋 [SendView_iOS] Modal sheet disappeared")
        }
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
        ContactsView_iOS { contact, address in
            handleContactSelection(contact: contact, address: address)
        }
        .environment(manager)
    }
    
    private func handleContactSelection(contact: ContactModel, address: ContactAddressModel) {
        print("👤 [SendView_iOS] Contact selected: \(contact.displayName)")
        print("📍 [SendView_iOS] Address selected: \(address.address)")
        
        // Populate the send form with the contact
        Task {
            await viewModel?.handleInitialSetup(
                prefilledRecipient: address.address,
                prefilledContact: contact
            )
            
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
        // Option C: Check clipboard only when SendView first appears
        Task {
            await viewModel.checkClipboardForAddress()
        }
    }
    
    @ViewBuilder
    private func modeSpecificContent(viewModel: SendViewModel) -> some View {
        switch viewModel.sendMode {
        case .manual:
            manualModeView(viewModel: viewModel)
            
        case .contact(let contact):
            contactModeView(viewModel: viewModel, contact: contact)
            
        case .quick(let paymentRequest):
            quickModeView(viewModel: viewModel, paymentRequest: paymentRequest)
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
            maxSpendableAmount: viewModel.maxSpendableAmount,
            availableBalanceText: viewModel.availableBalanceText,
            feeText: viewModel.feeText ?? "",
            isAmountLocked: viewModel.isAmountLocked,
            lockedAmountReason: viewModel.lockedAmountReason,
            minimumSendArk: viewModel.minimumSendArk,
            onSend: {
                Task {
                    await viewModel.executeSend()
                }
            }
        )
        .popover(isPresented: $viewModel.showAddressFormatsPopover) {
            AddressFormatsInfoView()
        }
    }
    
    @ViewBuilder
    private func contactModeView(viewModel: SendViewModel, contact: ContactModel) -> some View {
        @Bindable var viewModel = viewModel
        
        ContactPaymentView(
            contact: contact,
            contactAddress: prefilledRecipient,
            onClear: {
                viewModel.clearAll()
            },
            onNavigateToContact: onNavigateToContact,
            onSend: {
                Task {
                    await viewModel.executeSend()
                }
            },
            amount: $viewModel.amount,
            maxSpendableAmount: viewModel.maxSpendableAmount,
            availableBalanceText: viewModel.availableBalanceText,
            feeText: viewModel.feeText ?? "",
            isAmountLocked: viewModel.isAmountLocked,
            lockedAmountReason: viewModel.lockedAmountReason,
            minimumSendArk: viewModel.minimumSendArk
        )
    }
    
    @ViewBuilder
    private func quickModeView(viewModel: SendViewModel, paymentRequest: PaymentRequest) -> some View {
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
                
                Task {
                    await viewModel.executeSend(paymentRequest: paymentRequest, destinationId: capturedDestinationId, amount: amountToSend)
                }
            },
            currentNetwork: viewModel.currentNetworkConfig,
            paymentContext: viewModel.paymentContext,
            minimumSendArk: viewModel.minimumSendArk,
            contactLookup: { address in
                let normalizedAddress = address.lowercased()
                let contacts = ServiceContainer.shared.contactService.contacts
                return contacts.first { contact in
                    contact.addresses.contains { $0.normalizedAddress == normalizedAddress }
                }
            },
            maxSpendableAmount: viewModel.maxSpendableAmount,
            availableBalanceText: viewModel.availableBalanceText,
            feeText: viewModel.feeText ?? ""
        )
    }
    
    @ViewBuilder
    private func errorView(viewModel: SendViewModel, error: String) -> some View {
        ErrorView(
            errorMessage: error,
            onRetry: {
                Task {
                    await viewModel.executeSend()
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
            Color.blue.opacity(0.3)
            
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                Text("Camera View")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                Text("QR Scanner will appear here")
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

#Preview("Lightning Invoice") {
    NavigationStack {
        SendView_iOS(
            prefilledRecipient: "lnbc1000n1pj9x7zmpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpu"
        )
        .environment(WalletManager(useMock: true))
    }
}
