//
//  AddressCard.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI
import ArkeUI

struct AddressCard: View {
    let address: String
    let shareContent: String?
    @State private var showingCopied = false
    @State private var fontSize: CGFloat = 14
    
    init(address: String, shareContent: String? = nil) {
        self.address = address
        self.shareContent = shareContent
    }
    
    private func formattedAddress() -> some View {
        let chunks = address.chunked(into: 4)
        let indexedChunks = chunks.enumerated().map { IndexedChunk(index: $0.offset, chunk: $0.element) }
        let spacing = fontSize * 0.3 // Proportional to font size
        
        return FlexWrapView(data: indexedChunks, spacing: spacing) { indexedChunk in
            let isFirstOrLast = indexedChunk.index < 2 || indexedChunk.index >= chunks.count - 2
            let textColor: Color = isFirstOrLast ? .primary : .secondary
            let textWeight: Font.Weight = isFirstOrLast ? .semibold : .regular
            
            Text(indexedChunk.chunk)
                .foregroundStyle(textColor)
                .fontWeight(textWeight)
                .lineLimit(1)
                .fixedSize()
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                formattedAddress()
                    .font(.system(size: fontSize, design: .monospaced))
                    .animation(.easeInOut(duration: 0.3), value: fontSize)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            fontSize = fontSize == 14 ? 20 : 14
                        }
                    }
                
                Spacer()
    
                Button {
                    copyToClipboard(address)
                    showingCopied = true
                    
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        showingCopied = false
                    }
                } label: {
                    Image(systemName: showingCopied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("action_copy_address")
            }
        }
    }
}

#Preview {
    AddressCard(
        address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        shareContent: "bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
    )
    .padding()
}
