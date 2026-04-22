//
//  InvoiceGenerationTestView_iOS.swift
//  Arké
//
//  Created by Assistant on 12/15/25.
//

import SwiftUI
import ArkeUI
import UIKit

/// Test view for generating multiple Lightning invoices and copying them to clipboard
struct InvoiceGenerationTestView_iOS: View {
    @Environment(WalletManager.self) private var manager
    
    // Test configuration
    @State private var count: String = "5"
    @State private var amount: String = "100"
    
    // Test state
    @State private var isRunning: Bool = false
    @State private var generatedCount: Int = 0
    @State private var failedCount: Int = 0
    @State private var currentTask: Task<Void, Never>?
    @State private var invoices: [String] = []
    @State private var showCopiedAlert: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Generate multiple lightning invoices for testing and copy them to the clipboard.")
                    .font(.body)
                    .foregroundColor(.secondary)
            
                VStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Count")
                            .font(.body)
                            .foregroundColor(.secondary)
                        TextField("Number of invoices to generate", text: $count)
                            .keyboardType(.numberPad)
                            .disabled(isRunning)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount (sats)")
                            .font(.body)
                            .foregroundColor(.secondary)
                        TextField("Invoice amount", text: $amount)
                            .keyboardType(.numberPad)
                            .disabled(isRunning)
                    }
                    .padding(.vertical, 4)
                }
                
                if isRunning {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Progress:")
                            Spacer()
                            Text("\(generatedCount)/\(Int(count) ?? 0) generated, \(failedCount) failed")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("STOP", role: .destructive) {
                            stopTest()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                } else if !invoices.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Results:")
                            Spacer()
                            Text("\(invoices.count) invoices generated")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Copy All to Clipboard") {
                            copyInvoicesToClipboard()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Clear Results") {
                            clearResults()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button("Generate Invoices") {
                        startTest()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(count.isEmpty || amount.isEmpty)
                }
            
                if !invoices.isEmpty {
                    ForEach(Array(invoices.enumerated()), id: \.offset) { index, invoice in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Invoice #\(index + 1)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(invoice)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = invoice
                                showCopiedAlert = true
                            }) {
                                Label("Copy Invoice", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Invoice Generation")
        .navigationBarTitleDisplayMode(.large)
        .alert("Copied!", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(invoices.count > 1 ? "All invoices copied to clipboard" : "Invoice copied to clipboard")
        }
    }
    
    private func startTest() {
        guard let totalCount = Int(count),
              let invoiceAmount = Int(amount) else {
            print("❌ Invalid input parameters")
            return
        }
        
        isRunning = true
        generatedCount = 0
        failedCount = 0
        invoices = []
        
        currentTask = Task { @MainActor in
            print("🚀 Starting invoice generation test")
            print("   → Count: \(totalCount)")
            print("   → Amount: \(invoiceAmount) sats")
            
            for i in 0..<totalCount {
                if Task.isCancelled {
                    print("⏹️ Test cancelled by user")
                    break
                }
                
                print("📝 Generating invoice \(i+1)/\(totalCount)")
                
                do {
                    let invoice = try await manager.getLightningInvoice(amount: invoiceAmount)
                    invoices.append(invoice)
                    generatedCount += 1
                    print("   ✅ Success (\(generatedCount)/\(totalCount))")
                    
                } catch {
                    failedCount += 1
                    print("   ❌ Failed: \(error.localizedDescription)")
                    
                    // Continue on error instead of stopping
                }
            }
            
            isRunning = false
            print("🏁 Test completed: \(generatedCount) generated, \(failedCount) failed")
        }
    }
    
    private func stopTest() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
        print("⏹️ Test stopped by user")
    }
    
    private func copyInvoicesToClipboard() {
        let allInvoices = invoices.joined(separator: "\n")
        UIPasteboard.general.string = allInvoices
        showCopiedAlert = true
        print("📋 Copied \(invoices.count) invoices to clipboard")
    }
    
    private func clearResults() {
        invoices = []
        generatedCount = 0
        failedCount = 0
        print("🗑️ Results cleared")
    }
}

#Preview {
    NavigationStack {
        InvoiceGenerationTestView_iOS()
            .environment(WalletManager(useMock: true))
    }
}
