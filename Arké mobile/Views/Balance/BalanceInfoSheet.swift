//
//  BalanceInfoSheet.swift
//  Arké
//
//  Created by Christoph on 2/5/26.
//

import SwiftUI

struct BalanceInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("About Your Balances")
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
                            
                            Text("Payments Balance")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text("Your Payments Balance uses the Ark protocol to enable fast, low-fee Bitcoin payments similar to Lightning.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BalanceInfoSheetRow(icon: "hare", text: "Super-fast payments")
                            BalanceInfoSheetRow(icon: "bitcoinsign", text: "Low transaction fees")
                            BalanceInfoSheetRow(icon: "calendar", text: "Periodic maintenance fees")
                            BalanceInfoSheetRow(icon: "network", text: "Facilitated by an Ark server")
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
                            
                            Text("Savings Balance")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text("Your Savings Balance is standard Bitcoin held directly on the blockchain with full security.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BalanceInfoSheetRow(icon: "tortoise.fill", text: "Slow payments (10+ minutes)")
                            BalanceInfoSheetRow(icon: "bitcoinsign", text: "High transaction fees")
                            BalanceInfoSheetRow(icon: "checkmark.circle.fill", text: "No maintenance fees")
                            BalanceInfoSheetRow(icon: "network", text: "Uses the Bitcoin Network")
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
                        
                        Text("Use the arrows between your balances to move funds.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BalanceInfoSheetRow(icon: "arrow.up.circle.fill", text: "From Savings to Payments")
                            BalanceInfoSheetRow(icon: "arrow.down.circle.fill", text: "From Payments to Savings")
                        }
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
                .foregroundColor(.arkeGold)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
        }
    }
}
