# SQLite Error 14 Fix - "Unable to open database file"

## Problem
When creating a wallet, SQLite fails with Error Code 14 (SQLITE_CANTOPEN) when trying to create the database file at:
```
/Users/christoph/Library/Containers/GBKS.Ark-wallet-prototype/Data/Library/Application Support/GBKS.Ark-wallet-prototype/bark-data-ffi/bark.sqlite
```

## Root Cause
SQLite Error 14 typically occurs when:
1. The directory doesn't exist when SQLite tries to create the file
2. The directory exists but doesn't have write permissions
3. macOS App Sandbox is blocking file creation

## Solution Applied

### 1. Enhanced Directory Creation (`getWalletDirectory()`)
- Added explicit POSIX permissions (0o755) on macOS
- Added write verification test after directory creation
- Added logging to diagnose permission issues

### 2. Pre-flight Checks in `createWallet()` and `importWallet()`
Before calling the Rust FFI `Wallet.create()`:
1. **Verify directory exists** - Create it if missing with proper permissions
2. **Test write access** - Create and delete a test file to confirm writability
3. **Fail fast with clear error** - If directory can't be created or written to, throw an error before attempting wallet creation

## Testing the Fix

After rebuilding, you should see these logs when creating a wallet:

```
🔧 Creating wallet with FFI...
   Network: signet
   ASP: ark.signet.2nd.dev
   Data dir: /Users/christoph/Library/Containers/.../bark-data-ffi
✅ Data directory is confirmed writable
✅ Wallet created successfully
```

If you see warnings like:
```
⚠️ Data directory doesn't exist, creating it now...
```
That's expected if the directory wasn't created during init.

## If the Issue Persists

### Check 1: App Sandbox Entitlements
If you're still getting SQLite errors, check your app's entitlements file (`.entitlements`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required for sandboxed macOS app -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Add this if not present - allows read/write to Application Support -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

### Check 2: Manually Verify Directory
Open Terminal and run:

```bash
# Check if directory exists
ls -la "/Users/christoph/Library/Containers/GBKS.Ark-wallet-prototype/Data/Library/Application Support/GBKS.Ark-wallet-prototype/"

# Check bark-data-ffi permissions
ls -lad "/Users/christoph/Library/Containers/GBKS.Ark-wallet-prototype/Data/Library/Application Support/GBKS.Ark-wallet-prototype/bark-data-ffi"

# Try to create a test file
touch "/Users/christoph/Library/Containers/GBKS.Ark-wallet-prototype/Data/Library/Application Support/GBKS.Ark-wallet-prototype/bark-data-ffi/test.txt"
```

### Check 3: Clean Build
Sometimes Xcode's sandbox cache can cause issues:

1. In Xcode: Product → Clean Build Folder (Cmd+Shift+K)
2. Delete the app from Applications (if installed)
3. Delete the container:
   ```bash
   rm -rf ~/Library/Containers/GBKS.Ark-wallet-prototype
   ```
4. Rebuild and run

### Check 4: SQLite-Specific Issue
If the directory is writable but SQLite still fails, there might be an issue with how the Rust FFI is opening the database. Check:

1. **SQLite version compatibility** - The Rust crate might expect certain SQLite features
2. **Journal mode** - SQLite WAL mode requires additional file creation permissions
3. **Locking mechanism** - Sandboxed apps might have issues with certain SQLite locking modes

You might need to check the Rust `bark` library's SQLite configuration.

### Check 5: Directory Path Length
Extremely long paths can sometimes cause issues. Your path is quite long:
```
/Users/christoph/Library/Containers/GBKS.Ark-wallet-prototype/Data/Library/Application Support/GBKS.Ark-wallet-prototype/bark-data-ffi/bark.sqlite
```

Consider using a shorter bundle identifier if needed.

## Alternative: Use a Different Location

If Application Support continues to cause issues, you could try using a different directory:

```swift
private static func getWalletDirectory() -> URL {
    // Option 1: Use Documents directory (user-visible but writable)
    let documentsDir = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first!
    
    // Option 2: Use Caches directory (hidden, writable, can be cleared by system)
    let cachesDir = FileManager.default.urls(
        for: .cachesDirectory,
        in: .userDomainMask
    ).first!
    
    // Choose one
    let walletDir = documentsDir.appendingPathComponent("bark-data-ffi")
    
    // ... rest of the implementation
}
```

**Note:** Only use Documents if you want users to see/backup the wallet data through Finder.

## Additional Debugging

Add this to your `createWallet()` method right before calling `Wallet.create()`:

```swift
// Debug: Print all relevant paths and permissions
print("🔍 Debug Info:")
print("   Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
print("   Data dir exists: \(fileManager.fileExists(atPath: datadir))")
print("   Data dir path: \(datadir)")
print("   Wallet dir exists: \(fileManager.fileExists(atPath: walletDir.path))")
print("   Is writable: \(fileManager.isWritableFile(atPath: datadir))")

// Try to get directory attributes
if let attrs = try? fileManager.attributesOfItem(atPath: datadir) {
    print("   Directory attributes: \(attrs)")
}
```

This will help pinpoint exactly where the failure is occurring.

## Contact

If none of these solutions work, the issue might be in the Rust FFI layer's SQLite initialization. You may need to:
1. Check the `bark` Rust library's SQLite configuration
2. Ensure the SQLite library is compiled with the correct flags for macOS
3. Consider whether the Rust code needs to handle sandboxed app scenarios differently

The fixes applied should resolve the most common causes of SQLite Error 14 in sandboxed macOS apps.
