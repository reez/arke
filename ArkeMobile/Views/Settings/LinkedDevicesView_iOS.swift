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
    @State private var deviceToUnlink: DeviceRegistration?
    @State private var showingUnlinkConfirmation = false
    @State private var isUnlinking = false
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            Text(otherDevices.isEmpty ? "You're using Arké on one device. Install Arké on another iPhone or iPad signed in to the same iCloud, and it'll appear here automatically. View-only at first, ready to take over if you need it." : "Only your primary device can spend. Secondary devices can view balance and history.")
                .font(.title3)
                .foregroundColor(.secondary)
                .lineSpacing(6)
                .padding(.vertical, 15)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            
            Section {
                // Current device section
                if let currentDevice = currentDevice {
                    DeviceRow_iOS(
                        device: currentDevice,
                        isCurrent: true,
                        onRemove: { deviceToUnlink = currentDevice; showingUnlinkConfirmation = true },
                        onMakeSecondary: { makeDeviceSecondary(currentDevice) },
                        onMakePrimary: { makeDevicePrimary(currentDevice) }
                    )
                }
            
                // Other devices section
                if !otherDevices.isEmpty {
                    ForEach(otherDevices) { device in
                        DeviceRow_iOS(
                            device: device,
                            isCurrent: false,
                            onRemove: { deviceToUnlink = device; showingUnlinkConfirmation = true },
                            onMakeSecondary: { makeDeviceSecondary(device) },
                            onMakePrimary: { makeDevicePrimary(device) }
                        )
                    }
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
        .listSectionSpacing(8)
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
    
    private func makeDeviceSecondary(_ device: DeviceRegistration) {
        // TODO: Implement making device secondary
        print("Making device secondary: \(device.deviceName)")
    }
    
    private func makeDevicePrimary(_ device: DeviceRegistration) {
        // TODO: Implement making device primary
        print("Making device primary: \(device.deviceName)")
    }
}

// MARK: - Device Row

struct DeviceRow_iOS: View {
    let device: DeviceRegistration
    let isCurrent: Bool
    let onRemove: () -> Void
    let onMakeSecondary: () -> Void
    let onMakePrimary: () -> Void
    
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
                HStack(spacing: 4) {
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
                    if device.isPrimaryDevice {
                        StatusBadge_iOS(text: NSLocalizedString("status_full_wallet", comment: ""), color: .Arke.blue)
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
            
            // Menu button
            Menu {
                if device.isPrimaryDevice {
                    Button {
                        onMakeSecondary()
                    } label: {
                        Label("Make Secondary", systemImage: "arrow.down.circle")
                    }
                } else {
                    Button {
                        onMakePrimary()
                    } label: {
                        Label("Make Primary", systemImage: "arrow.up.circle")
                    }
                }
                
                if !isCurrent {
                    Divider()
                    
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .contentShape(Rectangle())
            }
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
