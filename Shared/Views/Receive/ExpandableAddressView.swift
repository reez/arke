//
//  ExpandableAddressView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 1/19/26.
//

import SwiftUI

/// A reusable view that displays an address in an expandable format.
/// Tap to toggle between collapsed and expanded states.
struct ExpandableAddressView: View {
    let address: String
    let animated: Bool
    @State private var internalIsExpanded: Bool = false
    private var externalIsExpanded: Binding<Bool>?
    @State private var hoveredChunkIndex: Int? = nil
    
    private var isExpanded: Bool {
        get { externalIsExpanded?.wrappedValue ?? internalIsExpanded }
        nonmutating set {
            if let binding = externalIsExpanded {
                binding.wrappedValue = newValue
            } else {
                internalIsExpanded = newValue
            }
        }
    }
    
    /// Creates an expandable address view with internal state management
    init(address: String, animated: Bool = true) {
        self.address = address
        self.animated = animated
        self.externalIsExpanded = nil
    }
    
    /// Creates an expandable address view with external state binding
    init(address: String, isExpanded: Binding<Bool>, animated: Bool = true) {
        self.address = address
        self.animated = animated
        self.externalIsExpanded = isExpanded
        self._internalIsExpanded = State(initialValue: isExpanded.wrappedValue)
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
                    .foregroundStyle(.primary)
                    .fontWeight(.regular)
                    .lineLimit(1)
                    .fixedSize()
            }
            
            if chunks.count > 4 {
                Text("...")
                    .foregroundStyle(.primary)
                    .fontWeight(.regular)
            }
            
            ForEach(max(2, chunks.count - 2)..<chunks.count, id: \.self) { index in
                Text(chunks[index])
                    .foregroundStyle(.primary)
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
        formattedAddress()
            .font(.system(size: fontSize, design: .monospaced))
            .animation(animated ? .easeInOut(duration: 0.3) : nil, value: fontSize)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onTapGesture {
                if animated {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                } else {
                    isExpanded.toggle()
                }
            }
    }
}

#Preview("Internal State") {
    VStack(spacing: 20) {
        ExpandableAddressView(
            address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
        )
        
        ExpandableAddressView(
            address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        )
    }
    .padding()
}

#Preview("External State") {
    struct PreviewWrapper: View {
        @State private var isExpanded = false
        
        var body: some View {
            VStack(spacing: 20) {
                ExpandableAddressView(
                    address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
                    isExpanded: $isExpanded
                )
                
                Button(isExpanded ? "Collapse" : "Expand") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}
