//
//  LinkedDevicesView_iOS.swift
//  Arké
//
//  Created by Christoph on 12/04/25.
//

import SwiftUI
import ArkeUI

struct LinkedDevicesView_iOS: View {
    @Environment(\.deviceRegistrationService) private var deviceService
    @Environment(\.dismiss) private var dismiss
    @State private var showingUnlinkAllConfirmation = false
    @State private var deviceToUnlink: DeviceRegistration?
    @State private var showingUnlinkConfirmation = false
    @State private var isUnlinking = false
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            // Current device section
            if let currentDevice = currentDevice {
                Section {
                    DeviceRow_iOS(device: currentDevice, isCurrent: true)
                } header: {
                    Text("settings_this_device")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
            }
            
            // Other devices section
            if !otherDevices.isEmpty {
                Section {
                    ForEach(otherDevices) { device in
                        DeviceRow_iOS(device: device, isCurrent: false)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deviceToUnlink = device
                                    showingUnlinkConfirmation = true
                                } label: {
                                    Label("button_unlink", systemImage: "link.slash")
                                }
                            }
                    }
                } header: {
                    Text("Other Devices (\(otherDevices.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
            }
            
            // Danger zone section
            if !otherDevices.isEmpty {
                Section {
                    Button(role: .destructive) {
                        showingUnlinkAllConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("button_unlink_all_others")
                        }
                        .font(.system(size: 16, weight: .medium))
                    }
                    .disabled(isUnlinking)
                } header: {
                    Text("settings_danger_zone")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.Arke.red)
                        .textCase(.uppercase)
                } footer: {
                    Text("Use this if you've lost a device or want to revoke access from all other devices. This cannot be undone.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.Arke.red)
                        .font(.system(size: 14))
                }
            }
        }
        .navigationTitle("settings_linked_devices")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await deviceService.loadRegisteredDevices()
        }
        .refreshable {
            await deviceService.loadRegisteredDevices()
        }
        .confirmationDialog("settings_unlink_device",
            isPresented: $showingUnlinkConfirmation,
            presenting: deviceToUnlink
        ) { (device: DeviceRegistration) in
            Button("Unlink \(device.deviceName)", role: .destructive) {
                Task {
                    await unlinkDevice(device)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { (device: DeviceRegistration) in
            Text("This device will no longer have access to the wallet. It will need to re-import the recovery phrase to regain access.")
        }
        .confirmationDialog("button_unlink_all_others",
            isPresented: $showingUnlinkAllConfirmation
        ) {
            Button("Unlink All (\(otherDevices.count) devices)", role: .destructive) {
                Task {
                    await unlinkAllOtherDevices()
                }
            }
            Button("Cancel", role: .cancel) { }
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
            
            // Provide haptic feedback
            await MainActor.run {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to unlink device: \(error.localizedDescription)"
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
        
        isUnlinking = false
    }
    
    private func unlinkAllOtherDevices() async {
        isUnlinking = true
        errorMessage = nil
        
        do {
            try await deviceService.unlinkAllOtherDevices()
            
            // Provide haptic feedback
            await MainActor.run {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to unlink devices: \(error.localizedDescription)"
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
        
        isUnlinking = false
    }
}

// MARK: - Device Row

struct DeviceRow_iOS: View {
    let device: DeviceRegistration
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Platform icon
            Text(device.platformIcon)
                .font(.system(size: 32))
            
            VStack(alignment: .leading, spacing: 4) {
                // Device name
                HStack {
                    Text(device.deviceName)
                        .font(.system(size: 16, weight: .medium))
                    
                    if isCurrent {
                        Text("(This Device)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Platform and status
                HStack(spacing: 8) {
                    Text(device.platformDisplayName)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("symbol_bullet")
                        .foregroundColor(.secondary)
                    
                    Text(device.lastSeenRelative)
                        .font(.system(size: 14))
                        .foregroundColor(device.isStale ? .Arke.red : .secondary)
                }
                
                // Status badges
                HStack(spacing: 6) {
                    if device.hasSeed {
                        StatusBadge_iOS(text: "Full Wallet", color: .Arke.green)
                    } else {
                        StatusBadge_iOS(text: "Metadata Only", color: .Arke.orange)
                    }
                    
                    if device.isStale {
                        StatusBadge_iOS(text: "Stale", color: .Arke.red)
                    }
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge_iOS: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

#Preview {
    NavigationStack {
        LinkedDevicesView_iOS()
            .environment(\.deviceRegistrationService, ServiceContainer.shared.deviceRegistrationService)
    }
}
