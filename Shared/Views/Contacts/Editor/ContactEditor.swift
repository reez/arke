//
//  ContactEditor.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/04/25.
//

import SwiftUI

// MARK: - Contact Editor

struct ContactEditor: View {
    
    // MARK: - Properties
    
    /// The contact being edited (nil for new contact)
    let editingContact: ContactModel?
    
    /// Callback when contact is saved
    let onSave: (ContactModel) -> Void
    
    /// Callback when editing is cancelled
    let onCancel: () -> Void
    
    /// Callback when contact is deleted
    let onDelete: ((ContactModel) -> Void)?
    
    /// Contact service for validation and operations
    @Environment(\.contactService) private var contactService
    
    // MARK: - Form State
    
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var avatarData: Data? = nil
    
    // Native contact import state
    @State private var importedNativeID: String? = nil
    @State private var importedNativeSyncDate: Date? = nil
    
    // MARK: - UI State
    
    @State private var showingAvatarPicker: Bool = false
    @State private var showingContactImport: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation: Bool = false
    
    // MARK: - Validation
    
    private var allContacts: [ContactModel] {
        contactService.contacts
    }
    
    private var validation: ContactValidation {
        ContactValidation(
            name: name,
            notes: notes.isEmpty ? nil : notes,
            existingContacts: allContacts,
            editingContactId: editingContact?.id
        )
    }
    
    private var canSave: Bool {
        validation.isValid && !isLoading
    }
    
    private var isEditing: Bool {
        editingContact != nil
    }
    
    // MARK: - Initialization
    
    init(editingContact: ContactModel? = nil, onSave: @escaping (ContactModel) -> Void, onCancel: @escaping () -> Void, onDelete: ((ContactModel) -> Void)? = nil) {
        print("👤 ContactEditor: Initializing with editingContact: \(editingContact?.displayName ?? "nil") (ID: \(editingContact?.id.uuidString ?? "nil"))")
        self.editingContact = editingContact
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Import from Contacts section (only for new contacts)
                    /*
                    if !isEditing {
                        importFromContactsSection
                    }
                     */
                    
                    // Preview Section
                    // contactPreviewSection
                    
                    // Form Section
                    ContactFormFields(
                        name: $name,
                        notes: $notes,
                        avatarData: $avatarData,
                        showingAvatarPicker: $showingAvatarPicker,
                        nameError: validation.nameError,
                        notesError: validation.notesError,
                        onSubmit: saveContact
                    )
                    
                    // Error Section
                    if let errorMessage = errorMessage {
                        errorSection(errorMessage)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                }
                
                if !isEditing {
                    ToolbarItem(placement: .automatic) {
                        importButton
                    }
                }
                
                if isEditing, onDelete != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        deleteButton
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
            }
            .confirmationDialog(
                "Delete Contact",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteContact()
                }
                Button(role: .cancel) {
                    
                } label: {
                    Image(systemName: "xmark")
                }
            } message: {
                Text("Are you sure you want to delete \(editingContact?.displayName ?? "this contact")? This action cannot be undone.")
            }
        }
        .onAppear {
            print("👤 ContactEditor: onAppear called")
            setupInitialValues()
        }
        .disabled(isLoading)
        .overlay {
            if isLoading {
                loadingOverlay
            }
        }
        .sheet(isPresented: $showingAvatarPicker) {
            AvatarPickerSheet(selectedAvatarData: $avatarData)
        }
        .sheet(isPresented: $showingContactImport) {
            ContactImportSheet(
                onSelect: { importedData in
                    handleContactImport(importedData)
                    showingContactImport = false
                },
                onCancel: {
                    showingContactImport = false
                }
            )
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var importFromContactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("Import from Contacts")
                    .font(.headline)
                
                Spacer()
            }
            
            Button(action: {
                showingContactImport = true
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                    
                    Text("Search your contacts...")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
            Text("or create manually below")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var contactPreviewSection: some View {
        ContactPreviewCard(contact: previewContact, isEmpty: name.isEmpty)
    }
    
    @ViewBuilder
    private var importButton: some View {
        Button("Import") {
            showingContactImport = true
        }
    }
    
    @ViewBuilder
    private var cancelButton: some View {
        Button("Cancel") {
            onCancel()
        }
    }
    
    @ViewBuilder
    private var saveButton: some View {
        //let buttonTitle = isEditing ? "Save" : "Create"
        Button {
            saveContact()
        } label: {
            Image(systemName: "checkmark.fill")
        }
        .disabled(!canSave)
        .fontWeight(.semibold)
    }
    
    @ViewBuilder
    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        Color.black.opacity(0.1)
            .ignoresSafeArea()
            .overlay {
                ProgressView()
                    .scaleEffect(1.2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .frame(width: 80, height: 80)
                    )
            }
    }
    
    @ViewBuilder
    private func errorSection(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundColor(.red)
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Computed Properties
    
    private var navigationTitle: String {
        isEditing ? "Edit Contact" : "New Contact"
    }
    
    private var previewContact: ContactModel {
        let displayName = name.isEmpty ? "Sample Contact" : name
        let displayNotes = notes.isEmpty ? nil : notes
        
        return ContactModel(
            cachedName: displayName,
            notes: displayNotes,
            avatarData: avatarData
        )
    }
    
    // MARK: - Actions
    
    private func setupInitialValues() {
        print("👤 ContactEditor: setupInitialValues called with editingContact: \(editingContact?.displayName ?? "nil") (ID: \(editingContact?.id.uuidString ?? "nil"))")
        
        if let contact = editingContact {
            name = contact.cachedName
            notes = contact.notes ?? ""
            avatarData = contact.avatarData
            importedNativeID = contact.nativeContactID
            importedNativeSyncDate = contact.lastSyncedFromNative
            print("👤 ContactEditor: Set form values - name: '\(name)', notes: '\(notes.prefix(50))...', hasAvatar: \(avatarData != nil)")
        } else {
            // Set up defaults for new contact
            name = ""
            notes = ""
            avatarData = nil
            importedNativeID = nil
            importedNativeSyncDate = nil
            print("👤 ContactEditor: Set default values - name: '\(name)', notes: '\(notes)', hasAvatar: \(avatarData != nil)")
        }
        
        errorMessage = nil
    }
    
    private func handleContactImport(_ importedData: ImportedContactData) {
        print("👤 ContactEditor: Importing contact - name: \(importedData.fullName), hasAvatar: \(importedData.imageData != nil)")
        
        // Populate form fields with imported data
        name = importedData.fullName
        avatarData = importedData.imageData
        importedNativeID = importedData.identifier
        importedNativeSyncDate = Date()
        
        // Clear any previous error
        errorMessage = nil
    }
    
    private func saveContact() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard canSave else { return }
        
        isLoading = true
        errorMessage = nil
        
        let contactToSave: ContactModel
        if let existingContact = editingContact {
            // Update existing contact (preserve native contact link)
            contactToSave = ContactModel(
                id: existingContact.id,
                cachedName: trimmedName,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                avatarData: avatarData,
                createdAt: existingContact.createdAt,
                updatedAt: Date(),
                nativeContactID: existingContact.nativeContactID,
                lastSyncedFromNative: existingContact.lastSyncedFromNative
            )
        } else {
            // Create new contact (include native contact link if imported)
            contactToSave = ContactModel(
                cachedName: trimmedName,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                avatarData: avatarData,
                createdAt: Date(),
                updatedAt: Date(),
                nativeContactID: importedNativeID,
                lastSyncedFromNative: importedNativeSyncDate
            )
        }
        
        // Simulate async operation
        Task {
            do {
                // Add small delay for better UX
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                
                await MainActor.run {
                    isLoading = false
                    onSave(contactToSave)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save contact: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteContact() {
        guard let contact = editingContact, let onDelete = onDelete else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Simulate async operation for better UX
        Task {
            do {
                // Add small delay for visual feedback
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                await MainActor.run {
                    isLoading = false
                    onDelete(contact)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to delete contact: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Presentation Modifiers

extension View {
    /// Present ContactEditor as a sheet
    func contactEditorSheet(
        isPresented: Binding<Bool>,
        editingContact: ContactModel? = nil,
        contactService: ContactService,
        onSave: @escaping (ContactModel) async -> Void,
        onDelete: ((ContactModel) async -> Void)? = nil
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            ContactEditor(
                editingContact: editingContact,
                onSave: { contact in
                    Task {
                        await onSave(contact)
                    }
                    isPresented.wrappedValue = false
                },
                onCancel: {
                    isPresented.wrappedValue = false
                },
                onDelete: onDelete.map { deleteHandler in
                    { contact in
                        Task {
                            await deleteHandler(contact)
                        }
                        isPresented.wrappedValue = false
                    }
                }
            )
            .environment(contactService)
        }
    }
    
    /// Present ContactEditor as a popover (optimal for macOS)
    func contactEditorPopover(
        isPresented: Binding<Bool>,
        editingContact: ContactModel? = nil,
        contactService: ContactService,
        onSave: @escaping (ContactModel) async -> Void,
        onDelete: ((ContactModel) async -> Void)? = nil
    ) -> some View {
        self.popover(isPresented: isPresented, arrowEdge: .top) {
            ContactEditor(
                editingContact: editingContact,
                onSave: { contact in
                    Task {
                        await onSave(contact)
                    }
                    isPresented.wrappedValue = false
                },
                onCancel: {
                    isPresented.wrappedValue = false
                },
                onDelete: onDelete.map { deleteHandler in
                    { contact in
                        Task {
                            await deleteHandler(contact)
                        }
                        isPresented.wrappedValue = false
                    }
                }
            )
            .environment(contactService)
            .frame(width: 500, height: 700)
        }
    }
    
    /// Present ContactEditor as a window (best for macOS)
    func contactEditorWindow(
        isPresented: Binding<Bool>,
        editingContact: ContactModel? = nil,
        contactService: ContactService,
        onSave: @escaping (ContactModel) async -> Void,
        onDelete: ((ContactModel) async -> Void)? = nil
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            ContactEditor(
                editingContact: editingContact,
                onSave: { contact in
                    Task {
                        await onSave(contact)
                    }
                    isPresented.wrappedValue = false
                },
                onCancel: {
                    isPresented.wrappedValue = false
                },
                onDelete: onDelete.map { deleteHandler in
                    { contact in
                        Task {
                            await deleteHandler(contact)
                        }
                        isPresented.wrappedValue = false
                    }
                }
            )
            .environment(contactService)
            .frame(minWidth: 500, maxWidth: 600, minHeight: 700, maxHeight: 800)
        }
    }
}

// MARK: - Preview

#Preview("New Contact") {
    ContactEditor(
        onSave: { contact in
            print("Saved contact: \(contact)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
    .environment(ContactService(taskManager: TaskDeduplicationManager()))
}

#Preview("Edit Contact") {
    ContactEditor(
        editingContact: ContactModel(
            cachedName: "John Doe", 
            notes: "Coffee shop owner downtown. Always has great recommendations for new blends."
        ),
        onSave: { contact in
            print("Updated contact: \(contact)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
    .environment(ContactService(taskManager: TaskDeduplicationManager()))
}
