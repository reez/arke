//
//  TransactionContactView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/4/25.
//

import SwiftUI
import SwiftData

struct TransactionContactView: View {
    let transaction: TransactionModel
    @Environment(WalletManager.self) private var walletManager
    
    @State private var showingContactSelector = false
    @State private var assignedContact: ContactModel?
    @State private var isContactLoading = false
    @State private var error: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isContactLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let assignedContact = assignedContact {
                FlowLayout(alignment: .leading, spacing: 8) {
                    ContactChip_Removable(contact: assignedContact, size: .large) {
                        Task {
                            await removeContact()
                        }
                    }
                    
                    // Edit contact button styled like a chip
                    Button("Change") {
                        showingContactSelector = true
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .fontWeight(.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isContactLoading)
                }
            } else {
                FlowLayout(alignment: .leading, spacing: 8) {
                    // Add contact button styled like a ContactChip
                    Button("Add contact") {
                        showingContactSelector = true
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .fontWeight(.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isContactLoading)
                }
            }
            
            if let error = error {
                ErrorView(errorMessage: error)
            }
        }
        .task(id: transaction.txid) {
            await loadAssignedContact()
        }
        .sheet(isPresented: $showingContactSelector) {
            ContactSelectorSheet(
                selectedContactId: Binding(
                    get: { assignedContact?.id },
                    set: { _ in }
                ),
                transactionId: transaction.txid,
                onAssignContact: { contact in
                    await MainActor.run {
                        self.assignedContact = contact
                    }
                }
            )
            .environment(walletManager)
            .frame(width: 600, height: 500)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadAssignedContact() async {
        isContactLoading = true
        error = nil
        
        do {
            let contacts = try await walletManager.getTransactionContacts(transaction.txid)
            await MainActor.run {
                self.assignedContact = contacts.first
                self.isContactLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isContactLoading = false
            }
        }
    }
    
    private func removeContact() async {
        isContactLoading = true
        error = nil
        
        do {
            try await walletManager.removeContactAssignment(from: transaction.txid)
            await MainActor.run {
                self.assignedContact = nil
                self.isContactLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isContactLoading = false
            }
        }
    }
}

#Preview {
    TransactionContactView(
        transaction: TransactionModel(
            txid: "sample-123",
            movementId: nil,
            recipientIndex: nil,
            type: .received,
            amount: 50000,
            date: Date(),
            status: .confirmed,
            address: nil
        )
    )
    .environment(WalletManager(useMock: true))
    .frame(width: 400, height: 200)
}
