//
//  WalletCreatedView_iOS.swift
//  Arké
//
//  Created by Christoph on 12/09/25.
//

import SwiftUI

struct WalletCreatedView_iOS: View {
    let onContinue: () -> Void
    let onShowRecoveryPhrase: () -> Void
    
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
                        Text("You are ready for bitcoin!")
                            .font(.system(size: 36, design: .serif))
                            .foregroundStyle(Color.arkeGold)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Your new wallet is ready to use.")
                            .font(.system(size: 24))
                            .lineSpacing(4)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        
                        Text("Make sure to make a backup. You're in control of this wallet, and also responsible for it.")
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
    WalletCreatedView_iOS(
        onContinue: {},
        onShowRecoveryPhrase: {}
    )
}
