//
//  ReceiveView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiveView_iOS: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel: ReceiveViewModel?
    
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
    }
    
    @ViewBuilder
    private func contentView(viewModel: ReceiveViewModel) -> some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 0) {
                    addressContentSection(viewModel: viewModel)
                    Divider()
                        .padding(.leading, 25)
                        .padding(.trailing, 25)
                    amountAndNoteSection(viewModel: viewModel)
                }
                .background(.ultraThinMaterial)
                .cornerRadius(25)
                actionButtonsSection(viewModel: viewModel)
            }
            .padding()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingQRCode },
            set: { if !$0 { viewModel.hideQRCode() } }
        )) {
            qrCodeSheet(viewModel: viewModel)
        }
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
            ActionButtonsView(
                selectedBalance: viewModel.selectedBalance,
                shareContent: viewModel.getShareContent(),
                hasQRContent: viewModel.hasQRContent,
                onShowQRCode: { viewModel.showQRCode() }
            )
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
}
