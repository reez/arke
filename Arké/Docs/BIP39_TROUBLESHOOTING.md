# Troubleshooting BIP39 Package Integration

## Issue: "Cannot find 'Mnemonic' or 'Entropy' in scope"

This error occurs when the BIP39 package types aren't being properly recognized. Here are the solutions:

### Solution 1: Use Full Module Qualification

The BIP39 library exposes its types within the `BIP39` namespace. Always use the full qualification:

```swift
// ❌ Wrong
let entropy = Entropy(bytes: randomBytes)
let mnemonic = Mnemonic(entropy: entropy)

// ✅ Correct
let entropy = BIP39.Entropy(bytes: randomBytes)
let mnemonic = BIP39.Mnemonic(entropy: entropy)
```

### Solution 2: Verify Package Installation

1. **Check Package Dependencies in Xcode:**
   - Select your project in the Project Navigator
   - Select your app target
   - Go to the "General" tab
   - Scroll down to "Frameworks, Libraries, and Embedded Content"
   - Verify that "BIP39" appears in the list

2. **Check Package in Package Dependencies:**
   - In the Project Navigator, select your project (top-level item)
   - Go to the "Package Dependencies" tab
   - Verify that "BIP39" is listed with status "Up to Date"
   - If not listed, click "+" to add:
     - URL: `https://github.com/anquii/BIP39`
     - Version: "Up to Next Major Version" from 1.0.0

3. **Clean Build Folder:**
   - In Xcode menu: **Product → Clean Build Folder** (Shift+Cmd+K)
   - Then rebuild: **Product → Build** (Cmd+B)

4. **Restart Xcode:**
   - Sometimes Xcode needs a restart to recognize new packages
   - Close Xcode completely
   - Delete derived data (optional but can help):
     ```bash
     rm -rf ~/Library/Developer/Xcode/DerivedData
     ```
   - Reopen your project

### Solution 3: Verify Import Statement

Make sure you have the import at the top of your file:

```swift
import Foundation
import BIP39  // Must be present
```

### Solution 4: Check Target Membership

1. Select `BIP39Usage.swift` or `BarkWalletFFI.swift` in the Project Navigator
2. Open the File Inspector (Cmd+Opt+1)
3. Under "Target Membership", ensure your app target is checked

### Solution 5: Alternative BIP39 Libraries

If the `anquii/BIP39` library continues to have issues, you can try alternative libraries:

#### Option A: swift-bip39 by greymass
```
https://github.com/greymass/swift-bip39
```

Usage:
```swift
import BIP39

let mnemonic = try BIP39.Mnemonic(entropy: Data(randomBytes))
let phrase = mnemonic.phrase
```

#### Option B: WalletKit
```
https://github.com/horizontalsystems/WalletKit
```

This is a more comprehensive wallet library that includes BIP39 support.

## Testing Your Installation

Create a simple test file to verify the package works:

```swift
import Foundation
import BIP39

func testBIP39Installation() {
    // Test 1: Create mnemonic from known entropy
    let testEntropy: [UInt8] = Array(repeating: 0, count: 16)
    let entropy = BIP39.Entropy(bytes: testEntropy)
    let mnemonic = BIP39.Mnemonic(entropy: entropy)
    print("Test mnemonic: \(mnemonic.phrase)")
    
    // Test 2: Validate known mnemonic
    do {
        let testPhrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let validatedMnemonic = try BIP39.Mnemonic(phrase: testPhrase)
        print("✅ Validation works!")
        print("Validated phrase: \(validatedMnemonic.phrase)")
    } catch {
        print("❌ Validation failed: \(error)")
    }
}

// Run the test
testBIP39Installation()
```

## Common Errors and Solutions

### Error: "No such module 'BIP39'"

**Cause:** Package not properly added to project

**Solution:**
1. Go to File → Add Package Dependencies
2. Add: `https://github.com/anquii/BIP39`
3. Select your app target when prompted
4. Rebuild

### Error: "Type 'BIP39' has no member 'Mnemonic'"

**Cause:** Wrong library version or incompatible API

**Solution:**
1. Check the package version in Package Dependencies
2. Try updating to the latest version
3. Verify you're using the correct API for that version

### Error: Build fails with "Cannot load underlying module for 'BIP39'"

**Cause:** SPM cache issues

**Solution:**
```bash
# In Terminal, navigate to your project directory
rm -rf .build
rm Package.resolved  # If using SPM directly

# In Xcode
# File → Packages → Reset Package Caches
```

## Verifying the Updated Code

After making the changes, you should see:

**In BarkWalletFFI.swift:**
```swift
import BIP39

private func generateMnemonic() throws -> String {
    // ...
    let entropy = BIP39.Entropy(bytes: randomBytes)
    let mnemonic = BIP39.Mnemonic(entropy: entropy)
    return mnemonic.phrase
}

private func validateMnemonic(_ phrase: String) -> Bool {
    do {
        _ = try BIP39.Mnemonic(phrase: phrase)
        return true
    } catch {
        return false
    }
}
```

**In BIP39Usage.swift:**
```swift
import BIP39

static func generate24WordMnemonic() throws -> String {
    // ...
    let entropy = BIP39.Entropy(bytes: randomBytes)
    let mnemonic = BIP39.Mnemonic(entropy: entropy)
    return mnemonic.phrase
}
```

## Still Having Issues?

If you're still experiencing problems:

1. **Check the library's actual API:**
   - In Xcode, Cmd+Click on `import BIP39`
   - This will show you the generated interface
   - Look for the actual type names and their namespaces

2. **Consult the library documentation:**
   - Visit: https://github.com/anquii/BIP39
   - Check the README for usage examples
   - Look for any specific setup instructions

3. **Try a minimal example:**
   - Create a new, empty Swift file
   - Add just the import and a simple test
   - If that works, the issue is elsewhere in your code

4. **Consider implementing BIP39 manually:**
   - If the package continues to cause issues
   - The BIP39 algorithm is well-documented
   - Could be implemented directly (though this is more work)

## Contact Information

If none of these solutions work:

1. File an issue on the library's GitHub: https://github.com/anquii/BIP39/issues
2. Check for existing issues that might match your problem
3. Provide your Xcode version, Swift version, and platform (iOS/macOS)
