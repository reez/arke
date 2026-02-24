//
//  SettingsView_iOS.swift
//  Arké
//
//  Created by Christoph on 11/27/25.
//

import SwiftUI

struct SettingsView_iOS: View {
    let onWalletDeleted: (() -> Void)?
    @Environment(WalletManager.self) private var manager
    @Environment(\.deviceRegistrationService) private var deviceService
    
    @AppStorage(BitcoinAmountFormat.userDefaultsKey)
    private var bitcoinFormat: String = BitcoinAmountFormat.defaultFormat.rawValue
    
    @AppStorage(UserDefaults.balancePrivacyKey)
    private var balancePrivacyEnabled: Bool = false
    
    @State private var navPath = NavigationPath()
    
    private var selectedFormat: BitcoinAmountFormat {
        BitcoinAmountFormat(rawValue: bitcoinFormat) ?? .defaultFormat
    }
    
    var body: some View {
        List {
            // Display Section
            Section {
                // Fee Summary
                NavigationLink(destination: FeeSummaryView_iOS()) {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.green)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fee Summary")
                                .font(.system(size: 16))
                            Text("View transaction fees")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                NavigationLink(destination: DisplaySettingsView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "textformat.size")
                            .foregroundColor(.indigo)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unit format")
                                .font(.system(size: 16))
                            Text("Currently: \(selectedFormat.displayName)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Balance Privacy Toggle
                Toggle(isOn: $balancePrivacyEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: balancePrivacyEnabled ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hide Big Balance")
                                .font(.system(size: 16))
                            Text("Long-press balance card to reveal")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Security Section
            Section {
                // Recovery Phrase
                NavigationLink(destination: RecoveryPhraseView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recovery Phrase")
                                .font(.system(size: 16))
                            Text("View your wallet backup")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Linked Devices
                /*
                NavigationLink(destination: LinkedDevicesView_iOS()) {
                    HStack(spacing: 12) {
                        Image(systemName: "laptopcomputer.and.iphone")
                            .foregroundColor(.purple)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Linked Devices")
                                .font(.system(size: 16))
                            Text("\(deviceCount) \(deviceCount == 1 ? "device" : "devices") connected")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                */
            } header: {
                Text("Security")
            }
            
            // Danger Zone Section
            Section {
                // Exit
                NavigationLink(destination: ExitView_iOS()) {
                    HStack(spacing: 12) {
                        Image(systemName: "light.beacon.max.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Force move to savings")
                                .font(.system(size: 16))
                            Text(manager.hasActiveUnilateralExits ? "In progress" : "Transfer your bitcoin independently")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .disabled(manager.hasActiveUnilateralExits)
                .opacity(manager.hasActiveUnilateralExits ? 0.5 : 1.0)
                
                // Delete Wallet
                NavigationLink(destination: DeleteWalletView(onWalletDeleted: onWalletDeleted)) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Wallet")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            Text("Permanently remove your wallet")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Danger Zone")
            }
            
            // Help & Learning Section
            Section {
                // Intro Video
                NavigationLink(destination: IntroVideoSettingsView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Intro Video")
                                .font(.system(size: 16))
                            Text("Learn how everything works")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Help & Learning")
            }
            
            // Behind the Curtain Section
            Section {
                // Address History
                NavigationLink(destination: AddressHistoryView_iOS()) {
                    HStack(spacing: 12) {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Address History")
                                .font(.system(size: 16))
                            Text("View generated addresses")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // X-Ray
                NavigationLink(value: ActivityDestination.data) {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile.fill")
                            .foregroundColor(.teal)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("X-Ray")
                                .font(.system(size: 16))
                            Text("Your wallet data, raw")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                /*
                // Console
                NavigationLink(destination: ConsoleView_iOS()) {
                    HStack(spacing: 12) {
                        Image(systemName: "arcade.stick.console.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Console")
                                .font(.system(size: 16))
                            Text("Debug logs and diagnostics")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                */
            } header: {
                Text("Behind the curtain")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await deviceService.loadRegisteredDevices()
        }
    }
    
    private var deviceCount: Int {
        deviceService.registeredDevices.filter { $0.isActive && !$0.isStale }.count
    }
}

// MARK: - Supporting Views

struct RecoveryPhraseView: View {
    var body: some View {
        RecoveryPhraseSettingView()
            .padding()
            //.navigationTitle("Recovery Phrase")
            //.navigationBarTitleDisplayMode(.inline)
    }
}

struct DeleteWalletView: View {
    let onWalletDeleted: (() -> Void)?
    
    var body: some View {
        DeleteWalletSettingView(onWalletDeleted: onWalletDeleted)
    }
}

struct DisplaySettingsView: View {
    var body: some View {
        BitcoinFormatSettingView_iOS()
            .padding()
    }
}
struct IntroVideoSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        IntroVideoView_iOS(
            onBack: { dismiss() },
            onContinue: nil,
            onSkip: nil
        )
        .navigationBarHidden(true)
    }
}

