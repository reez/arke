//
//  NFCReaderView_iOS.swift
//  Arké
//
//  Created by Assistant on 5/29/26.
//

import SwiftUI
import CoreNFC
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.arke", category: "NFCReaderView_iOS")

/// A SwiftUI wrapper for iOS NFC NDEF reading functionality
/// Scans NFC tags for BIP-21 payment URIs
class NFCReaderView_iOS {
    let onScan: (String) -> Void
    let onError: (String) -> Void
    private var delegate: NFCReaderDelegate?
    private var session: NFCNDEFReaderSession?
    
    init(onScan: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onScan = onScan
        self.onError = onError
    }
    
    /// Checks if NFC reading is available on the current device
    static var isAvailable: Bool {
        return NFCNDEFReaderSession.readingAvailable
    }
    
    /// Starts an NFC reading session
    func startScanning() {
        guard NFCNDEFReaderSession.readingAvailable else {
            logger.error("❌ NFC reading not available on this device")
            onError("NFC is not available on this device")
            return
        }
        
        logger.debug("📡 Starting NFC reading session...")
        
        // Create and retain the delegate
        let delegate = NFCReaderDelegate(onScan: onScan, onError: onError)
        self.delegate = delegate
        
        // Create session with the retained delegate
        let session = NFCNDEFReaderSession(
            delegate: delegate,
            queue: nil,
            invalidateAfterFirstRead: true
        )
        self.session = session
        
        session.alertMessage = "Hold your iPhone near an NFC tag"
        session.begin()
    }
}

/// Delegate for handling NFC NDEF reader session events
private class NFCReaderDelegate: NSObject, NFCNDEFReaderSessionDelegate {
    let onScan: (String) -> Void
    let onError: (String) -> Void
    
    init(onScan: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onScan = onScan
        self.onError = onError
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        logger.debug("✅ NFC session became active and ready to scan")
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        let nfcError = error as? NFCReaderError
        
        // Ignore expected "errors" that are actually success states or transient issues
        if nfcError?.code == .readerSessionInvalidationErrorUserCanceled {
            logger.debug("ℹ️ NFC session cancelled by user")
            return
        }
        
        // Error code 200 = "First NDEF tag read" - this is normal when invalidateAfterFirstRead is true
        if nfcError?.code == .readerSessionInvalidationErrorFirstNDEFTagRead {
            logger.debug("✅ NFC session completed successfully (first NDEF tag read)")
            return
        }
        
        // Error code 203 = "System resource unavailable" - happens when NFC is still shutting down from previous session
        if nfcError?.code.rawValue == 203 {
            logger.debug("ℹ️ NFC system resource temporarily unavailable (likely still shutting down)")
            return
        }
        
        // Only report actual errors
        logger.error("❌ NFC session invalidated with error: \(error.localizedDescription)")
        logger.error("   └─ Error code: \(String(describing: nfcError?.code.rawValue))")
        
        DispatchQueue.main.async {
            self.onError("NFC scanning failed: \(error.localizedDescription)")
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        logger.debug("📡 NFC tag detected, processing \(messages.count) NDEF message(s)...")
        
        // Process all messages and records to find a valid URI
        for (messageIndex, message) in messages.enumerated() {
            logger.debug("   └─ Message \(messageIndex): \(message.records.count) record(s)")
            
            for (recordIndex, record) in message.records.enumerated() {
                logger.debug("      └─ Record \(recordIndex):")
                logger.debug("         └─ Type Name Format: \(record.typeNameFormat.rawValue)")
                logger.debug("         └─ Type: \(String(data: record.type, encoding: .utf8) ?? "unknown")")
                logger.debug("         └─ Identifier: \(String(data: record.identifier, encoding: .utf8) ?? "none")")
                logger.debug("         └─ Payload length: \(record.payload.count) bytes")
                
                // Try to extract URI
                if let uri = extractURI(from: record) {
                    logger.debug("✅ Found URI in NFC tag: \(uri)")
                    
                    // Check if it's a Bitcoin or Lightning URI
                    if uri.lowercased().hasPrefix("bitcoin:") || 
                       uri.lowercased().hasPrefix("lightning:") ||
                       uri.lowercased().hasPrefix("lnurl") {
                        
                        session.alertMessage = "Payment information found!"
                        session.invalidate()
                        
                        DispatchQueue.main.async {
                            self.onScan(uri)
                        }
                        return
                    } else {
                        logger.debug("⚠️ URI found but not a payment URI: \(uri)")
                    }
                } else {
                    // Try to decode payload as text for debugging
                    if let payloadText = String(data: record.payload, encoding: .utf8) {
                        logger.debug("         └─ Payload as text: \(payloadText)")
                    } else if let payloadText = String(data: record.payload, encoding: .ascii) {
                        logger.debug("         └─ Payload as ASCII: \(payloadText)")
                    }
                }
            }
        }
        
        // No valid payment URI found
        logger.warning("⚠️ No valid payment URI found on NFC tag")
        session.alertMessage = "No payment information found on tag"
        session.invalidate()
        
        DispatchQueue.main.async {
            self.onError("No payment information found on NFC tag")
        }
    }
    
    /// Extracts a URI string from an NDEF record
    private func extractURI(from record: NFCNDEFPayload) -> String? {
        // Check for URI type (Type Name Format 0x01 = NFC Well Known type)
        if record.typeNameFormat == .nfcWellKnown {
            if let typeString = String(data: record.type, encoding: .utf8) {
                // Handle URI record (type "U")
                if typeString == "U" {
                    // URI record format: first byte is URI identifier code, rest is URI
                    let payload = record.payload
                    guard payload.count > 0 else { return nil }
                    
                    // Get URI identifier code (first byte)
                    let identifierCode = payload[0]
                    let uriData = payload.advanced(by: 1)
                    
                    // Get prefix based on identifier code
                    let prefix = uriPrefix(for: identifierCode)
                    
                    // Get the rest of the URI
                    if let uriSuffix = String(data: uriData, encoding: .utf8) {
                        return prefix + uriSuffix
                    }
                }
                
                // Handle Text record (type "T")
                if typeString == "T" {
                    let payload = record.payload
                    guard payload.count > 0 else { return nil }
                    
                    // First byte contains status and language code length
                    let statusByte = payload[0]
                    let languageCodeLength = Int(statusByte & 0x3F)  // Lower 6 bits
                    
                    // Skip the status byte and language code to get the text
                    let textStartIndex = 1 + languageCodeLength
                    guard payload.count > textStartIndex else { return nil }
                    
                    let textData = payload.advanced(by: textStartIndex)
                    if let text = String(data: textData, encoding: .utf8) {
                        logger.debug("         └─ Extracted text from NFC Text record: \(text)")
                        // Text records might contain URIs directly
                        return text
                    }
                }
            }
        }
        
        // Also check for absolute URI type (Type Name Format 0x03)
        if record.typeNameFormat == .absoluteURI {
            if let uri = String(data: record.payload, encoding: .utf8) {
                return uri
            }
        }
        
        return nil
    }
    
    /// Returns the URI prefix for a given identifier code
    /// Based on NFC Forum URI Record Type Definition
    private func uriPrefix(for code: UInt8) -> String {
        switch code {
        case 0x00: return ""
        case 0x01: return "http://www."
        case 0x02: return "https://www."
        case 0x03: return "http://"
        case 0x04: return "https://"
        case 0x05: return "tel:"
        case 0x06: return "mailto:"
        case 0x07: return "ftp://anonymous:anonymous@"
        case 0x08: return "ftp://ftp."
        case 0x09: return "ftps://"
        case 0x0A: return "sftp://"
        case 0x0B: return "smb://"
        case 0x0C: return "nfs://"
        case 0x0D: return "ftp://"
        case 0x0E: return "dav://"
        case 0x0F: return "news:"
        case 0x10: return "telnet://"
        case 0x11: return "imap:"
        case 0x12: return "rtsp://"
        case 0x13: return "urn:"
        case 0x14: return "pop:"
        case 0x15: return "sip:"
        case 0x16: return "sips:"
        case 0x17: return "tftp:"
        case 0x18: return "btspp://"
        case 0x19: return "btl2cap://"
        case 0x1A: return "btgoep://"
        case 0x1B: return "tcpobex://"
        case 0x1C: return "irdaobex://"
        case 0x1D: return "file://"
        case 0x1E: return "urn:epc:id:"
        case 0x1F: return "urn:epc:tag:"
        case 0x20: return "urn:epc:pat:"
        case 0x21: return "urn:epc:raw:"
        case 0x22: return "urn:epc:"
        case 0x23: return "urn:nfc:"
        default: return ""
        }
    }
}
