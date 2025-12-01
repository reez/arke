//
//  DetailRow.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/5/25.
//

import SwiftUI

struct DetailRow: View {
    let title: String
    let value: String
    let isCopyable: Bool
    
    init(title: String, value: String, isCopyable: Bool = false) {
        self.title = title
        self.value = value
        self.isCopyable = isCopyable
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if isCopyable {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        DetailRow(
            title: "Address",
            value: "0x1234567890abcdef1234567890abcdef12345678",
            isCopyable: true
        )
        
        DetailRow(
            title: "Balance",
            value: "1.5 ETH"
        )
        
        DetailRow(
            title: "Transaction Hash",
            value: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            isCopyable: true
        )
        
        DetailRow(
            title: "Status",
            value: "Confirmed"
        )
    }
    .padding()
    .frame(width: 400)
}
