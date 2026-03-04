//
//  SettingsView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import SwiftUI

struct SettingsView: View {
    let onWalletDeleted: (() -> Void)?
    @Environment(\.deviceRegistrationService) private var deviceService
    @State private var selectedSection: SettingsSection = .security
    
    enum SettingsSection: String, CaseIterable, Identifiable {
        case security
        case display
        case dangerZone
        
        var id: String { rawValue.localizedKey }
        
        var rawValue: SettingsRawValue {
            switch self {
            case .security: return SettingsRawValue(localizedKey: "settings_security")
            case .display: return SettingsRawValue(localizedKey: "settings_display")
            case .dangerZone: return SettingsRawValue(localizedKey: "settings_danger_zone")
            }
        }
        
        struct SettingsRawValue {
            let localizedKey: String
        }
        
        var icon: String {
            switch self {
            case .security: return "lock.shield"
            case .display: return "paintbrush"
            case .dangerZone: return "exclamationmark.triangle"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Menu - Segmented Picker Style
            Picker(selection: $selectedSection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(String(localized: String.LocalizationValue(section.rawValue.localizedKey)), systemImage: section.icon)
                        .tag(section)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
                        
            // Content
            Group {
                switch selectedSection {
                case .security:
                    SecuritySettingsView()
                        .frame(maxWidth: 500, maxHeight: .infinity)
                case .display:
                    DisplaySettingsView()
                        .frame(maxWidth: 500, maxHeight: .infinity)
                case .dangerZone:
                    DangerZoneSettingsView(onWalletDeleted: onWalletDeleted)
                        .frame(maxWidth: 500, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("settings_title")
        .task {
            await deviceService.loadRegisteredDevices()
        }
    }
}

#Preview {
    SettingsView(onWalletDeleted: nil)
        .environment(WalletManager(useMock: true))
}
