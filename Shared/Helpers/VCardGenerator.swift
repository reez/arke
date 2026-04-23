//
//  VCardGenerator.swift
//  Arké
//
//  Created by Assistant on 4/23/26.
//

import Foundation

/// Helper for generating vCard (.vcf) files with Bitcoin payment information
struct VCardGenerator {
    
    /// Generates a vCard with Bitcoin payment information
    /// - Parameters:
    ///   - name: User's display name
    ///   - bitcoinURI: Bitcoin URI (e.g., bitcoin:address?amount=X)
    ///   - avatarData: Optional image data for profile photo (JPEG/PNG)
    ///   - note: Optional note to include in the vCard
    /// - Returns: vCard data as Data, or nil if generation fails
    static func generateVCard(
        name: String,
        bitcoinURI: String,
        avatarData: Data? = nil,
        note: String? = nil
    ) -> Data? {
        var vcard = "BEGIN:VCARD\n"
        vcard += "VERSION:3.0\n"
        
        // Full name
        vcard += "FN:\(escapeVCardValue(name))\n"
        
        // Bitcoin URI as URL field
        vcard += "URL;type=bitcoin:\(escapeVCardValue(bitcoinURI))\n"
        
        // Optional note
        if let note = note, !note.isEmpty {
            vcard += "NOTE:\(escapeVCardValue(note))\n"
        }
        
        // Optional photo (base64 encoded)
        if let avatarData = avatarData {
            let base64Photo = avatarData.base64EncodedString()
            let photoType = detectImageType(from: avatarData)
            vcard += "PHOTO;ENCODING=BASE64;TYPE=\(photoType):\(base64Photo)\n"
        }
        
        vcard += "END:VCARD\n"
        
        return vcard.data(using: .utf8)
    }
    
    /// Escapes special characters in vCard values
    private static func escapeVCardValue(_ value: String) -> String {
        // vCard escaping rules: backslash, comma, semicolon, newline
        return value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
    
    /// Detects image type from data
    private static func detectImageType(from data: Data) -> String {
        guard data.count > 1 else { return "JPEG" }
        
        // Check PNG signature (89 50 4E 47)
        if data[0] == 0x89 && data[1] == 0x50 {
            return "PNG"
        }
        
        // Check JPEG signature (FF D8)
        if data[0] == 0xFF && data[1] == 0xD8 {
            return "JPEG"
        }
        
        // Default to JPEG
        return "JPEG"
    }
}
