//
//  WalletLinkedView_iOS.swift
//  Arké
//
//  Created by Christoph on 12/10/25.
//

import SwiftUI

struct WalletLinkedView_iOS: View {
    let onContinue: () -> Void
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // Success icon and title
                VStack(alignment: .leading, spacing: 30) {
                    // Success checkmark
                    ZStack {
                        Circle()
                            .fill(Color.arkeGold.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(Color.arkeGold)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Wallet Connected!")
                            .font(.system(size: 36, design: .serif))
                            .foregroundStyle(Color.arkeGold)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Your wallet is successfully linked with your other devices.")
                            .font(.system(size: 24))
                            .lineSpacing(4)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                Button {
                    onContinue()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 27))
                        .foregroundStyle(Color.arkeDark)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(Color.arkeGold)
                .accessibilityLabel("Next")
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .padding(.top, safeAreaInsets.top)
            .padding(.bottom, safeAreaInsets.bottom)
        }
        .background(Color.arkeDark)
        .ignoresSafeArea()
    }
}

#Preview {
    WalletLinkedView_iOS(
        onContinue: {}
    )
}
