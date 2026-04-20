//
//  BarkWalletFFI+Mnemonic.swift
//  Arke
//
//  Mnemonic generation, validation, and secure storage
//  Handles BIP39 seed phrases with Keychain integration
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import BIP39

extension BarkWalletFFI {
    
    // MARK: - Mnemonic Generation & Validation
    
    /// Generate a new BIP39 mnemonic (12 words)
    private func generateMnemonic() throws -> String {
        // Use BIP39 library components
        // let entropyGenerator = EntropyGenerator()
        let wordListProvider = EnglishWordListProvider()
        let mnemonicConstructor = MnemonicConstructor()
        
        // Generate 16 bytes (128 bits) of cryptographically secure random entropy
        let entropyByteCount = 16  // 128 bits = 12 words
        var randomBytes = [UInt8](repeating: 0, count: entropyByteCount)
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        
        guard result == errSecSuccess else {
            throw BarkWalletFFIError.configurationError("Failed to generate cryptographically secure random entropy")
        }
        
        // Convert bytes to Data
        let entropy = Data(randomBytes)
        
        // Generate mnemonic from entropy
        let phrase = mnemonicConstructor.mnemonic(entropy: entropy, wordList: wordListProvider.wordList)
        
        print("✅ Generated secure 12-word BIP39 mnemonic")
        print("   Entropy: \(randomBytes.count * 8) bits")
        print("   Words: \(phrase.split(separator: " ").count)")
        
        return phrase
    }
    
    /// Validate a BIP39 mnemonic phrase
    private func validateMnemonic(_ phrase: String) -> Bool {
        // Check if all words are in the wordlist
        let words = phrase.split(separator: " ").map(String.init)
        let wordListProvider = EnglishWordListProvider()
        let wordList = wordListProvider.wordList
        
        // Verify all words exist in wordlist
        for word in words {
            if !wordList.contains(word) {
                print("⚠️ Invalid mnemonic: word '\(word)' not in BIP39 wordlist")
                return false
            }
        }
        
        // Verify word count (must be 12, 15, 18, 21, or 24)
        let validCounts = [12, 15, 18, 21, 24]
        guard validCounts.contains(words.count) else {
            print("⚠️ Invalid mnemonic: word count \(words.count) is not valid (must be 12, 15, 18, 21, or 24)")
            return false
        }
        
        // TODO: Add checksum validation if the library provides it
        return true
    }
    
    // MARK: - Mnemonic Storage & Retrieval
    
    /// Store mnemonic securely using SecurityService (Keychain only - no legacy fallback)
    /// NOTE: This is called from BarkWalletFFI.createWallet() ONLY for import flows.
    /// For new wallet creation, WalletManager handles the storage to avoid duplication.
    func storeMnemonic(_ mnemonic: String) async throws {
        // SecurityService is required - no fallback to file system
        guard let securityService = securityService else {
            throw BarkWalletFFIError.configurationError("SecurityService is required but not available")
        }
        
        print("✅ Storing mnemonic securely via SecurityService (Keychain)")
        do {
            // Store with biometric protection if available
            let useBiometric = securityService.biometricsAvailable()
            try await securityService.saveMnemonic(mnemonic, requireBiometric: useBiometric)
            
            print("✅ Mnemonic stored securely in Keychain")
            if useBiometric {
                print("🔐 Biometric protection enabled")
            }
        } catch {
            print("❌ SecurityService storage failed: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to store mnemonic securely: \(error.localizedDescription)")
        }
    }
    
    func getMnemonic() async throws -> String {
        // Preview mode handling
        if isPreview {
            return "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        }
        
        // Return cached mnemonic if available
        if let cached = cachedMnemonic {
            return cached
        }
        
        // Try to load from storage
        do {
            let mnemonic = try loadMnemonic()
            cachedMnemonic = mnemonic
            return mnemonic
        } catch {
            print("❌ Failed to load mnemonic: \(error)")
            throw BarkWalletFFIError.walletNotInitialized
        }
    }
    
    /// Load mnemonic securely using SecurityService (Keychain only - no legacy fallback)
    func loadMnemonic() throws -> String {
        // SecurityService is required - no fallback to file system
        guard let securityService = securityService else {
            throw BarkWalletFFIError.configurationError("SecurityService is required but not available")
        }
        
        print("✅ Loading mnemonic securely via SecurityService (Keychain)")
        do {
            if let mnemonic = try securityService.loadMnemonic() {
                print("✅ Mnemonic loaded from Keychain")
                return mnemonic
            } else {
                print("⚠️ No mnemonic found in Keychain")
                throw BarkWalletFFIError.walletNotInitialized
            }
        } catch {
            print("❌ SecurityService load failed: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to load mnemonic: \(error.localizedDescription)")
        }
    }
}
