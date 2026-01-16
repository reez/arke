//
//  AddressCard.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI

struct AddressCardExpandable: View {
    let address: String
    let shareContent: String?
    @State private var showingCopied = false
    @State private var isExpanded = false
    @State private var hoveredChunkIndex: Int? = nil
    
    init(address: String, shareContent: String? = nil) {
        self.address = address
        self.shareContent = shareContent
    }
    
    private var fontSize: CGFloat {
        #if os(macOS)
        isExpanded ? 18 : 14
        #else
        isExpanded ? 20 : 17
        #endif
    }
    
    private func collapsedAddress(chunks: [String], spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<min(2, chunks.count), id: \.self) { index in
                Text(chunks[index])
                    .foregroundStyle(.secondary)
                    .fontWeight(.regular)
                    .lineLimit(1)
                    .fixedSize()
            }
            
            if chunks.count > 4 {
                Text("...")
                    .foregroundStyle(.secondary)
                    .fontWeight(.regular)
            }
            
            ForEach(max(2, chunks.count - 2)..<chunks.count, id: \.self) { index in
                Text(chunks[index])
                    .foregroundStyle(.secondary)
                    .fontWeight(.regular)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
    
    private func expandedAddress(chunks: [String], spacing: CGFloat) -> some View {
        let indexedChunks = chunks.enumerated().map { IndexedChunk(index: $0.offset, chunk: $0.element) }
        
        return FlexWrapView(data: indexedChunks, spacing: spacing) { indexedChunk in
            let isFirstOrLast = indexedChunk.index < 2 || indexedChunk.index >= chunks.count - 2
            let isHovered = hoveredChunkIndex == indexedChunk.index
            let textColor: Color = isFirstOrLast ? .primary : .secondary
            let textWeight: Font.Weight = isFirstOrLast ? .semibold : .regular
            
            Text(indexedChunk.chunk)
                .foregroundStyle(textColor)
                .fontWeight(textWeight)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovered ? Color.accentColor.opacity(0.2) : Color.clear)
                )
                .onHover { hovering in
                    hoveredChunkIndex = hovering ? indexedChunk.index : nil
                }
        }
    }
    
    @ViewBuilder
    private func formattedAddress() -> some View {
        let chunks = address.chunked(into: 4)
        let spacing = fontSize * 0.3 // Proportional to font size
        
        ZStack(alignment: .topLeading) {
            // Collapsed view - always present
            collapsedAddress(chunks: chunks, spacing: spacing)
                .font(.system(size: fontSize, design: .monospaced))
                .opacity(isExpanded ? 0 : 1)
                .zIndex(isExpanded ? 0 : 1)
            
            // Expanded view - always present
            expandedAddress(chunks: chunks, spacing: spacing)
                .font(.system(size: fontSize, design: .monospaced))
                .opacity(isExpanded ? 1 : 0)
                .zIndex(isExpanded ? 1 : 0)
        }
        .frame(height: isExpanded ? nil : fontSize * 1.3, alignment: .topLeading)
        .clipped()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                formattedAddress()
                    .font(.system(size: fontSize, design: .monospaced))
                    .animation(.easeInOut(duration: 0.3), value: fontSize)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }
                
                Spacer(minLength: 8)
    
                Button {
                    copyToClipboard(address)
                    showingCopied = true
                    
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        showingCopied = false
                    }
                } label: {
                    Image(systemName: showingCopied ? "checkmark" : "doc.on.doc.fill")
                }
                .buttonStyle(.bordered)
                .help("Copy address")
            }
        }
    }
}

#Preview {
    AddressCardExpandable(
        address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        shareContent: "bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
    )
    .padding()
}
