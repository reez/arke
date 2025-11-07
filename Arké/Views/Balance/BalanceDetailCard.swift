//
//  BalanceDetailCard.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/17/25.
//

import SwiftUI

struct BalanceDetailCard: View {
    let title: String
    let description: String
    let spendable: Int
    let pending: Int
    let total: Int
    let color: Color
    let imageName: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 25) {
            Image(imageName)
                .resizable()
                .frame(width: 150, height: 150)
                .cornerRadius(15)
            
            VStack(alignment: .leading, spacing: 20) {
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .fontWeight(.regular)
                        .font(.system(size: 30, design: .serif))
                    
                    Text(description)
                        .font(.footnote)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Available")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(spendable.formatted()) ₿")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Pending")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(pending.formatted()) ₿")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total")
                            .font(.title2)
                        Spacer()
                        Text("\(total.formatted()) ₿")
                            .font(.title2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 16) {
        BalanceDetailCard(
            title: "Payments balance",
            description: "Fast & low fees · Ark network",
            spendable: 150000,
            pending: 25000,
            total: 175000,
            color: .orange,
            imageName: "wallet"
        )
        
        BalanceDetailCard(
            title: "Savings balance",
            description: "Best security · Bitcoin network",
            spendable: 75000,
            pending: 0,
            total: 75000,
            color: .blue,
            imageName: "safe"
        )
    }
    .padding()
}
