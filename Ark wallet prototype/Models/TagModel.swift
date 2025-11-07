//
//  TagModel.swift
//  Ark wallet prototype
//
//  Created by Assistant on 10/29/25.
//

import SwiftUI
import SwiftData

struct TagModel: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let colorHex: String
    let emoji: String
    let createdDate: Date
    let isActive: Bool
    
    init(id: UUID = UUID(), name: String, colorHex: String, emoji: String, createdDate: Date = Date(), isActive: Bool = true) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.emoji = emoji
        self.createdDate = createdDate
        self.isActive = isActive
    }
    
    // Initialize from persistent tag
    init(from persistentTag: PersistentTag) {
        self.id = persistentTag.id
        self.name = persistentTag.name
        self.colorHex = persistentTag.colorHex
        self.emoji = persistentTag.emoji
        self.createdDate = persistentTag.createdDate
        self.isActive = persistentTag.isActive
    }
    
    // Computed property for SwiftUI Color
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    // Display name with emoji
    var displayName: String {
        emoji.isEmpty ? name : "\(emoji) \(name)"
    }
    
    // For creating common tags
    static func createDefaultTags() -> [TagModel] {
        return [
            TagModel(name: "Savings", colorHex: "#8B4513", emoji: "💰"),
            TagModel(name: "Food", colorHex: "#FF6B35", emoji: "🍕"),
            TagModel(name: "Transport", colorHex: "#4A90E2", emoji: "🚗"),
            TagModel(name: "Shopping", colorHex: "#7B68EE", emoji: "🛒"),
            TagModel(name: "Bills", colorHex: "#FF4444", emoji: "📄"),
            TagModel(name: "Income", colorHex: "#32CD32", emoji: "💰"),
            TagModel(name: "Investment", colorHex: "#FFD700", emoji: "📈"),
            TagModel(name: "Gift", colorHex: "#FF69B4", emoji: "🎁")
        ]
    }
    
    // Convert to persistent model
    func toPersistentTag() -> PersistentTag {
        return PersistentTag(
            id: self.id,
            name: self.name,
            colorHex: self.colorHex,
            emoji: self.emoji,
            createdDate: self.createdDate,
            isActive: self.isActive
        )
    }
}
