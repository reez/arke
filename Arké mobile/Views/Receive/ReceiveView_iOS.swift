//
//  ReceiveView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
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
    
    // MARK: - Initializers
    init(doubleTapTrigger: Int = 0) {
        self.doubleTapTrigger = doubleTapTrigger
    }
    
    var body: some View {
        Group {
            if let viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .task {
                        viewModel = ReceiveViewModel(walletManager: walletManager)
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let viewModel {
                    balanceTypeMenu(viewModel: viewModel)
                }
            }
        }
    }
    
    @ViewBuilder
    private func contentView(viewModel: ReceiveViewModel) -> some View {
        ZStack {
            slidingContentView(viewModel: viewModel)
            
            // Floating mode picker overlay
            VStack {
                modePickerOverlay()
                
                Spacer()
            }
            .padding(.top, 75)
            .ignoresSafeArea(edges: .top)
        }
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
    }
    
    @ViewBuilder
    private func modePickerOverlay() -> some View {
        ReceiveModePicker_iOS(mode: $receiveMode)
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
            VStack(spacing: 10) {
                // Add top padding to account for the floating picker
                Spacer()
                    .frame(height: 5)
                
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
                
                // Amount and Note inputs
                VStack(spacing: 0) {
                    amountAndNoteSection(viewModel: viewModel)
                }
                .background(.ultraThinMaterial)
                .cornerRadius(25)
                .padding(.horizontal)
                
                // Share button
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
                
                Spacer()
            }
        }
        .frame(width: width)
    }
    
    @ViewBuilder
    private func addressesModeView(viewModel: ReceiveViewModel, width: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 30) {
                // Add top padding to account for the floating picker
                Spacer()
                    .frame(height: 5)
                
                Text("Your addresses")
                    .font(.system(size: 24, design: .serif))
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 0) {
                    addressContentSection(viewModel: viewModel)
                    /*
                    Divider()
                        .padding(.leading, 25)
                        .padding(.trailing, 25)
                    amountAndNoteSection(viewModel: viewModel)
                    */
                }
                .background(.ultraThinMaterial)
                .cornerRadius(25)
                actionButtonsSection(viewModel: viewModel)
            }
            .padding()
        }
        .frame(width: width)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func addressContentSection(viewModel: ReceiveViewModel) -> some View {
        if viewModel.selectedBalance != .lightning {
            AddressDisplayView(
                selectedBalance: viewModel.selectedBalance,
                amount: viewModel.amount,
                note: viewModel.note
            )
        } else {
            if viewModel.lightningInvoice == nil {
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
    private func amountAndNoteSection(viewModel vm: ReceiveViewModel) -> some View {
        if vm.selectedBalance == .lightning {
            LightningAmountInputSection(
                amount: Binding(
                    get: { vm.amount },
                    set: { vm.amount = $0 }
                ),
                note: Binding(
                    get: { vm.note },
                    set: { vm.note = $0 }
                ),
                lightningInvoice: vm.lightningInvoice,
                invoiceError: vm.invoiceError,
                onAmountChange: { vm.clearLightningInvoice() },
                onNoteChange: { vm.clearLightningInvoice() },
                onInvoiceTap: {
                    if let invoice = vm.lightningInvoice {
                        vm.copyToClipboard(vm.extractInvoiceFromJSON(invoice))
                    }
                },
                showCopySuccess: vm.showCopySuccess
            )
        } else {
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
    }
    
    @ViewBuilder
    private func actionButtonsSection(viewModel: ReceiveViewModel) -> some View {
        if viewModel.selectedBalance == .lightning {
            LightningActionSection(
                amount: viewModel.amount,
                lightningInvoice: viewModel.lightningInvoice,
                isGeneratingInvoice: viewModel.isGeneratingInvoice,
                onCreateInvoice: {
                    Task {
                        await viewModel.generateLightningInvoice()
                    }
                },
                onShowQRCode: { viewModel.showQRCode() },
                extractInvoiceFromJSON: viewModel.extractInvoiceFromJSON
            )
        } else {
            /*
            ActionButtonsView(
                selectedBalance: viewModel.selectedBalance,
                shareContent: viewModel.getShareContent(),
                hasQRContent: viewModel.hasQRContent,
                onShowQRCode: { viewModel.showQRCode() }
            )
             */
        }
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
        Menu {
            Section {
                ForEach(ReceiveBalanceType.allCases, id: \.self) { balanceType in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.changeBalanceType(to: balanceType)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(balanceType.rawValue)
                                    .font(.body)
                                Text(balanceType.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if viewModel.selectedBalance == balanceType {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text("Choose Address Type")
            }
        } label: {
            HStack(spacing: 6) {
                /*
                Text(viewModel.balanceTypeLabel)
                    .font(.body)
                */
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.primary)
        }
    }
}

