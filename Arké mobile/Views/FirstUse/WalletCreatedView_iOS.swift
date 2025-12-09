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
        VStack(spacing: 24) {
            // Success icon and title
            VStack(spacing: 20) {
                // Success checkmark
                ZStack {
                    Circle()
                        .fill(Color.arkeGold.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.arkeGold)
                }
                
                VStack(spacing: 8) {
                    Text("You are ready for bitcoin!")
                        .font(.system(size: 34, design: .serif))
                        .foregroundStyle(Color.arkeGold)
                        .multilineTextAlignment(.center)
                    
                    Text("Your new wallet has been successfully created and is ready to use.")
                        .font(.system(size: 18))
                        .lineSpacing(5)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                    
                    Text("Once you have some funds in it, make sure to do a proper backup. You're in control of this wallet, and also responsible for it.")
                        .font(.system(size: 18))
                        .lineSpacing(5)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            
            Spacer()
            
            Button {
                onContinue()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                    Text("Let's go!")
                }
            }
            .buttonStyle(ArkeButtonStyle(size: .large))
        }
        .background(Color.arkeDark)
        .safeAreaPadding([.top, .bottom])
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

#Preview {
    WalletCreatedView_iOS(
        onContinue: {},
        onShowRecoveryPhrase: {}
    )
}
