//
//  SecuritySettingsView.swift
//  Arké
//
//  Created by Christoph on 12/4/25.
//

import SwiftUI
import ArkeUI

struct SecuritySettingsView: View {
    @Environment(\.deviceRegistrationService) private var deviceService
    @State private var showingUnlinkAllConfirmation = false
    @State private var deviceToUnlink: DeviceRegistration?
    @State private var showingUnlinkConfirmation = false
    @State private var isUnlinking = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    // Recovery Phrase
                    RecoveryPhraseSettingView()
                    
                    Divider()
                    
                    // Linked Devices
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Linked Devices")
                            .font(.system(size: 24, design: .serif))
                        
                        Text("Manage devices that have access to your wallet")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        // Current device
                        if let currentDevice = currentDevice {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("This Device")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                DeviceCard(device: currentDevice, isCurrent: true)
                            }
                            .padding(.top, 8)
                        }
                        
                        // Other devices
                        if !otherDevices.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Other Devices (\(otherDevices.count))")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                ForEach(otherDevices) { device in
                                    DeviceCard(
                                        device: device,
                                        isCurrent: false,
                                        onUnlink: {
                                            deviceToUnlink = device
                                            showingUnlinkConfirmation = true
                                        }
                                    )
                                }
                            }
                            .padding(.top, 8)
                        }
                        
                        // Danger zone
                        if !otherDevices.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Danger Zone")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.Arke.red)
                                    .textCase(.uppercase)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Use this if you've lost a device or want to revoke access from all other devices. This cannot be undone.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Button {
                                        showingUnlinkAllConfirmation = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                            Text("Unlink All Other Devices")
                                        }
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.Arke.red)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isUnlinking)
                                }
                                .padding(16)
                                .background(Color.Arke.red.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.Arke.red.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .padding(.top, 8)
                        }
                        
                        // Error message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.Arke.red)
                                .font(.system(size: 13))
                                .padding(12)
                                .background(Color.Arke.red.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .task {
            await deviceService.loadRegisteredDevices()
        }
        .alert("Unlink Device", isPresented: $showingUnlinkConfirmation, presenting: deviceToUnlink) { device in
            Button("Cancel", role: .cancel) { }
            Button("Unlink", role: .destructive) {
                Task {
                    await unlinkDevice(device)
                }
            }
        } message: { device in
            Text("Are you sure you want to unlink \(device.deviceName)? It will need to re-import the recovery phrase to regain access.")
        }
        .alert("Unlink All Other Devices", isPresented: $showingUnlinkAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unlink All (\(otherDevices.count) devices)", role: .destructive) {
                Task {
                    await unlinkAllOtherDevices()
                }
            }
        } message: {
            Text("All other devices will lose access to the wallet. They will need to re-import the recovery phrase to regain access. This action cannot be undone.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentDevice: DeviceRegistration? {
        deviceService.registeredDevices.first { device in
            do {
                let currentDeviceId = try deviceService.getOrCreateDeviceId()
                return device.deviceId == currentDeviceId
            } catch {
                return false
            }
        }
    }
    
    private var otherDevices: [DeviceRegistration] {
        deviceService.registeredDevices.filter { device in
            do {
                let currentDeviceId = try deviceService.getOrCreateDeviceId()
                return device.deviceId != currentDeviceId && device.isActive
            } catch {
                return false
            }
        }.sorted { $0.lastSeenAt > $1.lastSeenAt }
    }
    
    // MARK: - Actions
    
    private func unlinkDevice(_ device: DeviceRegistration) async {
        isUnlinking = true
        errorMessage = nil
        
        do {
            try await deviceService.unlinkDevice(device.deviceId)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to unlink device: \(error.localizedDescription)"
            }
        }
        
        isUnlinking = false
    }
    
    private func unlinkAllOtherDevices() async {
        isUnlinking = true
        errorMessage = nil
        
        do {
            try await deviceService.unlinkAllOtherDevices()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to unlink devices: \(error.localizedDescription)"
            }
        }
        
        isUnlinking = false
    }
}
