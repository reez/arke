# Default Contact Implementation

## Overview
Implemented `createDefaultContactsIfNeeded()` functionality to automatically create a system test contact "Faucetto Signetto" when the wallet is first initialized, mirroring the existing default tags pattern.

## Changes Made

### 1. Schema Changes

#### PersistentContact.swift
- **Added**: `var isSystemContact: Bool = false` property
  - Identifies system-created contacts (like default tags have `isSystemTag`)
  - Default value `false` for CloudKit compatibility
  - Updated `init()` to include this parameter

#### ContactModel.swift
- **Added**: `let isSystemContact: Bool` property
  - Mirrors the persistent model property
  - Updated all initializers to include this field:
    - Main `init()`
    - `init(from persistentContact:)`
    - `toPersistentContact()`
    - `withUpdatedTimestamp()`

### 2. Service Layer

#### ContactService.swift
- **Added**: `createDefaultContactsIfNeeded()` public method
  - Checks if `contactCount == 0` before creating
  - Uses task manager for deduplication
  - Delegates to private implementation

- **Added**: `performCreateDefaultContacts()` private method
  - Creates "Faucetto Signetto" contact with:
    - Name: `"Faucetto Signetto"`
    - Notes: `"System test contact for signet faucet"`
    - `isSystemContact: true`
  - Adds two placeholder addresses:
    - **Ark Address**: `tark1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqs4wuzwu` (primary)
    - **Onchain Address**: `tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx`
  - Uses `ContactAddressService` to properly validate and create addresses
  - Gracefully handles address creation failures (logs warning but continues)
  - Reloads contacts after creation to update in-memory cache

### 3. Manager Layer

#### WalletManager.swift
- **Added**: `createDefaultContactsIfNeeded()` delegation method
  - Simply delegates to `contactService.createDefaultContactsIfNeeded()`
  - Follows the same pattern as `createDefaultTagsIfNeeded()`

- **Updated**: `performInitialization()`
  - Added call to `await createDefaultContactsIfNeeded()` after `createDefaultTagsIfNeeded()`
  - Only executes when wallet exists and after successful refresh

## Implementation Flow

```
WalletManager.performInitialization()
  ↓
await refresh() // Load existing wallet data
  ↓
await createDefaultTagsIfNeeded()
  ↓
await createDefaultContactsIfNeeded() // NEW
  ↓
  → ContactService.createDefaultContactsIfNeeded()
      ↓
      → Check if contactCount == 0
      ↓
      → performCreateDefaultContacts()
          ↓
          → Create ContactModel with isSystemContact = true
          ↓
          → Insert PersistentContact into ModelContext
          ↓
          → Save to SwiftData
          ↓
          → Add Ark address (primary) via ContactAddressService
          ↓
          → Add Onchain address via ContactAddressService
          ↓
          → Reload contacts to refresh cache
```

## Default Contact Details

**Name**: Faucetto Signetto  
**Notes**: System test contact for signet faucet  
**System Contact**: Yes (`isSystemContact = true`)  
**Profile Image**: Not yet configured (asset name: "FaucettoSignetto")

### Addresses

1. **Ark Address** (Primary)
   - Address: `tark1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqs4wuzwu`
   - Label: "Ark Address"
   - Format: Ark
   - Type: Primary

2. **Onchain Address**
   - Address: `tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx`
   - Label: "Onchain Address"
   - Format: Bitcoin (Signet)
   - Type: Secondary

## TODO: Next Steps

### 1. Replace Placeholder Addresses
The current implementation uses placeholder addresses. Replace with actual faucet addresses:
- Update `arkAddress` in `ContactService.performCreateDefaultContacts()`
- Update `onchainAddress` in `ContactService.performCreateDefaultContacts()`

### 2. Add Profile Image
To add the custom profile image:
1. Add image to Assets.xcassets with name "FaucettoSignetto"
2. Load the image and convert to `Data`:
```swift
#if os(iOS)
if let image = UIImage(named: "FaucettoSignetto"),
   let imageData = image.pngData() {
    avatarData = imageData
}
#elseif os(macOS)
if let image = NSImage(named: "FaucettoSignetto"),
   let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
   let bitmapRep = NSBitmapImageRep(cgImage: cgImage),
   let imageData = bitmapRep.representation(using: .png, properties: [:]) {
    avatarData = imageData
}
#endif
```

### 3. Consider Edit/Delete Protection (Future)
The `isSystemContact` flag is now in place. In the future, you can:
- Check `contact.isSystemContact` in the UI to:
  - Hide delete button
  - Disable name editing
  - Show "System Contact" badge
  - Prevent certain operations

Example UI check:
```swift
if !contact.isSystemContact {
    Button("Delete Contact", role: .destructive) {
        // delete action
    }
}
```

## Testing

### Verification Steps
1. **Fresh wallet**: Delete existing wallet and create new one
2. **Check contact created**: Navigate to Contacts view
3. **Verify details**: 
   - Name should be "Faucetto Signetto"
   - Should have 2 addresses (1 Ark, 1 Onchain)
   - Ark address should be marked as primary
4. **Check system flag**: Contact should have `isSystemContact = true`
5. **Existing wallets**: Opening existing wallet should NOT create duplicate

### Console Output
Look for these logs:
```
✅ Created default system contact: Faucetto Signetto
✅ Added primary Ark address to contact: tark1qyq...
✅ Added onchain address to contact: tb1qw50...
✅ Default contact setup complete
👥 Loaded 1 contacts with addresses from SwiftData
```

## Notes

- **Schema Migration**: No migration needed since this is early development
- **CloudKit Sync**: System contact will sync across devices via iCloud
- **Idempotent**: Safe to call multiple times - checks `contactCount == 0`
- **Addresses**: Uses `ContactAddressService` for proper validation and format detection
- **Error Handling**: Address creation failures are logged but don't fail the entire operation
- **Naming Convention**: Follows the same pattern as tags (`isSystemTag` → `isSystemContact`)
