//
//  BalanceInfoSheet.swift
//  Arké
//
//  Created by Christoph on 2/5/26.
//

import SwiftUI
import ArkeUI

struct BalanceInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("balance_about_title")
                        .font(.system(size: 30, design: .serif))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                
                    // Payments Balance Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image("wallet")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                            
                            Text("balance_payments")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text("balance_payments_help")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BalanceInfoSheetRow(icon: "hare", text: NSLocalizedString("balance_payments_fast", comment: ""))
                            BalanceInfoSheetRow(icon: "bitcoinsign", text: NSLocalizedString("balance_payments_low_fees", comment: ""))
                            BalanceInfoSheetRow(icon: "calendar", text: NSLocalizedString("balance_payments_periodic_fees", comment: ""))
                            BalanceInfoSheetRow(icon: "network", text: NSLocalizedString("balance_payments_ark_server", comment: ""))
                        }
                    }
                    
                    Divider()
                    
                    // Savings Balance Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image("safe")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                            
                            Text("balance_savings")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text("balance_savings_help")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BalanceInfoSheetRow(icon: "tortoise.fill", text: NSLocalizedString("balance_savings_slow", comment: ""))
                            BalanceInfoSheetRow(icon: "bitcoinsign", text: NSLocalizedString("balance_savings_high_fees", comment: ""))
                            BalanceInfoSheetRow(icon: "checkmark.circle.fill", text: NSLocalizedString("balance_savings_no_fees", comment: ""))
                            BalanceInfoSheetRow(icon: "network", text: NSLocalizedString("balance_savings_bitcoin_network", comment: ""))
                        }
                    }
                    
                    Divider()
                    
                    // Moving Funds Section
                    VStack(alignment: .leading, spacing: 12) {
                        /*
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.arkeGold)
                            
                            Text("Moving Between Balances")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        */
                        
                        Text("balance_arrows_help")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BalanceInfoSheetRow(icon: "arrow.up.circle.fill", text: NSLocalizedString("balance_transfer_savings_to_payments", comment: ""))
                            BalanceInfoSheetRow(icon: "arrow.down.circle.fill", text: NSLocalizedString("balance_transfer_payments_to_savings", comment: ""))
                        }
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("button_done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BalanceInfoSheetRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.Arke.gold)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
        }
    }
}
