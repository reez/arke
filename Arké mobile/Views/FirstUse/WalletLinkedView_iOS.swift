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
        VStack(spacing: 24) {
            // Success icon and title
            VStack(spacing: 20) {
                // Success checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.arkeGold)
                
                VStack(spacing: 8) {
                    Text("Wallet Connected!")
                        .font(.system(size: 34, design: .serif))
                        .foregroundStyle(Color.arkeGold)
                        .multilineTextAlignment(.center)
                    
                    Text("Your wallet is successfully linked with your other devices.")
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
        .padding(.top, 60)
        .padding(.bottom, 40)
    }
}

#Preview {
    WalletLinkedView_iOS(
        onContinue: {}
    )
}
