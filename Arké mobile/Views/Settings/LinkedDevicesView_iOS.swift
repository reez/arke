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
                    Text("settings_other_devices")
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
                    Text("settings_danger_zone_note")
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
            Button(String(format: NSLocalizedString("button_unlink_device_name", comment: ""), device.deviceName), role: .destructive) {
                Task {
                    await unlinkDevice(device)
                }
            }
            Button("button_cancel", role: .cancel) { }
        } message: { (device: DeviceRegistration) in
            Text("alert_device_lose_access")
        }
        .confirmationDialog("button_unlink_all_others",
            isPresented: $showingUnlinkAllConfirmation
        ) {
            Button(String(format: NSLocalizedString("button_unlink_all_count", comment: ""), otherDevices.count), role: .destructive) {
                Task {
                    await unlinkAllOtherDevices()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("alert_all_devices_lose_access")
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
                errorMessage = String(format: NSLocalizedString("error_unlink_device", comment: ""), error.localizedDescription)
                
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
                errorMessage = String(format: NSLocalizedString("error_unlink_devices", comment: ""), error.localizedDescription)
                
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
                        Text("settings_this_device_parentheses")
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
                        StatusBadge_iOS(text: NSLocalizedString("status_full_wallet", comment: ""), color: .Arke.green)
                    } else {
                        StatusBadge_iOS(text: NSLocalizedString("status_metadata_only", comment: ""), color: .Arke.orange)
                    }
                    
                    if device.isStale {
                        StatusBadge_iOS(text: NSLocalizedString("status_stale", comment: ""), color: .Arke.red)
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
