//
//  ContactImportSheet.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/11/25.
//

import SwiftUI
import Contacts

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Sheet for importing contacts from macOS native Contacts
struct ContactImportSheet: View {
    
    // MARK: - Properties
    
    /// Callback when contact is selected
    let onSelect: (ImportedContactData) -> Void
    
    /// Callback when cancelled
    let onCancel: () -> Void
    
    /// Native contact service
    @State private var nativeContactService = NativeContactService()
    
    // MARK: - State
    
    @State private var searchText: String = ""
    @State private var searchResults: [ContactSearchResult] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var permissionState: PermissionState = .notDetermined
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Permission content or contact list
                if permissionState == .denied {
                    permissionDeniedView
                } else if permissionState == .authorized {
                    contactListView
                } else {
                    // notDetermined or requesting
                    requestingPermissionView
                }
            }
            .navigationTitle("Import Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .task {
                await checkPermissionAndLoad()
            }
        }
        .frame(width: 500, height: 600)
    }
    
    // MARK: - Contact List View
    
    @ViewBuilder
    private var contactListView: some View {
        VStack(spacing: 0) {
            // Search field
            searchField
                .padding()
            
            Divider()
            
            // Results list
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else if searchResults.isEmpty {
                emptyStateView
            } else {
                contactResultsList
            }
        }
    }
    
    @ViewBuilder
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search contacts", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .onChange(of: searchText) { _, newValue in
                    Task {
                        await performSearch(query: newValue)
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
        )
    }
    
    @ViewBuilder
    private var contactResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults) { contact in
                    ContactImportRow(
                        contact: contact,
                        onSelect: {
                            selectContact(contact)
                        }
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    if contact.id != searchResults.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Loading & Empty States
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching contacts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No contacts found")
                .font(.headline)
            
            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Start typing to search your contacts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await performSearch(query: searchText)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Permission Views
    
    @ViewBuilder
    private var requestingPermissionView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Requesting access to Contacts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("Contacts Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This app needs permission to access your Contacts to import contact information.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Button("Open System Settings") {
                openSystemSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("After granting permission, please try again.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func checkPermissionAndLoad() async {
        let status = nativeContactService.authorizationStatus()
        
        switch status {
        case .notDetermined:
            permissionState = .requesting
            let granted = await nativeContactService.requestAccess()
            permissionState = granted ? .authorized : .denied
            
            if granted {
                await loadInitialContacts()
            }
            
        case .authorized:
            permissionState = .authorized
            await loadInitialContacts()
            
        case .denied, .restricted:
            permissionState = .denied
            
        case .limited:
            permissionState = .limited
        @unknown default:
            permissionState = .denied
        }
    }
    
    private func loadInitialContacts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load a reasonable initial set (search with empty query gets all)
            let results = try await nativeContactService.fetchAllContacts()
            searchResults = Array(results.prefix(100)) // Limit to first 100
            isLoading = false
        } catch {
            errorMessage = "Failed to load contacts: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func performSearch(query: String) async {
        guard permissionState == .authorized else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Add small debounce
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        do {
            let results = try await nativeContactService.searchContacts(query: query)
            searchResults = results
            isLoading = false
        } catch {
            errorMessage = "Failed to search contacts: \(error.localizedDescription)"
            searchResults = []
            isLoading = false
        }
    }
    
    private func selectContact(_ contact: ContactSearchResult) {
        let importedData = ImportedContactData(
            identifier: contact.id,
            fullName: contact.fullName,
            imageData: contact.imageData
        )
        onSelect(importedData)
    }
    
    private func openSystemSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
            NSWorkspace.shared.open(url)
        }
        #elseif os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - Contact Import Row

struct ContactImportRow: View {
    let contact: ContactSearchResult
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar - using ContactAvatarView with initials fallback
            ContactAvatarView(
                avatarData: contact.imageData,
                size: 40,
                fallbackText: contact.displayName
            )
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // Select button
            Button("Select") {
                onSelect()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Permission State

private enum PermissionState: Equatable {
    case notDetermined
    case requesting
    case authorized
    case denied
    case limited
}

// MARK: - Preview

#Preview("With Permission") {
    ContactImportSheet(
        onSelect: { data in
            print("Selected: \(data.fullName)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}

#Preview("Permission Denied") {
    struct PreviewWrapper: View {
        @State private var permissionState: PermissionState = .denied
        
        var body: some View {
            ContactImportSheet(
                onSelect: { _ in },
                onCancel: { }
            )
        }
    }
    
    return PreviewWrapper()
}
