//
//  ReceiveView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
import ArkeUI
import CoreImage.CIFilterBuiltins

enum ReceiveMode_iOS {
    case qrcode
    case addresses
}

struct ReceiveView_iOS: View {
    // MARK: - Initialization Parameters
    let doubleTapTrigger: Int
    
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel: ReceiveViewModel?
    @State private var receiveMode: ReceiveMode_iOS = .qrcode
    @State private var showingBalanceTypeSheet = false
    
    // MARK: - Initializers
    init(doubleTapTrigger: Int = 0) {
        self.doubleTapTrigger = doubleTapTrigger
    }
    
    var body: some View {
        if let viewModel {
            contentView(viewModel: viewModel)
        } else {
            ProgressView()
                .task {
                    viewModel = ReceiveViewModel(walletManager: walletManager)
                }
        }
    }
    
    @ViewBuilder
    private func contentView(viewModel: ReceiveViewModel) -> some View {
        ZStack(alignment: .top) {
            slidingContentView(viewModel: viewModel)
                .zIndex(0)
             
            ZStack {
                // Centered picker
                ReceiveModePicker_iOS(mode: $receiveMode)
                
                // Menu aligned to trailing edge
                HStack {
                    Spacer()
                    balanceTypeMenu(viewModel: viewModel)
                        .padding(.trailing, 10)
                }
            }
            .offset(y: 75)
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: Binding(
            get: { viewModel.showingQRCode },
            set: { if !$0 { viewModel.hideQRCode() } }
        )) {
            qrCodeSheet(viewModel: viewModel)
        }
        .onChange(of: doubleTapTrigger) { oldValue, newValue in
            print("🔔 [ReceiveView_iOS] doubleTapTrigger changed: \(oldValue) → \(newValue)")
            handleDoubleTap()
        }
        .onChange(of: viewModel.selectedBalance) { oldValue, newValue in
            // Auto-switch to addresses mode when Lightning is selected
            if newValue == .lightning {
                withAnimation(.easeInOut(duration: 0.3)) {
                    receiveMode = .addresses
                }
            }
        }
        .onChange(of: viewModel.lightningInvoice) { oldValue, newValue in
            // Auto-switch to QR mode when invoice is generated
            if viewModel.selectedBalance == .lightning && newValue != nil && oldValue == nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    receiveMode = .qrcode
                }
            }
        }
        .sheet(isPresented: $showingBalanceTypeSheet) {
            BalanceTypeSelectionSheet_iOS(
                viewModel: viewModel,
                isPresented: $showingBalanceTypeSheet
            )
        }
    }
    
    // MARK: - Double-Tap Handler
    
    private func handleDoubleTap() {
        print("👆 [ReceiveView_iOS] handleDoubleTap() called")
        print("   └─ Current receiveMode: \(receiveMode)")
        
        // Toggle between qrcode and addresses modes
        withAnimation(.easeInOut(duration: 0.3)) {
            let newMode: ReceiveMode_iOS = receiveMode == .qrcode ? .addresses : .qrcode
            print("   └─ Toggling to: \(newMode)")
            receiveMode = newMode
        }
        
        print("   └─ New receiveMode: \(receiveMode)")
    }
    
    @ViewBuilder
    private func slidingContentView(viewModel: ReceiveViewModel) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                qrCodeModeView(viewModel: viewModel, width: geometry.size.width)
                addressesModeView(viewModel: viewModel, width: geometry.size.width)
            }
            .frame(height: geometry.size.height)
            .offset(x: receiveMode == .qrcode ? 0 : -geometry.size.width)
            .animation(.easeInOut(duration: 0.3), value: receiveMode)
        }
    }
    
    
    // MARK: - Mode Views
    
    @ViewBuilder
    private func qrCodeModeView(viewModel: ReceiveViewModel, width: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Add top padding to account for the floating picker
                Spacer()
                    .frame(height: 135)
                
                // Lightning-specific QR display
                if viewModel.selectedBalance == .lightning {
                    if let invoice = viewModel.lightningInvoice {
                        LightningInvoiceQRDisplayView(
                            invoice: invoice,
                            extractInvoiceFromJSON: viewModel.extractInvoiceFromJSON,
                            onCopyInvoice: {
                                viewModel.copyToClipboard(viewModel.extractInvoiceFromJSON(invoice))
                            },
                            showCopySuccess: viewModel.showCopySuccess
                        )
                        .padding(.horizontal)
                        
                        // Share button for Lightning invoice
                        if let shareContent = viewModel.getShareContent() {
                            ShareLink(item: shareContent) {
                                Text("Share")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle(Color.arkeDark)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 20)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.arkeGold)
                            .controlSize(.large)
                            .padding(.horizontal)
                        }
                    } else {
                        // No invoice generated yet
                        LightningInvoiceQREmptyStateView(onSwitchToAddresses: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                receiveMode = .addresses
                            }
                        })
                        .padding(.horizontal)
                    }
                } else {
                    // Non-Lightning balance types (Bitcoin/Liquid)
                    // Large QR Code Display
                    VStack(spacing: 20) {
                        if let qrContent = viewModel.getCurrentQRContent() {
                            ReceiveQRCodeDisplaySection_iOS(
                                content: qrContent.content,
                                title: qrContent.title
                            )
                        } else {
                            // Placeholder when no content available
                            VStack(spacing: 12) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.secondary)
                                Text("Configure amount to generate QR code")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .cornerRadius(25)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Amount and Note inputs (non-Lightning only)
                    VStack(spacing: 0) {
                        amountAndNoteSection(viewModel: viewModel)
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(25)
                    .padding(.horizontal)
                    
                    // Share button (non-Lightning only)
                    if viewModel.hasQRContent, let shareContent = viewModel.getShareContent() {
                        ShareLink(item: shareContent) {
                            Text("Share")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(Color.arkeDark)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.arkeGold)
                        .controlSize(.large)
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
        }
        .frame(width: width)
    }
    
    @ViewBuilder
    private func addressesModeView(viewModel: ReceiveViewModel, width: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Add top padding to account for the floating picker
                Spacer()
                    .frame(height: 135)
                
                // Lightning-specific form
                if viewModel.selectedBalance == .lightning {
                    LightningInvoiceFormView_iOS(
                        amount: Binding(
                            get: { viewModel.amount },
                            set: { viewModel.amount = $0 }
                        ),
                        note: Binding(
                            get: { viewModel.note },
                            set: { viewModel.note = $0 }
                        ),
                        lightningInvoice: viewModel.lightningInvoice,
                        invoiceError: viewModel.invoiceError,
                        isGeneratingInvoice: viewModel.isGeneratingInvoice,
                        onGenerateInvoice: {
                            Task {
                                await viewModel.generateLightningInvoice()
                            }
                        },
                        onClearInvoice: {
                            viewModel.resetLightningForm()
                        }
                    )
                } else {
                    // Non-Lightning balance types (Bitcoin/Liquid)
                    Text("Your addresses")
                        .font(.system(size: 24, design: .serif))
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 0) {
                        addressContentSection(viewModel: viewModel)
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(25)
                    actionButtonsSection(viewModel: viewModel)
                }
            }
            .padding(.horizontal)
        }
        .frame(width: width)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func addressContentSection(viewModel: ReceiveViewModel) -> some View {
        // Only used for non-Lightning balance types now
        AddressDisplayView(
            selectedBalance: viewModel.selectedBalance,
            amount: viewModel.amount,
            note: viewModel.note
        )
    }
    
    @ViewBuilder
    private func amountAndNoteSection(viewModel vm: ReceiveViewModel) -> some View {
        // Only used for non-Lightning balance types now
        AmountAndNoteInputView(
            amount: Binding(
                get: { vm.amount },
                set: { vm.amount = $0 }
            ),
            note: Binding(
                get: { vm.note },
                set: { vm.note = $0 }
            ),
            showingAmountAndNote: Binding(
                get: { vm.showingAmountAndNote },
                set: { vm.showingAmountAndNote = $0 }
            )
        )
    }
    
    @ViewBuilder
    private func actionButtonsSection(viewModel: ReceiveViewModel) -> some View {
        // This section is now only used for non-Lightning balance types
        // Lightning actions are handled in the form view
        EmptyView()
    }
    
    @ViewBuilder
    private func qrCodeSheet(viewModel: ReceiveViewModel) -> some View {
        if let qrContent = viewModel.getCurrentQRContent() {
            QRCodeView(
                content: qrContent.content,
                title: qrContent.title,
                onClose: { viewModel.hideQRCode() }
            )
            .frame(minWidth: 300, minHeight: 300)
        }
    }
    
    // MARK: - Toolbar Components
    
    @ViewBuilder
    private func balanceTypeMenu(viewModel: ReceiveViewModel) -> some View {
        Button {
            showingBalanceTypeSheet = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
                .frame(width: 40, height: 40)
                .glassEffect()
                .foregroundStyle(.primary)
        }
    }
}

