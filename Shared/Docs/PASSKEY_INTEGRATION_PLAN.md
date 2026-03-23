# Passkey Integration Implementation Plan

## Executive Summary

This document outlines the implementation plan for integrating Apple Passkeys into Arke wallet creation and recovery. The hybrid approach balances convenience for mainstream users with sovereignty options for advanced users, while acknowledging Ark protocol's unique recovery constraints.

**Target Date:** TBD  
**Status:** Planning Phase  
**Priority:** Medium-High (UX Improvement)

---

## Table of Contents

1. [Context & Motivation](#context--motivation)
2. [Technical Architecture](#technical-architecture)
3. [Implementation Phases](#implementation-phases)
4. [File Changes Required](#file-changes-required)
5. [Security Considerations](#security-considerations)
6. [User Experience Flow](#user-experience-flow)
7. [Testing Strategy](#testing-strategy)
8. [Future Enhancements](#future-enhancements)

---

## Context & Motivation

### Current State

**Wallet Creation:**
- BIP39 mnemonic generated via `bark` CLI or BDK
- Stored in local Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
- PBKDF2 hash synced via `NSUbiquitousKeyValueStore` for cross-device detection
- Mnemonic intentionally never syncs to iCloud
- Multi-device setup requires manual QR code import

**Key Limitation:**
- Users must manually backup 12-24 word phrase
- Lost device = complex recovery process
- Poor UX compared to modern apps

### Why Passkeys Make Sense for Ark

Unlike traditional Bitcoin wallets, Ark has unique recovery characteristics:

1. **Mnemonic is necessary but not sufficient**
   - Recovers on-chain Bitcoin keys and signing ability
   - Does NOT recover VTXOs (off-chain state with ASP)
   - Does NOT recover transaction history, pending states, round participation

2. **Already requires iCloud for practical recovery**
   - CloudKit stores: transactions, contacts, tags, device registry
   - `NSUbiquitousKeyValueStore` used for wallet detection
   - VTXO state likely in SwiftData/CloudKit
   - Without these, even with mnemonic, wallet is partially broken

3. **User trust assumption is already present**
   - iPhone users are in Apple ecosystem
   - Already trusting iCloud for transaction history
   - Passkey sync is consistent with existing trust model

4. **Future-proof with VTXO export/import**
   - When VTXO portability arrives, users can export both:
     - Mnemonic (on-chain keys)
     - VTXOs (off-chain state)
   - Full self-sovereignty becomes possible even with Passkey default

### Solution: Hybrid Approach

**Three-tier sovereignty spectrum:**

```
┌─────────────────────────────────────────────────────┐
│ Level 1: Passkey (Recommended - 95% of users)       │
│ ✓ Auto-sync across devices                          │
│ ✓ Seamless recovery with Face ID                    │
│ ✓ iCloud Keychain backup                            │
│ ✓ No manual phrase management                       │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Level 2: Passkey + Manual Export (Power users)      │
│ ✓ Everything from Level 1                           │
│ ✓ Export mnemonic (emergency backup)                │
│ ✓ Export VTXOs (when available)                     │
│ ✓ Can escape Apple ecosystem if needed              │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Level 3: Pure Manual (Advanced - 5% of users)       │
│ ✓ No iCloud dependency                              │
│ ✓ Manual mnemonic backup                            │
│ ✓ Manual VTXO export/import                         │
│ ✓ Full self-sovereignty                             │
└─────────────────────────────────────────────────────┘
```

---

## Technical Architecture

### Core Components

#### 1. Passkey Service (`PasskeyService.swift`)

New service responsible for Passkey operations:

```swift
@MainActor
@Observable
class PasskeyService {
    // MARK: - Properties
    private let keychainService = "com.arke.wallet.passkey"
    private let credentialID = "arke.wallet.credential"
    
    // MARK: - Passkey Creation
    func createPasskey(for username: String) async throws -> ASAuthorizationPlatformPublicKeyCredentialRegistration
    
    // MARK: - Passkey Authentication
    func authenticateWithPasskey() async throws -> ASAuthorizationPlatformPublicKeyCredentialAssertion
    
    // MARK: - Encryption/Decryption
    func encryptMnemonic(_ mnemonic: String, using credential: Data) throws -> Data
    func decryptMnemonic(_ encryptedData: Data, using credential: Data) throws -> String
    
    // MARK: - Storage
    func saveEncryptedMnemonic(_ encryptedData: Data) async throws
    func loadEncryptedMnemonic() async throws -> Data?
}
```

#### 2. Enhanced SecurityService

Update `Arke/Shared/Services/SecurityService.swift`:

```swift
// Add to SecurityService
enum WalletBackupMode {
    case passkey          // iCloud Keychain sync via Passkey
    case manual           // Traditional 12-word phrase
    case hybrid           // Passkey + manual export option
}

func saveMnemonic(
    _ mnemonic: String, 
    mode: WalletBackupMode,
    requireBiometric: Bool = false
) async throws

func getCurrentBackupMode() -> WalletBackupMode
func migrateToPasskey() async throws
func migrateToManual() async throws
```

#### 3. Data Flow

```
┌─────────────────────────────────────────────────────┐
│                 Wallet Creation                      │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
              ┌─────────────────┐
              │ Generate        │
              │ BIP39 Mnemonic  │
              └─────────────────┘
                        │
           ┌────────────┴────────────┐
           │                         │
           ▼                         ▼
    ┌─────────────┐          ┌─────────────┐
    │  PASSKEY    │          │   MANUAL    │
    │    MODE     │          │    MODE     │
    └─────────────┘          └─────────────┘
           │                         │
           ▼                         ▼
    ┌─────────────┐          ┌─────────────┐
    │ 1. Create   │          │ 1. Show     │
    │    Passkey  │          │    12-word  │
    │             │          │    phrase   │
    │ 2. Encrypt  │          │             │
    │    mnemonic │          │ 2. User     │
    │    with     │          │    writes   │
    │    Passkey  │          │    down     │
    │             │          │             │
    │ 3. Store in │          │ 3. Store    │
    │    iCloud   │          │    in local │
    │    Keychain │          │    Keychain │
    │             │          │    only     │
    │ 4. Store    │          │             │
    │    local    │          │ 4. No sync  │
    │    copy for │          │             │
    │    speed    │          │             │
    └─────────────┘          └─────────────┘
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1-2)

**Goal:** Create core Passkey infrastructure

**Tasks:**
1. Create `PasskeyService.swift` in `Arke/Shared/Services/`
   - Implement Passkey registration flow
   - Implement Passkey authentication flow
   - Add encryption/decryption using CryptoKit
   - Add iCloud Keychain storage

2. Update `SecurityService.swift`
   - Add `WalletBackupMode` enum
   - Add mode-aware `saveMnemonic()` method
   - Add migration methods
   - Keep backward compatibility

3. Add entitlements
   - Update `Arké mobile.entitlements`
   - Add "Associated Domains" for Passkey
   - Ensure iCloud Keychain is enabled

**Files Modified:**
- `Arke/Shared/Services/PasskeyService.swift` (new)
- `Arke/Shared/Services/SecurityService.swift`
- `Arke/Arké mobile/Arke_mobile.entitlements`
- `Arke/Arké/Arké.entitlements`

**Testing:**
- Unit tests for encryption/decryption
- Test Passkey creation in simulator
- Test iCloud Keychain storage

---

### Phase 2: Wallet Creation UI (Week 3-4)

**Goal:** Add Passkey option to wallet creation flow

**Tasks:**
1. Create backup mode selection view
   - `BackupModeSelectionView_iOS.swift`
   - Show two options: Passkey (recommended) vs Manual
   - Clear explanation of each approach

2. Update `CreateWalletView_iOS.swift`
   - Add backup mode parameter
   - Call appropriate creation method based on mode
   - Handle Passkey creation errors gracefully

3. Create Passkey creation success view
   - Show confirmation that Passkey was created
   - Explain cross-device sync
   - Option to view/export mnemonic anyway (hybrid mode)

**Files Modified:**
- `Arke/Arké mobile/Views/FirstUse/BackupModeSelectionView_iOS.swift` (new)
- `Arke/Arké mobile/Views/FirstUse/CreateWalletView_iOS.swift`
- `Arke/Arké mobile/Views/FirstUse/OnboardingFlow_iOS.swift`
- `Arke/Shared/Data/WalletManager.swift` (add mode parameter)

**UI Flow:**
```
OnboardingFlow
    ↓
Choose Backup Method
    ├─ Passkey (Recommended)
    │   ↓
    │   Face ID Prompt
    │   ↓
    │   Creating Wallet...
    │   ↓
    │   Success! (with optional "View Recovery Phrase" button)
    │
    └─ Manual Backup (Advanced)
        ↓
        Creating Wallet...
        ↓
        Write Down Your 12 Words
        ↓
        Confirm Words
```

**Testing:**
- Test Passkey creation flow
- Test Face ID prompt
- Test error handling (user cancels, Face ID unavailable)
- Test on physical device

---

### Phase 3: Recovery Flow (Week 5-6)

**Goal:** Allow users to recover wallet using Passkey

**Tasks:**
1. Update `LinkWalletView_iOS.swift`
   - Detect if Passkey exists in iCloud Keychain
   - Show "Recover with Face ID" button if available
   - Show "Import from QR Code" as alternative

2. Create Passkey recovery flow
   - Authenticate with Face ID
   - Decrypt mnemonic from iCloud Keychain
   - Import wallet using decrypted mnemonic
   - Restore from CloudKit (VTXOs, transactions, etc.)

3. Handle migration scenarios
   - Manual → Passkey upgrade
   - Passkey → Manual downgrade

**Files Modified:**
- `Arke/Arké mobile/Views/FirstUse/LinkWalletView_iOS.swift`
- `Arke/Arké mobile/Views/FirstUse/PasskeyRecoveryView_iOS.swift` (new)
- `Arke/Shared/Services/SecurityService.swift` (add recovery methods)

**Testing:**
- Test recovery on new device
- Test recovery with iCloud sync delay
- Test fallback to QR code if Passkey fails

---

### Phase 4: Settings Integration (Week 7-8)

**Goal:** Allow users to manage backup mode and export options

**Tasks:**
1. Update `SecuritySettingsView.swift`
   - Show current backup mode
   - "Upgrade to Passkey" button (if manual)
   - "Switch to Manual Backup" button (if Passkey)
   - "Export Recovery Phrase" option (always available)

2. Create export flow
   - Require Face ID authentication
   - Show mnemonic with copy/share options
   - Warning about security implications

3. Add VTXO export placeholder
   - "Export VTXOs (Coming Soon)" section
   - Explain future full self-custody option

**Files Modified:**
- `Arke/Arké mobile/Views/Settings/SecuritySettingsView_iOS.swift` (new/update existing)
- `Arke/Arké mobile/Views/Settings/ExportRecoveryPhraseView_iOS.swift` (new)
- `Arke/Arké mobile/Views/Settings/BackupModeManagementView_iOS.swift` (new)

**UI Structure:**
```
Settings → Security & Backup
    ├─ Backup Method
    │   ├─ Current: Passkey (iCloud)
    │   └─ Change to Manual (Advanced)
    │
    ├─ Export for Self-Custody
    │   ├─ Export Recovery Phrase
    │   └─ Export VTXOs (Coming Soon)
    │
    └─ Devices with Access
        └─ [List of devices from DeviceRegistration]
```

**Testing:**
- Test mode switching
- Test export with biometric auth
- Test on devices without Face ID

---

### Phase 5: Migration & Polish (Week 9-10)

**Goal:** Handle existing users and edge cases

**Tasks:**
1. Detect existing users without Passkey
   - Show one-time migration prompt
   - Explain benefits of Passkey
   - Allow dismissal (don't force)

2. Handle edge cases
   - User disabled iCloud Keychain
   - User disabled Face ID/passcode
   - Passkey sync failures
   - Multiple devices with timing issues

3. Add analytics/logging
   - Track Passkey adoption rate
   - Track recovery success rate
   - Track mode switching patterns

4. Documentation
   - Update user-facing help docs
   - Update developer docs
   - Add troubleshooting guide

**Files Modified:**
- `Arke/Shared/Services/MigrationService.swift` (new)
- `Arke/Arké mobile/Views/Settings/PasskeyMigrationPromptView_iOS.swift` (new)
- Various files for error handling improvements

**Testing:**
- Test migration from manual to Passkey
- Test all error scenarios
- User acceptance testing

---

## File Changes Required

### New Files

```
Arke/Shared/Services/
├─ PasskeyService.swift
└─ MigrationService.swift (Phase 5)

Arke/Arké mobile/Views/FirstUse/
├─ BackupModeSelectionView_iOS.swift
└─ PasskeyRecoveryView_iOS.swift

Arke/Arké mobile/Views/Settings/
├─ SecuritySettingsView_iOS.swift (may already exist)
├─ ExportRecoveryPhraseView_iOS.swift
├─ BackupModeManagementView_iOS.swift
└─ PasskeyMigrationPromptView_iOS.swift (Phase 5)

Arke/Shared/Docs/
└─ PASSKEY_USER_GUIDE.md (user-facing)
```

### Modified Files

```
Arke/Shared/Services/
└─ SecurityService.swift
    - Add WalletBackupMode enum
    - Add mode-aware save/load methods
    - Add migration methods

Arke/Shared/Data/
└─ WalletManager.swift
    - Add createWallet(mode:) parameter
    - Update initialization to detect mode

Arke/Arké mobile/Views/FirstUse/
├─ CreateWalletView_iOS.swift
│   - Add mode selection
│   - Handle Passkey flow
├─ LinkWalletView_iOS.swift
│   - Add Passkey recovery option
└─ OnboardingFlow_iOS.swift
    - Add mode selection step

Arke/Arké mobile/
├─ Arke_mobile.entitlements
│   - Add Associated Domains
│   - Ensure iCloud Keychain
└─ Arké/Arké.entitlements
    - Same updates for macOS target

Arke/Shared/Models/
└─ WalletConfiguration.swift (if exists)
    - Add backupMode property
```

---

## Security Considerations

### Encryption Approach

**Passkey-derived encryption:**
```swift
// Use Passkey credential ID as key derivation material
let credentialID = passkeyAssertion.credentialID
let salt = "com.arke.wallet.v1".data(using: .utf8)!

// Derive encryption key using HKDF
let symmetricKey = HKDF<SHA256>.deriveKey(
    inputKeyMaterial: SymmetricKey(data: credentialID),
    salt: salt,
    outputByteCount: 32
)

// Encrypt mnemonic using ChaChaPoly
let sealedBox = try ChaChaPoly.seal(
    mnemonicData,
    using: symmetricKey
)

// Store sealed box in iCloud Keychain
```

### Storage Locations

**Passkey Mode:**
- **Local Keychain**: Unencrypted mnemonic (fast access, never syncs)
  - `kSecAttrSynchronizable = false`
  - `kSecAttrAccessible = kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
  
- **iCloud Keychain**: Encrypted mnemonic (backup, syncs)
  - `kSecAttrSynchronizable = true`
  - `kSecAttrAccessControl = .biometryCurrentSet`
  - Requires Face ID to decrypt

**Manual Mode:**
- **Local Keychain only**: Unencrypted mnemonic
  - `kSecAttrSynchronizable = false`
  - User responsible for backup

### Threat Model

**Passkey protects against:**
- ✅ Device loss (syncs to new device)
- ✅ Accidental deletion (recoverable from iCloud)
- ✅ User forgot password (uses biometric)
- ✅ Unauthorized iCloud access (encrypted, requires biometric)

**Passkey does NOT protect against:**
- ❌ Apple account compromise + biometric compromise
- ❌ Malicious apps with Keychain access (same as current)
- ❌ Physical coercion to unlock with Face ID
- ❌ iCloud infrastructure breach (encrypted at rest, but Apple holds keys)

**Mitigation:**
- Always offer manual export option
- Educate users about trade-offs
- Consider hardware security key support later

---

## User Experience Flow

### First-Time User Journey (Passkey Mode)

```
1. User opens app
   ↓
2. "Welcome to Arke" (intro video)
   ↓
3. "How would you like to protect your wallet?"
   
   ┌──────────────────────────────────────────┐
   │  🔐 Face ID Protection (Recommended)     │
   │                                          │
   │  ✓ Automatic backup to iCloud            │
   │  ✓ Works on all your Apple devices       │
   │  ✓ No recovery phrase to remember        │
   │                                          │
   │       [Continue with Face ID]            │
   └──────────────────────────────────────────┘
   
   ┌──────────────────────────────────────────┐
   │  📝 Manual Backup (Advanced)             │
   │                                          │
   │  ✓ Full self-custody                     │
   │  ✓ No iCloud dependency                  │
   │  ✓ You manage 12-word phrase             │
   │                                          │
   │       [Use Manual Backup]                │
   └──────────────────────────────────────────┘
   
   ↓ (User selects Passkey)
   
4. Face ID prompt appears
   "Arke wants to create a secure wallet 
    protected by Face ID"
   
   [Face ID animation]
   
   ↓
   
5. Creating your wallet...
   [Magic wallet creation animation]
   
   ✅ Success!
   
   Your wallet is protected by Face ID and 
   automatically backed up to iCloud.
   
   Optional: [View Recovery Phrase Anyway]
   
   [Get Started]
```

### Multi-Device Setup (Passkey Mode)

```
User gets new iPhone
   ↓
Signs in with Apple ID
   ↓
Opens Arke app
   ↓
"Welcome back!"

We found your wallet in iCloud.
   
   [Unlock with Face ID]
   
   ↓
   
Face ID prompt
   ↓
   
✅ Wallet restored!

Restoring your data...
├─ Balance: ✓
├─ Transactions: ✓
├─ Contacts: ✓
└─ Tags: ✓

[Continue]
```

### Settings Management

```
Settings → Security & Backup

┌─────────────────────────────────────┐
│ Backup Method                       │
│                                     │
│ Current: Face ID (iCloud)           │
│                                     │
│ Your wallet syncs across all your  │
│ Apple devices using iCloud.         │
│                                     │
│ [Change Backup Method...]           │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Export for Self-Custody             │
│                                     │
│ [Export Recovery Phrase]            │
│                                     │
│ [Export VTXOs] Coming Soon          │
│                                     │
│ Save these securely to maintain     │
│ access even without iCloud.         │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Devices with Access                 │
│                                     │
│ • iPhone 15 Pro (This device)       │
│ • iPad Pro (Last active 2 days ago) │
│                                     │
│ [Manage Devices...]                 │
└─────────────────────────────────────┘
```

---

## Testing Strategy

### Unit Tests

```swift
// PasskeyServiceTests.swift
class PasskeyServiceTests: XCTestCase {
    func testEncryptionDecryption()
    func testPasskeyCreation()
    func testPasskeyAuthentication()
    func testKeychainStorage()
    func testMigrationToPasskey()
    func testMigrationToManual()
}

// SecurityServiceTests.swift (additions)
func testBackupModeDetection()
func testModeSwitching()
func testPasskeyFallback()
```

### Integration Tests

```swift
// WalletCreationTests.swift
func testCreateWalletWithPasskey()
func testCreateWalletManual()
func testRecoverWalletWithPasskey()
func testRecoverWalletFromQR()
func testMultiDeviceSync()
```

### Manual Testing Checklist

**Phase 1:**
- [ ] Passkey creation on physical device
- [ ] Face ID prompt appears correctly
- [ ] Encryption/decryption works
- [ ] iCloud Keychain storage persists

**Phase 2:**
- [ ] Backup mode selection appears
- [ ] Both flows complete successfully
- [ ] Error handling works (user cancels)
- [ ] UI is clear and intuitive

**Phase 3:**
- [ ] Recovery on new device works
- [ ] Face ID recovery is seamless
- [ ] QR code fallback works
- [ ] Migration preserves all data

**Phase 4:**
- [ ] Settings show correct mode
- [ ] Mode switching works both ways
- [ ] Export shows mnemonic correctly
- [ ] All changes persist

**Phase 5:**
- [ ] Existing users see migration prompt
- [ ] Migration doesn't lose data
- [ ] Edge cases handled gracefully

### Device Testing Matrix

| Device | iOS Version | iCloud | Face ID | Test |
|--------|-------------|--------|---------|------|
| iPhone 15 Pro | 18.0 | ✓ | ✓ | Primary |
| iPhone SE | 17.0 | ✓ | ✗ (Touch ID) | Fallback |
| iPad Pro | 18.0 | ✓ | ✓ | Multi-device |
| Simulator | 18.0 | ✗ | ✗ | Dev testing |

---

## Future Enhancements

### Phase 6+: Advanced Features

1. **VTXO Export/Import**
   - When Ark protocol supports VTXO portability
   - Add export button next to mnemonic export
   - Full self-custody achieved

2. **Hardware Security Key Support**
   - Support USB/NFC security keys
   - Even more secure than biometrics
   - For paranoid users

3. **Cross-Platform Passkey**
   - Android support via FIDO2
   - Web wallet support
   - True cross-platform sync

4. **Social Recovery**
   - Shamir's Secret Sharing
   - Split recovery phrase across trusted contacts
   - Recover without any single backup

5. **Inheritance/Dead Man's Switch**
   - Time-locked recovery
   - Trusted contacts can recover after N months
   - Bitcoin inheritance solved

---

## Success Metrics

### User Experience
- **Wallet creation time**: < 30 seconds (vs 5+ minutes for manual)
- **Multi-device setup time**: < 10 seconds (vs 2+ minutes for QR)
- **User satisfaction**: Track via in-app survey
- **Support requests**: Monitor backup-related issues

### Technical
- **Passkey adoption rate**: Target 80%+ of new users
- **Recovery success rate**: Target 99%+
- **Mode switching rate**: Track migrations both ways
- **Error rate**: < 1% of Passkey operations

### Business
- **User retention**: Improved onboarding = better retention
- **Viral growth**: Easier setup = more referrals
- **Competitive advantage**: Best-in-class Bitcoin wallet UX

---

## Risk Mitigation

### Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| iCloud Keychain failure | High | Low | Always keep local copy + manual export |
| Passkey API changes | Medium | Medium | Follow Apple's beta releases closely |
| Encryption bug | Critical | Low | Extensive testing + code review |
| Sync timing issues | Medium | Medium | Robust retry logic + user feedback |

### User Experience Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| User doesn't trust iCloud | Medium | Medium | Offer manual mode prominently |
| User loses Apple ID | High | Low | Encourage manual export |
| Confusion about modes | Medium | Medium | Clear UI + education |
| Lock-in perception | Low | Medium | Emphasize export options |

---

## Appendix

### Passkey API Reference

```swift
import AuthenticationServices

// Registration
let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
    relyingPartyIdentifier: "arke.app"
)

let challenge = Data() // From server or local generation
let userID = Data() // Unique user identifier

let registrationRequest = provider.createCredentialRegistrationRequest(
    challenge: challenge,
    name: "user@example.com",
    userID: userID
)

// Authentication
let assertionRequest = provider.createCredentialAssertionRequest(
    challenge: challenge
)

// Present UI
let controller = ASAuthorizationController(
    authorizationRequests: [registrationRequest]
)
controller.delegate = self
controller.presentationContextProvider = self
controller.performRequests()
```

### Encryption Example

```swift
import CryptoKit

func encryptMnemonic(_ mnemonic: String, credentialID: Data) throws -> Data {
    // Derive key from Passkey credential
    let salt = "com.arke.wallet.v1".data(using: .utf8)!
    let key = HKDF<SHA256>.deriveKey(
        inputKeyMaterial: SymmetricKey(data: credentialID),
        salt: salt,
        outputByteCount: 32
    )
    
    // Encrypt with ChaChaPoly (authenticated encryption)
    let mnemonicData = mnemonic.data(using: .utf8)!
    let sealedBox = try ChaChaPoly.seal(mnemonicData, using: key)
    
    // Return combined (nonce + ciphertext + tag)
    return sealedBox.combined
}

func decryptMnemonic(_ encrypted: Data, credentialID: Data) throws -> String {
    // Derive same key
    let salt = "com.arke.wallet.v1".data(using: .utf8)!
    let key = HKDF<SHA256>.deriveKey(
        inputKeyMaterial: SymmetricKey(data: credentialID),
        salt: salt,
        outputByteCount: 32
    )
    
    // Decrypt
    let sealedBox = try ChaChaPoly.SealedBox(combined: encrypted)
    let decryptedData = try ChaChaPoly.open(sealedBox, using: key)
    
    return String(data: decryptedData, encoding: .utf8)!
}
```

### Keychain Storage Example

```swift
func saveToiCloudKeychain(_ data: Data, account: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.arke.wallet.passkey",
        kSecAttrAccount as String: account,
        kSecValueData as String: data,
        kSecAttrSynchronizable as String: true, // iCloud sync!
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
    ]
    
    // Delete old entry
    SecItemDelete(query as CFDictionary)
    
    // Add new entry
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.saveFailed(status)
    }
}
```

---

## Conclusion

Passkey integration represents a significant UX improvement for Arke while maintaining sovereignty options. The hybrid approach respects both mainstream users who want convenience and advanced users who want control.

**Key Benefits:**
- ✅ Eliminates manual backup friction
- ✅ Seamless multi-device experience
- ✅ Consistent with Ark's existing iCloud usage
- ✅ Maintains export options for self-custody
- ✅ Future-proof for VTXO portability

**Implementation Timeline:** ~10 weeks (5 phases)

**Next Steps:**
1. Review and approve this plan
2. Create detailed tickets for Phase 1
3. Begin PasskeyService implementation
4. Iterate based on testing feedback

---

**Document Version:** 1.0  
**Last Updated:** 2026-03-23  
**Author:** Assistant  
**Status:** Ready for Review
