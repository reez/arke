//
//  ContactFormFields.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/04/25.
//

import SwiftUI

struct ContactFormFields: View {
    @Binding var name: String
    @Binding var notes: String
    @Binding var avatarData: Data?
    @Binding var showingAvatarPicker: Bool
    
    let nameError: String?
    let notesError: String?
    let onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Name Field
            nameField
            
            // Avatar Field
            avatarField
            
            // Notes Field
            notesField
        }
        .animation(.easeInOut(duration: 0.2), value: nameError)
        .animation(.easeInOut(duration: 0.2), value: notesError)
    }
    
    // MARK: - Name Field
    
    @ViewBuilder
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Name")
                    .font(.headline)
                
                Spacer()
                
                Text("\(name.count)/50")
                    .font(.caption)
                    .foregroundStyle(name.count > 45 ? .orange : .secondary)
            }
            
            TextField("Enter contact name", text: $name)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onSubmit(onSubmit)
            
            if let nameError = nameError {
                Label(nameError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Avatar Field
    
    @ViewBuilder
    private var avatarField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Avatar (Optional)")
                .font(.headline)
            
            HStack {
                Button(action: {
                    showingAvatarPicker.toggle()
                }) {
                    HStack {
                        // Avatar preview
                        Group {
                            if let avatarData = avatarData,
                               let nsImage = NSImage(data: avatarData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Text(avatarData == nil ? "Choose avatar" : "Change avatar")
                            .foregroundStyle(avatarData == nil ? .secondary : .primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                if avatarData != nil {
                    Button("Clear") {
                        avatarData = nil
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Notes Field
    
    @ViewBuilder
    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes (Optional)")
                    .font(.headline)
                
                Spacer()
                
                Text("\(notes.count)/500")
                    .font(.caption)
                    .foregroundStyle(notes.count > 450 ? .orange : .secondary)
            }
            
            TextEditor(text: $notes)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.textBackgroundColor))
                        )
                )
                .font(.body)
            
            if let notesError = notesError {
                Label(notesError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("Add any additional information about this contact")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContactFormFields(
        name: .constant("John Doe"),
        notes: .constant("Coffee shop owner downtown. Always has great recommendations for new blends."),
        avatarData: .constant(nil),
        showingAvatarPicker: .constant(false),
        nameError: nil,
        notesError: nil,
        onSubmit: { print("Submit") }
    )
    .padding()
    .frame(width: 400)
}