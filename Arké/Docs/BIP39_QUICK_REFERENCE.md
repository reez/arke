# swift-bip39 Quick Reference

## Installation

```swift
// In Xcode: File → Add Package Dependencies
// URL: https://github.com/anquii/BIP39
```

## Import

```swift
import BIP39
```

## Generate New Mnemonic

### 24 words (recommended)
```swift
var bytes = [UInt8](repeating: 0, count: 32)
SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
let mnemonic = Mnemonic(entropy: Entropy(bytes: bytes))
let phrase = mnemonic.phrase
```

### 12 words
```swift
var bytes = [UInt8](repeating: 0, count: 16)
SecRandomCopyBytes(kSecRandomDefault, 16, &bytes)
let mnemonic = Mnemonic(entropy: Entropy(bytes: bytes))
let phrase = mnemonic.phrase
```

## Validate Mnemonic

```swift
// Returns true/false
func isValid(_ phrase: String) -> Bool {
    do {
        _ = try Mnemonic(phrase: phrase)
        return true
    } catch {
        return false
    }
}

// Throws error with details
let mnemonic = try Mnemonic(phrase: userInput)
```

## Convert Entropy ↔ Phrase

```swift
// Phrase → Entropy
let mnemonic = try Mnemonic(phrase: phrase)
let bytes = mnemonic.entropy.bytes

// Entropy → Phrase
let entropy = Entropy(bytes: bytes)
let mnemonic = Mnemonic(entropy: entropy)
let phrase = mnemonic.phrase
```

## Test Mnemonics

```swift
// 12 words
"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

// 24 words
"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
```

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| Invalid word count | Wrong number of words | Use 12, 15, 18, 21, or 24 words |
| Invalid checksum | Corrupted phrase | Use original unmodified phrase |
| Word not in list | Typo or invalid word | Check against BIP39 word list |

## Entropy Sizes

| Words | Entropy | Checksum | Total Bits |
|-------|---------|----------|------------|
| 12    | 128     | 4        | 132        |
| 15    | 160     | 5        | 165        |
| 18    | 192     | 6        | 198        |
| 21    | 224     | 7        | 231        |
| 24    | 256     | 8        | 264        |

## Security Notes

✅ **DO:**
- Use 24 words (256-bit) for Bitcoin wallets
- Use `SecRandomCopyBytes` for entropy
- Store in Keychain
- Validate before importing

❌ **DON'T:**
- Hardcode mnemonics
- Use weak random sources
- Store in plain text
- Skip validation
