//
//  TransactionService+AddressLinking.swift
//  Arke
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import SwiftData
import ArkeUI

extension TransactionService {
    
    // MARK: - Internal (Extension Use Only)
    
    /// Link a transaction to its address for internal transfer detection
    /// - Parameter transaction: The transaction to link
    func linkTransactionToAddress(_ transaction: PersistentTransaction) async {
        guard let addressService = addressService else {
            // AddressService not available yet - this is OK during initialization
            return
        }
        
        guard let address = transaction.address else {
            // No address on transaction - this is normal for some transaction types
            // However, we still need to check for category-based internal transfers below
            
            // Handle all transfer/internal operations by category (for transactions without addresses)
            if transaction.subsystemCategory != "internal_transfer" {
                let category = MovementCategory(rawValue: transaction.subsystemCategory ?? "") ?? .unknown
                if category == .refresh || category == .boarding || category == .exit || category == .offboarding {
                    transaction.subsystemCategory = "internal_transfer"
                    await autoTagInternalTransfer(transaction)
                    print("🔄 Auto-tagged internal operation: \(transaction.txid) (category: \(category.displayName))")
                }
            }
            
            return
        }
        
        // Handle received transactions: mark address as used
        if transaction.type == "received" {
            await addressService.markAddressAsUsed(
                address: address,
                transaction: transaction
            )
            
            // Link the address to transaction
            if let persistentAddr = await addressService.getAddressByString(address) {
                transaction.receivingAddress = persistentAddr
                print("✅ Linked received transaction \(transaction.txid) to address \(address)")
            }
        }
        
        // Handle sent transactions: check if internal transfer
        // This includes regular sends and onchain sends (bark.offboard send_onchain)
        if transaction.type == "sent" {
            let isOwn = await addressService.isOwnAddress(address)
            if isOwn {
                // This is an internal transfer!
                // For onchain sends to own address, keep the onchainSend category
                // but mark it by linking the receivingAddress
                let category = MovementCategory(rawValue: transaction.subsystemCategory ?? "") ?? .unknown
                
                if category != .onchainSend {
                    // Regular sends to own address - mark as internal_transfer
                    transaction.subsystemCategory = "internal_transfer"
                }
                // For onchainSend, don't change category - the receivingAddress link will indicate it's internal
                
                // Link to receiving address
                if let persistentAddr = await addressService.getAddressByString(address) {
                    transaction.receivingAddress = persistentAddr
                    if category == .onchainSend {
                        print("🔄 Detected onchain send to own address: \(transaction.txid) to \(address)")
                    } else {
                        print("🔄 Detected internal transfer: \(transaction.txid) to \(address)")
                    }
                }
                
                // Auto-tag with "Balance" system tag
                await autoTagInternalTransfer(transaction)
            }
        }
        
        // Handle all transfer/internal operations by category (for transactions with addresses)
        if transaction.subsystemCategory != "internal_transfer" {
            let category = MovementCategory(rawValue: transaction.subsystemCategory ?? "") ?? .unknown
            if category == .refresh || category == .boarding || category == .exit || category == .offboarding {
                transaction.subsystemCategory = "internal_transfer"
                
                // Link to address if available
                if let persistentAddr = await addressService.getAddressByString(address) {
                    transaction.receivingAddress = persistentAddr
                }
                
                await autoTagInternalTransfer(transaction)
                print("🔄 Auto-tagged internal operation: \(transaction.txid) (category: \(category.displayName))")
            }
        }
    }
}
