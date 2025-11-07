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
    
    /// Contact service for validation and operations
    @Environment(ContactService.self) private var contactService
    
    // MARK: - Form State
    
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var avatarData: Data? = nil
    
    // MARK: - UI State
    
    @State private var showingAvatarPicker: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
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
    
    init(editingContact: ContactModel? = nil, onSave: @escaping (ContactModel) -> Void, onCancel: @escaping () -> Void) {
        print("👤 ContactEditor: Initializing with editingContact: \(editingContact?.displayName ?? "nil") (ID: \(editingContact?.id.uuidString ?? "nil"))")
        self.editingContact = editingContact
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview Section
                    contactPreviewSection
                    
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
                
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
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
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var contactPreviewSection: some View {
        ContactPreviewCard(contact: previewContact, isEmpty: name.isEmpty)
    }
    
    @ViewBuilder
    private var cancelButton: some View {
        Button("Cancel") {
            onCancel()
        }
    }
    
    @ViewBuilder
    private var saveButton: some View {
        let buttonTitle = isEditing ? "Save" : "Create"
        Button(buttonTitle) {
            saveContact()
        }
        .disabled(!canSave)
        .fontWeight(.semibold)
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
            print("👤 ContactEditor: Set form values - name: '\(name)', notes: '\(notes.prefix(50))...', hasAvatar: \(avatarData != nil)")
        } else {
            // Set up defaults for new contact
            name = ""
            notes = ""
            avatarData = nil
            print("👤 ContactEditor: Set default values - name: '\(name)', notes: '\(notes)', hasAvatar: \(avatarData != nil)")
        }
        
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
            // Update existing contact
            contactToSave = ContactModel(
                id: existingContact.id,
                cachedName: trimmedName,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                avatarData: avatarData,
                createdAt: existingContact.createdAt,
                updatedAt: Date()
            )
        } else {
            // Create new contact
            contactToSave = ContactModel(
                cachedName: trimmedName,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                avatarData: avatarData
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
}

// MARK: - Presentation Modifiers

extension View {
    /// Present ContactEditor as a sheet
    func contactEditorSheet(
        isPresented: Binding<Bool>,
        editingContact: ContactModel? = nil,
        contactService: ContactService,
        onSave: @escaping (ContactModel) async -> Void
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
        onSave: @escaping (ContactModel) async -> Void
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
        onSave: @escaping (ContactModel) async -> Void
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