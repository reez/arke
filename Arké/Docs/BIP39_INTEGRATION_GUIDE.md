# Using swift-bip39 in Ark Wallet

## Overview

The `swift-bip39` library provides BIP39 mnemonic phrase generation and validation for secure wallet seed phrases.

**Repository**: https://github.com/anquii/BIP39

## Installation

### Using Xcode (Recommended)

1. Open your project in Xcode
2. Go to **File → Add Package Dependencies...**
3. Enter the URL: `https://github.com/anquii/BIP39`
4. Choose version: **Up to Next Major Version** starting from `1.0.0`
5. Click **Add Package**

### Using Package.swift

If you're building a Swift Package, add this to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/anquii/BIP39", from: "1.0.0")
]
```

And add it to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "BIP39", package: "BIP39")
    ]
)
```

## Basic Usage

### Import the Library

```swift
import BIP39
```

### Generate a New Mnemonic

#### 24-word mnemonic (256-bit entropy) - Recommended for Bitcoin wallets

```swift
func generateMnemonic() throws -> String {
    // Generate 32 bytes of entropy (256 bits)
    var randomBytes = [UInt8](repeating: 0, count: 32)
    let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    
    guard result == errSecSuccess else {
        throw NSError(domain: "entropy", code: -1)
    }
    
    // Create entropy and mnemonic
    let entropy = Entropy(bytes: randomBytes)
    let mnemonic = Mnemonic(entropy: entropy)
    
    return mnemonic.phrase
}
```

#### 12-word mnemonic (128-bit entropy)

```swift
func generate12WordMnemonic() throws -> String {
    // Generate 16 bytes of entropy (128 bits)
    var randomBytes = [UInt8](repeating: 0, count: 16)
    let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    
    guard result == errSecSuccess else {
        throw NSError(domain: "entropy", code: -1)
    }
    
    let entropy = Entropy(bytes: randomBytes)
    let mnemonic = Mnemonic(entropy: entropy)
    
    return mnemonic.phrase
}
```

### Validate a Mnemonic

```swift
func validateMnemonic(_ phrase: String) -> Bool {
    do {
        _ = try Mnemonic(phrase: phrase)
        return true
    } catch {
        return false
    }
}
```

### Get Detailed Validation Errors

```swift
func validateWithDetails(_ phrase: String) throws {
    // This throws an error if the phrase is invalid
    _ = try Mnemonic(phrase: phrase)
}

// Usage
do {
    try validateWithDetails("invalid phrase")
} catch {
    print("Validation failed: \(error)")
}
```

### Convert Between Entropy and Phrase

```swift
// Phrase to entropy
func phraseToEntropy(_ phrase: String) throws -> [UInt8] {
    let mnemonic = try Mnemonic(phrase: phrase)
    return mnemonic.entropy.bytes
}

// Entropy to phrase
func entropyToPhrase(_ bytes: [UInt8]) -> String {
    let entropy = Entropy(bytes: bytes)
    let mnemonic = Mnemonic(entropy: entropy)
    return mnemonic.phrase
}
```

## Integration with BarkWalletFFI

The `BarkWalletFFI` class now uses `swift-bip39` for:

1. **Generating new wallets** - Creates cryptographically secure 24-word mnemonics
2. **Importing wallets** - Validates mnemonic phrases before attempting restore
3. **Secure entropy** - Uses iOS/macOS `SecRandomCopyBytes` for true randomness

### Key Changes Made

#### Import Statement
```swift
import BIP39
```

#### Generate Mnemonic (updated)
```swift
private func generateMnemonic() throws -> String {
    // Generate secure 256-bit entropy (24 words)
    let entropyBitCount = 256
    var randomBytes = [UInt8](repeating: 0, count: entropyBitCount / 8)
    let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    
    guard result == errSecSuccess else {
        throw BarkWalletFFIError.configurationError("Failed to generate random entropy")
    }
    
    // Create entropy from random bytes
    let entropy = Entropy(bytes: randomBytes)
    
    // Generate mnemonic from entropy
    let mnemonic = Mnemonic(entropy: entropy)
    
    return mnemonic.phrase
}
```

#### Validate Mnemonic (new helper)
```swift
private func validateMnemonic(_ phrase: String) -> Bool {
    do {
        _ = try Mnemonic(phrase: phrase)
        return true
    } catch {
        return false
    }
}
```

#### Import Wallet (improved validation)
```swift
func importWallet(network: String? = nil, asp: String? = nil, mnemonic: String) async throws -> String {
    // ... preview check ...
    
    // Validate mnemonic using BIP39 library
    let trimmedMnemonic = mnemonic.trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard validateMnemonic(trimmedMnemonic) else {
        print("❌ Invalid BIP39 mnemonic phrase")
        throw BarkWalletFFIError.invalidMnemonic
    }
    
    // ... rest of import logic ...
}
```

## BIP39 Specifications

### Entropy to Mnemonic Mapping

| Entropy (bits) | Checksum (bits) | Total (bits) | Words |
|----------------|-----------------|--------------|-------|
| 128            | 4               | 132          | 12    |
| 160            | 5               | 165          | 15    |
| 192            | 6               | 198          | 18    |
| 224            | 7               | 231          | 21    |
| 256            | 8               | 264          | 24    |

### Word List

- BIP39 uses a standardized list of 2048 words
- Each word represents 11 bits of data
- The library uses the English word list by default
- All words are unique within the first 4 letters

## Security Best Practices

1. **Use 256-bit entropy (24 words)** for maximum security
2. **Never hardcode mnemonics** in production code
3. **Store mnemonics securely** using Keychain (already done via SecurityService)
4. **Validate user input** before importing wallets
5. **Use SecRandomCopyBytes** for entropy generation (cryptographically secure)

## Testing

### Standard Test Mnemonics

The library provides these well-known test mnemonics:

**12 words:**
```
abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about
```

**24 words:**
```
abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art
```

### Unit Test Example

```swift
import Testing
import BIP39

@Test("Generate and validate mnemonic")
func testMnemonicGeneration() throws {
    // Generate
    var randomBytes = [UInt8](repeating: 0, count: 32)
    let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    #expect(result == errSecSuccess)
    
    let entropy = Entropy(bytes: randomBytes)
    let mnemonic = Mnemonic(entropy: entropy)
    let phrase = mnemonic.phrase
    
    // Validate
    let words = phrase.split(separator: " ")
    #expect(words.count == 24)
    
    // Round trip
    let validated = try Mnemonic(phrase: phrase)
    #expect(validated.phrase == phrase)
}

@Test("Validate known test mnemonic")
func testKnownMnemonic() throws {
    let testPhrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    
    let mnemonic = try Mnemonic(phrase: testPhrase)
    #expect(mnemonic.phrase == testPhrase)
}

@Test("Reject invalid mnemonic")
func testInvalidMnemonic() {
    let invalid = "not a valid mnemonic phrase"
    
    #expect(throws: Error.self) {
        _ = try Mnemonic(phrase: invalid)
    }
}
```

## Common Errors

### Invalid Phrase Length
```
Error: Mnemonic phrase must be 12, 15, 18, 21, or 24 words
```
**Solution**: Ensure the phrase has the correct word count

### Invalid Checksum
```
Error: Invalid mnemonic checksum
```
**Solution**: The phrase has been modified or corrupted. Use the original phrase.

### Invalid Word
```
Error: Word not in BIP39 word list
```
**Solution**: Check for typos. All words must be from the standard BIP39 word list.

## Additional Resources

- [BIP39 Specification](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)
- [swift-bip39 GitHub](https://github.com/anquii/BIP39)
- [BIP39 Word List](https://github.com/bitcoin/bips/blob/master/bip-0039/english.txt)

## Next Steps

You may also want to explore:

1. **BIP32/BIP44** - For hierarchical deterministic key derivation
2. **Key derivation** - Converting mnemonic to seed and then to keys
3. **Passphrase support** - Adding an optional passphrase (BIP39 extension)

For Bitcoin key derivation from mnemonics, you might want to look at libraries like:
- `swift-bitcoin` for Bitcoin-specific operations
- Or use your existing Rust FFI layer if it handles key derivation
