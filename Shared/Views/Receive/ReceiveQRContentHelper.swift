//
//  ReceiveQRContentHelper.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/21/25.
//

import Foundation

struct ReceiveQRContentHelper {
    static func getCurrentQRContent(
        selectedBalance: ReceiveBalanceType,
        amount: String,
        note: String,
        arkAddress: String,
        onchainAddress: String,
        label: String? = nil
    ) -> (content: String, title: String)? {
        let amountValue = amount.isEmpty ? nil : amount
        let noteValue = note.isEmpty ? nil : note
        
        switch selectedBalance {
        case .payments:
            guard !arkAddress.isEmpty else { return nil }
            return (
                content: BIP21URIHelper.createBIP21URI(
                    arkAddress: arkAddress,
                    amountSats: amountValue,
                    label: label,
                    message: noteValue ?? nil
                ),
                title: "Receive to Payments"
            )
            
        case .savings:
            guard !onchainAddress.isEmpty else { return nil }
            return (
                content: BIP21URIHelper.createBIP21URI(
                    onchainAddress: onchainAddress,
                    amountSats: amountValue,
                    label: label,
                    message: noteValue ?? nil
                ),
                title: "Receive to Savings"
            )
            
        case .paymentsAndSavings:
            guard !arkAddress.isEmpty || !onchainAddress.isEmpty else { return nil }
            let combinedURI = BIP21URIHelper.createBIP21URI(
                arkAddress: arkAddress,
                onchainAddress: onchainAddress,
                label: label,
                message: noteValue ?? nil
            )
            return (
                content: combinedURI,
                title: "Receive to Payments or Savings"
            )
            
        case .lightning:
            return nil // Lightning not supported yet
        }
    }
    
    static func getShareContent(
        selectedBalance: ReceiveBalanceType,
        amount: String,
        note: String,
        arkAddress: String,
        onchainAddress: String,
        label: String? = nil
    ) -> String? {
        switch selectedBalance {
        case .payments:
            guard !arkAddress.isEmpty else { return nil }
            return BIP21URIHelper.createBIP21URI(
                arkAddress: arkAddress,
                amountSats: amount.isEmpty ? nil : amount,
                label: label,
                message: note.isEmpty ? nil : note
            )
            
        case .savings:
            guard !onchainAddress.isEmpty else { return nil }
            return BIP21URIHelper.createBIP21URI(
                onchainAddress: onchainAddress,
                amountSats: amount.isEmpty ? nil : amount,
                label: label,
                message: note.isEmpty ? nil : note
            )
            
        case .paymentsAndSavings:
            guard !arkAddress.isEmpty || !onchainAddress.isEmpty else { return nil }
            return BIP21URIHelper.createBIP21URI(
                arkAddress: arkAddress,
                onchainAddress: onchainAddress,
                label: label,
                message: note.isEmpty ? nil : note
            )
            
        case .lightning:
            return nil
        }
    }
}
