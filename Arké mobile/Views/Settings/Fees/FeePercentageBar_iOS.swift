//
//  FeePercentageBar_iOS.swift
//  Arké
//
//  Created by Christoph on 1/11/26.
//

import SwiftUI

/// Visual percentage bar
struct FeePercentageBar_iOS: View {
    let percentage: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .cornerRadius(3)
                
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * (percentage / 100.0))
                    .cornerRadius(3)
            }
        }
    }
}
