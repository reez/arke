//
//  BitcoinFormatSettingView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/13/25.
//

import SwiftUI

struct BitcoinFormatSettingView: View {
    @AppStorage(BitcoinAmountFormat.userDefaultsKey)
    private var selectedFormat: BitcoinAmountFormat = .defaultFormat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bitcoin Amount Format")
                .font(.system(size: 24, design: .serif))
            
            Text("Choose how Bitcoin amounts are displayed throughout the app.")
                .font(.body)
                .foregroundColor(.secondary)
            
            Picker("", selection: $selectedFormat) {
                ForEach(BitcoinAmountFormat.allCases, id: \.self) { format in
                    HStack(spacing: 15) {
                        Text(format.exampleFormat)
                            .font(.body)
                        Text("(\(format.displayName))")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(format)
                }
            }
            #if os(macOS)
            .pickerStyle(.radioGroup)
            #else
            .pickerStyle(.inline)
            #endif
            .padding(.top, 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    BitcoinFormatSettingView()
        .padding()
}
