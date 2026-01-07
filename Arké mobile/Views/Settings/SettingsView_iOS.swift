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
    
    @State private var navPath = NavigationPath()
    
    private var selectedFormat: BitcoinAmountFormat {
        get { BitcoinAmountFormat(rawValue: bitcoinFormat) ?? .defaultFormat }
        nonmutating set { bitcoinFormat = newValue.rawValue }
    }
    
    var body: some View {
        List {
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
            } header: {
                Text("Security")
            }
            
            // Display Section
            Section {
                Picker("Bitcoin Amount Format", selection: Binding(
                    get: { selectedFormat },
                    set: { selectedFormat = $0 }
                )) {
                    ForEach(BitcoinAmountFormat.allCases, id: \.self) { format in
                        HStack(spacing: 8) {
                            Text(format.exampleFormat)
                            Text("(\(format.displayName))")
                                .foregroundColor(.secondary)
                        }
                        .tag(format)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("Display")
            } footer: {
                Text("Choose how Bitcoin amounts are displayed throughout the app.")
            }
            
            // Behind the Curtain Section
            Section {
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
            } header: {
                Text("Behind the curtain")
            }
            
            // Danger Zone Section
            Section {
                // Exit
                NavigationLink(destination: ExitView_iOS()) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.forward.square.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exit")
                                .font(.system(size: 16))
                            Text("Manage unilateral exits")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
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
            .navigationTitle("Recovery Phrase")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct DeleteWalletView: View {
    let onWalletDeleted: (() -> Void)?
    
    var body: some View {
        DeleteWalletSettingView(onWalletDeleted: onWalletDeleted)
            .padding()
            .navigationTitle("Delete Wallet")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct BitcoinFormatSettingRow: View {
    var body: some View {
        BitcoinFormatSettingView()
    }
}
