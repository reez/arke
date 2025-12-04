//
//  DisplaySettingsView.swift
//  Arké
//
//  Created by Christoph on 12/4/25.
//

import SwiftUI

struct DisplaySettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Display")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                BitcoinFormatSettingView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
    }
}
