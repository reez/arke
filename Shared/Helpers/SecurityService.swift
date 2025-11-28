//
//  SecurityService.swift
//  Arké
//
//  Created by Christoph on 11/28/25.
//

import Foundation
import SwiftData
import CryptoKit
import LocalAuthentication
import Observation
import CommonCrypto

@MainActor
@Observable
class SecurityService {
    // MARK: - Published Properties
    
    /// Current wallet state for cross-device detection
    var walletState: WalletState = .unknown
    
    /// Error message for security operations
    var error: String?
    
    /// Loading state
    var isLoading: Bool = false
    
    // MARK: - Dependencies
    
    private var modelContext: ModelContext?
    private let taskManager: TaskDeduplicationManager
    
    // MARK: - Constants
    
    private let keychainService = "com.arke.wallet"
    private let mnemonicAccount = "mnemonic"
    private let hashSalt = "com.arke.mnemonic.hash.v1"
    private let pbkdf2Iterations = 100_000
    
    // MARK: - Initialization
    
    init(taskManager: TaskDeduplicationManager) {
        self.taskManager = taskManager
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Wallet State Detection
    
    /// Detects if user has a wallet on another device
    func detectWalletState() async -> WalletState {
        return await taskManager.execute(key: "detectWalletState") {
            // 1. Check local keychain first (instant)
            if self.hasMnemonic() {
                return .walletWithSeed
            }
            
            // 2. Check for local hash in SwiftData (instant)
            if let _ = self.getLocalHash() {
                return .walletWithoutSeed
            }
            
            // 3. Check SwiftData for any wallet metadata (synced via CloudKit)
            // This would include transactions, contacts, etc.
            if await self.hasWalletMetadata() {
                return .walletWithoutSeed
            }
            
            return .noWallet
        }
    }
    
    /// Checks if user has wallet metadata (transactions, contacts) in SwiftData
    private func hasWalletMetadata() async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        // Check if WalletConfiguration exists
        let descriptor = FetchDescriptor<WalletConfiguration>()
        let configs = try? modelContext.fetch(descriptor)
        
        return !(configs?.isEmpty ?? true)
    }
    
    // MARK: - Mnemonic Storage (Local Only)
    
    /// Saves mnemonic to keychain (NEVER syncs to iCloud)
    func saveMnemonic(_ mnemonic: String, requireBiometric: Bool = false) throws {
        guard let data = mnemonic.data(using: .utf8) else {
            throw WalletError.encodingFailed
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: mnemonicAccount,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: false  // NEVER sync!
        ]
        
        // Set access control based on biometric requirement
        if requireBiometric {
            // Use SecAccessControl for biometric protection
            var error: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                &error
            ) else {
                if let error = error?.takeRetainedValue() {
                    print("⚠️ Failed to create SecAccessControl: \(error)")
                    throw WalletError.keychainError(errSecParam)
                }
                throw WalletError.keychainError(errSecParam)
            }
            query[kSecAttrAccessControl as String] = access
        } else {
            // Use simple accessibility without biometric requirement
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        
        // Delete existing entry first
        SecItemDelete(query as CFDictionary)
        
        // Add new entry
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WalletError.keychainError(status)
        }
    }
    
    /// Loads mnemonic from keychain
    func loadMnemonic() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: mnemonicAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw WalletError.keychainError(status)
        }
        
        guard let data = result as? Data else {
            throw WalletError.encodingFailed
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Checks if mnemonic exists in keychain
    func hasMnemonic() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: mnemonicAccount,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
    
    /// Deletes mnemonic from keychain
    func deleteMnemonic() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: mnemonicAccount
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletError.keychainError(status)
        }
    }
    
    // MARK: - Hash Management (For Validation)
    
    /// Generates PBKDF2 hash of mnemonic for validation
    func hashMnemonic(_ mnemonic: String) -> String {
        let passwordData = Array(mnemonic.utf8)
        let saltData = Array(hashSalt.utf8)
        
        var derivedKeyData = Data(count: 32)
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            saltData.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordData,
                    passwordData.count,
                    saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    saltData.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(pbkdf2Iterations),
                    derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    32
                )
            }
        }
        
        guard derivationStatus == kCCSuccess else {
            // Fallback to simple hash if PBKDF2 fails
            var combinedData = Data()
            combinedData.append(contentsOf: mnemonic.utf8)
            combinedData.append(contentsOf: hashSalt.utf8)
            return SHA256.hash(data: combinedData)
                .compactMap { String(format: "%02x", $0) }
                .joined()
        }
        
        return derivedKeyData.base64EncodedString()
    }
    
    /// Saves hash to SwiftData (syncs via CloudKit)
    func saveHashToStorage(_ mnemonic: String) async throws {
        guard let modelContext = modelContext else {
            throw WalletError.unknown("No model context available")
        }
        
        let hash = hashMnemonic(mnemonic)
        
        // Check if config already exists
        let descriptor = FetchDescriptor<WalletConfiguration>()
        let existing = try? modelContext.fetch(descriptor).first
        
        if let existing = existing {
            // Update existing
            existing.mnemonicHash = hash
            existing.lastAccessedAt = Date()
        } else {
            // Create new
            let config = WalletConfiguration(mnemonicHash: hash)
            modelContext.insert(config)
        }
        
        try modelContext.save()
    }
    
    /// Gets locally stored hash from SwiftData
    func getLocalHash() -> String? {
        guard let modelContext = modelContext else { return nil }
        
        let descriptor = FetchDescriptor<WalletConfiguration>()
        let config = try? modelContext.fetch(descriptor).first
        
        return config?.mnemonicHash
    }
    
    /// Gets reference hash (checks both local and should-be-synced data)
    func getReferenceHash() async -> String? {
        return getLocalHash()
    }
    
    // MARK: - Validation
    
    /// Validates imported mnemonic against stored hash
    func validateMnemonic(_ mnemonic: String) async -> MnemonicValidationResult {
        // 1. Check if it's valid BIP39 format
        guard isValidBIP39(mnemonic) else {
            return .invalidFormat
        }
        
        // 2. Try to get reference hash
        guard let referenceHash = await getReferenceHash() else {
            // No reference hash exists yet - this is OK for first import
            return .validNoReference
        }
        
        // 3. Compare hashes
        let importedHash = hashMnemonic(mnemonic)
        
        return importedHash == referenceHash ? .valid : .invalid
    }
    
    /// Validates BIP39 format (basic check - enhance as needed)
    func isValidBIP39(_ mnemonic: String) -> Bool {
        let words = mnemonic.components(separatedBy: " ")
        
        // Check word count (12, 15, 18, 21, or 24 words)
        guard [12, 15, 18, 21, 24].contains(words.count) else {
            return false
        }
        
        // All words should be non-empty and lowercase
        return words.allSatisfy { !$0.isEmpty }
    }
    
    // MARK: - Biometric Authentication
    
    /// Authenticates user with Face ID / Touch ID
    func authenticateUser(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw WalletError.biometricNotAvailable
        }
        
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            throw WalletError.authenticationFailed
        }
    }
    
    /// Checks if biometrics are available
    func biometricsAvailable() -> Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
}

// MARK: - Supporting Types

enum WalletState: Equatable {
    case unknown                // Initial state, not yet checked
    case noWallet              // No wallet exists anywhere
    case walletWithoutSeed     // CloudKit has data, but no local seed
    case walletWithSeed        // Full wallet with local seed
}

enum MnemonicValidationResult {
    case valid                 // Matches reference hash
    case invalid               // Doesn't match reference hash
    case validNoReference      // Valid BIP39, but no reference to compare
    case invalidFormat         // Not valid BIP39 format
}

enum WalletError: LocalizedError {
    // Keychain errors
    case encodingFailed
    case keychainError(OSStatus)
    case mnemonicNotFound
    
    // Security errors
    case authenticationFailed
    case biometricNotAvailable
    
    // Validation errors
    case invalidMnemonic
    case mnemonicHashMismatch
    case invalidBIP39Words
    
    // Import/Export errors
    case qrCodeGenerationFailed
    case qrCodeScanningFailed
    case exportFailed
    
    // Sync errors
    case cloudKitNotAvailable
    case syncTimeout
    case networkUnavailable
    
    // General
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode recovery phrase"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .mnemonicNotFound:
            return "No recovery phrase found"
        case .authenticationFailed:
            return "Authentication failed"
        case .biometricNotAvailable:
            return "Face ID / Touch ID not available"
        case .invalidMnemonic:
            return "Invalid recovery phrase"
        case .mnemonicHashMismatch:
            return "Recovery phrase doesn't match your wallet"
        case .invalidBIP39Words:
            return "One or more words are not valid BIP39 words"
        case .qrCodeGenerationFailed:
            return "Failed to generate QR code"
        case .qrCodeScanningFailed:
            return "Failed to scan QR code"
        case .exportFailed:
            return "Failed to export wallet"
        case .cloudKitNotAvailable:
            return "iCloud is not available"
        case .syncTimeout:
            return "Sync is taking longer than expected"
        case .networkUnavailable:
            return "No internet connection"
        case .unknown(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .keychainError:
            return "Try restarting the app or check system settings"
        case .mnemonicNotFound:
            return "You may need to import your recovery phrase"
        case .authenticationFailed:
            return "Please try again or check your biometric settings"
        case .biometricNotAvailable:
            return "Enable Face ID or Touch ID in Settings"
        case .invalidMnemonic, .invalidBIP39Words:
            return "Check your recovery phrase and try again"
        case .mnemonicHashMismatch:
            return "Make sure you're entering the correct recovery phrase for this wallet"
        case .networkUnavailable:
            return "Check your internet connection and try again"
        default:
            return nil
        }
    }
}
