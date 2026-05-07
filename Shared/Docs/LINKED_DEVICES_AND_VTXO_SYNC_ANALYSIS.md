# Linked Devices & VTXO Synchronization Architecture Analysis

**Date**: 2026-05-06  
**Context**: Analysis of current device linking mechanism and path toward hub-and-spoke VTXO synchronization  
**Recent Change**: iCloud Keychain sync for seed phrases enabled (2026-05-06)

---

## Executive Summary

**⚡ BREAKING CHANGE**: As of today, seed phrases now automatically sync via iCloud Keychain across all user devices. This simplifies device onboarding but makes the hub-and-spoke architecture even more critical to prevent multiple devices from independently syncing with the Ark server.

---

Arké has a **production-ready linked devices system** that tracks devices via CloudKit and enables seamless multi-device wallet access. However, there are **two critical constraints** that prevent true multi-device wallet usage:

1. **VTXO data does not currently sync** between devices
2. **Only ONE device can actively connect to the Ark server at a time** (database consistency requirement)

This means the current "linked devices" system is actually a **device migration/backup system**, not true multi-device concurrent access. This document analyzes the architectural constraints and proposes a path toward hub-and-spoke synchronization where one device acts as the primary hub.

**🚨 CRITICAL CONSTRAINT**: Two devices cannot independently sync with the Ark server, as their local databases would diverge and become inconsistent. This fundamentally requires a hub-and-spoke architecture, not peer-to-peer.

---

## 1. Current Linked Devices Architecture

### Core Components

**DeviceRegistration Model** (`Shared/Models/DeviceRegistration.swift`)
- Tracks all devices with wallet access
- Syncs via CloudKit for cross-device visibility
- **Key Properties**:
  - `deviceId`: Stable identifier (Keychain, `ThisDeviceOnly`)
  - `walletHash`: Links device to wallet via mnemonic hash
  - `hasSeed`: Boolean indicating if device has seed phrase
  - `platform`: iOS or macOS
  - `isActive`: Manual unlink flag
  - `lastSeenAt`: Heartbeat timestamp (30-day staleness threshold)

**Two Device Types** (Legacy - Now Obsolete with iCloud Keychain):
1. **Full Wallet Devices** (`hasSeed=true`)
   - Has seed phrase in local Keychain (now syncs via iCloud Keychain)
   - Can sign transactions independently
   - Can generate new addresses

2. **Metadata-Only Devices** (`hasSeed=false`)
   - ~~Can view wallet data via iCloud sync~~
   - ~~Cannot sign transactions alone~~
   - ~~Must link with primary device via QR code~~
   - **NOW OBSOLETE**: All devices get seed automatically via iCloud Keychain

**Note**: With iCloud Keychain sync enabled, the `hasSeed` flag is now meaningless for tracking seed possession. It should be repurposed or replaced with `isPrimaryDevice` to track device role instead. The old QR-based linking flow is no longer needed for seed transfer.

### Device Registration Flow (Current - Will Change)

```
User Creates Wallet (Device A)
  ↓
Device A auto-registers (hasSeed=true, isPrimaryDevice=true)
  ↓
Hash + Seed both sync to iCloud automatically
  ↓
User installs on Device B
  ↓
Device B detects hash AND gets seed via iCloud Keychain
  ↓
Device B auto-registers (hasSeed=true, isPrimaryDevice=false)
  ↓
User sees "Your wallet is available" (no QR scan needed!)
  ↓
Device B is secondary device (has seed but blocked from ASP sync)
```

**New Flow Benefits**:
- ✅ No QR code scanning required for seed transfer
- ✅ Seamless device addition
- ✅ Secondary devices can be promoted to primary if needed
- ⚠️ Must prevent secondary from independently syncing with ASP

### Heartbeat System

- 24-hour interval
- `updateHeartbeatIfNeeded()` keeps device fresh
- Prevents false "stale" detection
- Triggered on app launch and foreground
- Devices older than 30 days shown as potentially stale

---

## 2. Data Synchronization Model

### What Syncs via CloudKit ✅

**Metadata (Safe to Sync)**:
- Transaction metadata (notes, amounts, dates, timestamps)
- Tags (`PersistentTag`)
- Contacts (`PersistentContact`)
- Device registrations
- Balance cache (`ArkBalanceModel`, `OnchainBalanceModel`)
- Wallet configuration
- UI preferences

**Real-Time Sync Mechanism**:
- `CloudKitObserver` watches `NSPersistentStoreRemoteChange` notifications
- Posts custom `.cloudKitDataDidChange` notification
- Services (TagService, ContactService) observe and reload
- SwiftUI views update automatically via `@Query` and `@Observable`

### What Does NOT Sync ❌

**Sensitive Data**:
- ~~Private keys~~ (derived from seed, so effectively sync via seed sync)
- ~~Seed phrases~~ ✅ **NOW SYNCS via iCloud Keychain** (as of today's change)
- Device IDs (Keychain `ThisDeviceOnly`, never syncs)

**Note**: With seed phrases syncing, all devices can derive the same private keys, meaning they all have full signing capability. This is why blocking secondary devices from syncing with ASP is critical - they have the cryptographic capability but shouldn't use it.

**Critical Gap: VTXO Data**:
- VTXOs stored in Bark wallet (Rust FFI)
- Retrieved via `sync()` from ASP (Ark Service Provider)
- **NO persistence to iCloud/CloudKit**
- **NO cross-device synchronization**

---

## 3. The VTXO Synchronization Problem

### Current Behavior

```
Device A (iPhone, has seed + VTXOs)
  └─ VTXOs stored in Bark wallet (local only)

Device B (iPad, has seed via iCloud Keychain)
  └─ Can see transaction metadata via CloudKit
  └─ Must call sync() to fetch VTXOs from ASP
  └─ May get different VTXO state if ASP doesn't have full history
```

### The Critical Gap

When a user switches to a new device:
1. Seed phrase syncs automatically via iCloud Keychain ✅
2. Transaction metadata syncs via CloudKit ✅
3. **VTXOs must be re-synced from ASP server** ⚠️
4. Server doesn't currently provide full VTXO recovery ❌

### Why This Matters

- VTXOs represent **actual spendable funds**
- If ASP doesn't have complete history, funds may appear lost
- User must manually trigger sync on each device
- No way to "transfer" VTXO state between devices directly

### 🚨 THE CRITICAL CONSTRAINT: Database Consistency

**The fundamental problem that changes everything:**

If Device A and Device B both independently call `sync()` on the Ark server:
- Each device maintains its own local Bark wallet database
- Bark wallet tracks VTXO state, pending rounds, exits, etc.
- **These databases WILL diverge** if both devices sync independently
- Result: Inconsistent balances, missing transactions, corrupted state

**Example Failure Scenario:**
```
T0: Device A syncs → sees 5 VTXOs worth 100k sats
T1: Device A sends 50k sats → creates new VTXOs (40k + 10k)
T2: Device B syncs independently → still sees original 5 VTXOs (100k)
T3: Device B tries to spend → uses already-spent VTXOs → FAILURE
```

**This means:**
- ❌ Peer-to-peer multi-device is **architecturally impossible**
- ❌ Cannot have multiple devices independently sync with server
- ✅ **MUST** have hub-and-spoke with ONE primary device
- ✅ Secondary devices receive state from primary via iCloud

This is not a feature limitation - it's a **fundamental requirement** of the Ark protocol's client-side state management.

---

## 4. Hub-and-Spoke Pattern Analysis

### Is It Implemented? **Partially (Foundation Complete, Enforcement Needed)**

**✅ COMPLETED (2026-05-07)**:
- `isPrimaryDevice` flag added to `DeviceRegistration` model
- First device automatically becomes primary on registration
- Helper methods added: `getPrimaryDevice()`, `isCurrentDevicePrimary()`, `migrateToThisDevice()`
- CloudKit sync ready (property syncs across devices automatically)

**❌ REMAINING WORK**:
- Wallet initialization check (block if not primary device)
- "Wallet Active on [Device]" screen for secondary devices
- Transaction relay/approval logic between devices (optional, future)
- Centralized VTXO aggregation mechanism (optional, future)

**Current Behavior (Still BROKEN)**:
- All devices still independently call `sync()` ← **Must be blocked on secondary devices**
- No UI enforcement of single-active-device model yet

**Current Behavior (BROKEN)**:
```
User has iPhone + iPad, both with seed
iPhone syncs → local DB state X
iPad syncs → local DB state Y (diverged)
Result: Inconsistent balances, transaction failures
```

### Must It Be Implemented? **YES (Required for Multi-Device)**

The architecture must change to hub-and-spoke - this is not optional:

**Required Design (Simplified - Single Active Device)**:
```
Primary Device (iPhone) - ONLY device with active wallet
  ├─ Has seed phrase (synced via iCloud Keychain)
  ├─ ONLY device allowed to open/sync wallet with ASP
  ├─ Maintains authoritative VTXO state
  ├─ Full wallet functionality
  └─ Can be migrated to another device

Secondary Devices (iPad, Mac) - WALLET CLOSED
  ├─ Have seed phrase (auto-synced via iCloud Keychain ✅)
  ├─ Seed available for emergency recovery/migration
  ├─ Can see transaction metadata via CloudKit (view-only)
  ├─ Show "Wallet is active on [Primary Device]"
  ├─ Button: "Switch to This Device" (makes this primary)
  └─ NEVER open Bark wallet or sync with ASP
```

**Key Insight**: Secondary devices **don't open the wallet at all**. They show transaction history from CloudKit metadata, but the actual Bark wallet remains closed. This is similar to hardware wallet model - you can only use the wallet on one device at a time.

**Note on Seed Sync**: As of the latest change, seed phrases now sync via iCloud Keychain automatically. This means:
- ✅ New devices get the seed automatically (no QR code scan needed!)
- ✅ Device registration happens automatically via CloudKit sync
- ✅ Secondary devices can be promoted to primary (migration flow)
- ⚠️ **CRITICAL**: Secondary devices MUST NOT open the Bark wallet
- ⚠️ Secondary devices only show CloudKit metadata, never sync with ASP
- ⚠️ This is a "single active device" model, like hardware wallets

**This is NOT optional - it's required for correctness**:
- ✅ Single source of truth for VTXO state (only primary has it)
- ✅ Database consistency guaranteed (no divergence)
- ✅ Reduced ASP server load (only one device syncs)
- ✅ Simple mental model (like hardware wallet)
- ✅ No complex state synchronization needed

**Implementation Requirements (Simplified)**:
1. ✅ Add `isPrimaryDevice` flag to `DeviceRegistration` **(COMPLETED 2026-05-07)**
2. **Block secondary devices from opening Bark wallet** (check before initialization)
3. Show "Wallet Active on [Device]" screen on secondary devices
4. Display CloudKit transaction metadata (view-only)
5. Add "Switch to This Device" button (migration flow)
6. ✅ Migration flow: Mark old primary as secondary, new device as primary **(API READY 2026-05-07)** - UI needed
7. ~~No wallet state serialization needed~~ (wallet never opens on secondary)
8. ~~No state broadcast needed~~ (CloudKit metadata is sufficient for viewing)

---

## 5. Similar App Patterns

### WhatsApp Multi-Device
- Phone is primary device ("hub")
- Desktop/web are secondary ("spokes")
- Message history syncs from phone initially
- After sync, all devices are peers for new messages
- If phone offline for >14 days, secondary devices stop working

### Signal Linked Devices
- Phone is primary device (required)
- Desktop/iPad are linked devices
- All messages flow through primary device
- Secondary devices cannot add new linked devices
- Primary device can unlink secondary devices

### Arké's Current Model (BROKEN)
- Attempts peer-to-peer (like WhatsApp post-sync)
- All devices automatically get seed via iCloud Keychain
- No QR code needed (seed syncs automatically)
- All devices become "equal" with full seed access
- **Critical flaw**: All devices independently sync with ASP
- **Result**: Database divergence, broken balances
- **Made worse by iCloud Keychain**: Nothing prevents users from opening app on multiple devices

### Arké's Required Model (Single Active Device)
- **Must** be like hardware wallet, not WhatsApp/Signal
- Only ONE device has wallet open at a time
- Other devices show "Wallet active on [Device]"
- Secondary devices show CloudKit metadata only (no wallet state)
- User can migrate to different device via "Switch to This Device"
- Simple, safe, no database synchronization complexity

---

## 6. Immediate Risk Assessment

### 🚨 The New Risk: Accidental Multi-Device Usage

**Before iCloud Keychain sync**:
- User creates wallet on iPhone
- Gets new iPad
- Sees "Link Existing Wallet" → scans QR code
- Deliberate, manual action required
- Less likely to accidentally use both simultaneously

**After iCloud Keychain sync (TODAY)**:
- User creates wallet on iPhone
- Gets new iPad
- Opens app → wallet automatically appears
- Zero friction, "just works" like other apps
- **HIGH RISK**: User will naturally use both devices
- **RESULT**: Database corruption within hours/days of multi-device adoption

### User Behavior Expectation

Users expect apps to work like:
- **Photos**: Take photo on iPhone → appears on iPad instantly
- **Notes**: Edit on iPhone → syncs to iPad instantly
- **Messages**: Send on iPhone → appears on all devices

They will **expect the same behavior** from the wallet:
- Send sats on iPhone → balance updates on iPad
- **Reality**: Opening iPad after iPhone use will corrupt database

### Required Immediate Actions

**Option A: Temporary Warning (Quick Fix - Days)**
1. Add banner on app launch: "⚠️ Important: Only use wallet on one device at a time"
2. Show alert if app detects it's been opened on another device recently
3. Add FAQ explaining limitation
4. Document in release notes

**Option B: Single Active Device (Proper Fix - Days)**
1. Add `isPrimaryDevice` check before wallet initialization
2. Block secondary devices from opening wallet entirely
3. Show "Wallet Active on [Device]" screen
4. Display CloudKit transaction metadata (view-only)
5. Add "Switch to This Device" migration button

**Recommendation**: Skip Option A and go straight to Option B - it's actually simpler than the warning approach and provides proper protection.

---

## 7. Path Forward: Two Options (Revised)

### ~~Option 1: Server-Side VTXO Recovery~~ ❌ NOT SUFFICIENT

**Why this doesn't solve the problem**:
- Even with server recovery, **two devices still can't both actively sync**
- Database divergence still occurs if both devices call `sync()`
- Server recovery helps with **initial wallet restore**, but not **concurrent multi-device**
- This is useful for device migration, but doesn't enable true multi-device usage

**Verdict**: Server recovery is necessary but not sufficient. Still need hub-and-spoke.

---

### ~~Option 2: iCloud VTXO State Sync~~ ❌ ARCHITECTURALLY IMPOSSIBLE

**Why this can't work**:
- Assumes all devices can independently sync with ASP
- This **breaks database consistency** (see Section 3)
- Conflict resolution cannot fix diverged databases
- Even with timestamps, you can't merge incompatible states

**Verdict**: This was based on incorrect assumption that peer-to-peer is possible. It's not.

---

### Option 3: Single Active Device ✅ **REQUIRED (SIMPLIFIED)**

**This is the ONLY architecturally sound approach**:
- Only ONE device has wallet open at a time
- **Primary device calls `sync()` on ASP**
- **Secondary devices never open wallet** (Bark wallet stays closed)
- Secondary devices show CloudKit transaction metadata (view-only)
- User can migrate wallet to different device

**Implementation Requirements (Much Simpler)**:
1. Add `isPrimaryDevice` flag to `DeviceRegistration`
2. **Block wallet initialization on secondary devices** (check before opening wallet)
3. Show "Wallet Active on [Device Name]" screen on secondary
4. Display CloudKit transaction metadata (already syncs)
5. Add "Switch to This Device" button (migration flow)
6. Migration: Close wallet on old primary, open on new primary, update flags
7. ~~No wallet state serialization~~ (not needed!)
8. ~~No state broadcast~~ (not needed!)

**Pros**:
- ✅ Architecturally correct (no database divergence possible)
- ✅ Single source of truth (only one wallet open)
- ✅ Reduced server load (only one device syncs)
- ✅ Simple implementation (just block wallet opening)
- ✅ Matches hardware wallet UX (familiar to Bitcoin users)
- ✅ **No complex state synchronization needed**

**Cons**:
- User can only actively use wallet on one device at a time
- Must migrate to switch devices
- ~~Migration requires both devices online~~ (actually no - just update flag via CloudKit)

**Implementation Estimate**: 2-3 days (not weeks!)

---

## 8. Recommended Approach

### **Single Active Device (Option 3) - The Only Path**

**Phase 1: Implement Single Active Device (Required - 2-3 Days)**
1. Add `isPrimaryDevice` boolean to `DeviceRegistration`
2. First device to create/import wallet becomes primary automatically
3. **Add check before wallet initialization** - block if `!isPrimaryDevice`
4. Show "Wallet Active on [Device]" screen on secondary devices
5. Display CloudKit transaction metadata (view-only) on secondary
6. Add "Switch to This Device" button → migration flow
7. Migration flow: Update `isPrimaryDevice` flags via CloudKit
8. After migration, new primary initializes wallet, old primary shows locked screen

**Phase 2: Optimize with Server Recovery (When Available)**
1. Use server VTXO recovery for initial wallet restore
2. Still maintain single active device model
3. Server provides fallback if primary device lost
4. Recovery: Any device can become primary with server state

**Phase 3: Enhanced UX (Future - Optional)**
1. ~~Transaction approval flow~~ (not applicable - wallet closed on secondary)
2. Show sync status from primary device
3. "Last synced X minutes ago" indicator
4. Push notifications for transactions (from metadata sync)

---

## 8. Technical Implementation Details

### VTXO Serialization Strategy

**Challenge**: Bark wallet stores VTXOs in Rust structs
**Solution**: Add FFI methods to serialize/deserialize

```swift
// Proposed FFI additions
extension BarkWallet {
    /// Exports all VTXOs as JSON string
    func exportVTXOs() async throws -> String

    /// Imports VTXOs from JSON string
    func importVTXOs(_ json: String) async throws

    /// Gets VTXO state hash for conflict detection
    func getVTXOStateHash() -> String
}
```

### CloudKit Storage Model

**New Record Type**: `VTXOState`
- `recordID`: Deterministic (wallet hash)
- `encryptedVTXOs`: Encrypted VTXO JSON (via `CKRecord.encryptedValues`)
- `stateHash`: For quick conflict detection
- `lastSyncedAt`: Timestamp
- `deviceId`: Which device last synced
- `vtxoCount`: For sanity checks

### Conflict Resolution Logic

```swift
func mergeVTXOStates(local: VTXOState, remote: VTXOState) -> VTXOState {
    // If timestamps within 5 seconds, merge by VTXO ID
    if abs(local.lastSyncedAt.timeIntervalSince(remote.lastSyncedAt)) < 5 {
        return mergeByVTXOId(local, remote)
    }

    // Otherwise, newest wins
    return local.lastSyncedAt > remote.lastSyncedAt ? local : remote
}
```

---

## 9. Key Files for Implementation

**Device System** (Already Built):
- `Shared/Models/DeviceRegistration.swift` - Device tracking model
- `Shared/Services/DeviceRegistrationService.swift` - Registration logic
- `Shared/Helpers/CloudKitObserver.swift` - Real-time sync notifications

**VTXO System** (Needs Extension):
- `Shared/Data/BarkWalletFFI/BarkWalletFFI+VTXO.swift` - VTXO operations
- `Shared/Services/VTXORefreshService.swift` - VTXO refresh logic
- **NEW**: `Shared/Services/VTXOSyncService.swift` - iCloud VTXO sync

**UI** (Already Built):
- `ArkeMobile/Views/Settings/LinkedDevicesView_iOS.swift` - Device list
- `ArkeDesktop/Views/Settings/LinkedDevicesView.swift` - Device list (macOS)
- **Enhancement**: Add VTXO sync status indicator

---

## 10. Open Questions

1. **VTXO Size Limits**: How large can VTXO state grow? Will it hit CloudKit limits?
2. **Sync Frequency**: How often should devices sync VTXO state? On every change? Periodically?
3. **Emergency Recovery**: If all devices lose VTXO state, can server recover?
4. **Primary Device UX**: If we go hub-and-spoke, how do users choose primary device?
5. **Desktop Role**: Should Mac be allowed as primary device, or mobile-only?
6. **Conflict Strategy**: Merge by VTXO ID, or timestamp-based "newest wins"?
7. **Privacy Trade-off**: Is encrypted CloudKit storage acceptable for VTXO data?

---

## 11. Summary & Next Steps

### Current State ⚠️ **BROKEN FOR MULTI-DEVICE**
- ✅ Robust device tracking via CloudKit
- ✅ Real-time metadata sync across devices
- ✅ Smart device deletion logic
- ✅ Seed phrase auto-sync via iCloud Keychain (NEW)
- ~~✅ QR code linking flow~~ (NOW REDUNDANT - seeds sync automatically)
- ✅ `isPrimaryDevice` flag in `DeviceRegistration` **(COMPLETED 2026-05-07)**
- ✅ Primary device auto-assignment on first registration **(COMPLETED 2026-05-07)**
- ✅ Migration API (`migrateToThisDevice()`) **(COMPLETED 2026-05-07)**
- ❌ **VTXOs don't sync between devices**
- ⚠️ **Hub-and-spoke pattern** (PARTIALLY IMPLEMENTED - foundation complete, enforcement needed)
- ❌ **All devices independently sync with ASP** (causes database divergence - needs blocking)
- 🚨 **URGENT**: iCloud Keychain makes this worse - users can accidentally open wallet on multiple devices
- ⚠️ **Current system only works for device migration, NOT concurrent multi-device use**

### Recommended Next Steps

**Critical Fix** (Before Public Release - NOW URGENT - 1-2 Days):
1. ✅ **Add `isPrimaryDevice` flag to `DeviceRegistration`** **(COMPLETED 2026-05-07)**
   - Model updated with `isPrimaryDevice: Bool` property
   - First device automatically becomes primary
   - Helper methods added: `getPrimaryDevice()`, `isCurrentDevicePrimary()`
2. ✅ **Block wallet initialization on non-primary devices** **(COMPLETED 2026-05-07)**
   - Added `walletActiveElsewhere(deviceName: String)` case to `WalletState` enum
   - `SecurityService.detectWalletState()` now checks `isPrimaryDevice` before allowing wallet init
   - `MainView_iOS` and `MainView` (macOS) block wallet initialization when device is not primary
   - BarkWallet.init() is never called on non-primary devices
3. ✅ **Create "Wallet Locked" screen for secondary devices** **(COMPLETED 2026-05-07)**
   - Created `WalletActiveElsewhereView_iOS` showing primary device name
   - Created `WalletActiveElsewhereView` (macOS) with same functionality
   - Shows which device is currently primary
   - "Make This Device Active" button triggers migration flow
   - Migration calls `DeviceRegistrationService.migrateToThisDevice()`
4. ✅ **Implement migration flow API** **(COMPLETED 2026-05-07)**
   - `migrateToThisDevice()` method ready
   - Updates old primary: `isPrimaryDevice = false`
   - Updates new primary: `isPrimaryDevice = true`
   - Syncs via CloudKit automatically
   - ✅ **UI integration complete** - migration triggered from WalletActiveElsewhereView
5. Add "Active Device" badge in Linked Devices UI (Optional Polish)

**Status**: ✅ **CRITICAL BLOCKER RESOLVED** - Wallet initialization is now properly blocked on non-primary devices. Users can safely open the app on multiple devices without corrupting wallet state.

**Short-Term** (Polish UX - Optional Enhancements):
1. ✅ Add device name to "Wallet Active on [Device Name]" - DONE
2. Show last sync time from primary
3. ✅ Add explanation: "Only one device can have the wallet active at a time" - DONE
4. Smooth migration UX (loading states, success confirmation)
5. Test migration flow between iPhone ↔ iPad ↔ Mac

**Medium-Term** (Future Enhancements):
1. **Payment request relay** (send from secondary → primary handles)
   - User on iPad sees address/invoice
   - Taps "Pay" → request sent to iPhone via CloudKit
   - iPhone shows notification "Payment request from iPad"
   - Primary approves/rejects and completes payment
   - Secondary sees status update via CloudKit
2. Show more detailed CloudKit metadata on secondary devices
3. Add push notifications for new transactions
4. ~~Handle primary device unavailable~~ (just migrate to available device)
5. "Pending payment requests" indicator on primary device

**Long-Term** (When Server Ready):
1. Integrate server VTXO recovery endpoint
2. Use server for initial wallet restore
3. Still maintain hub-and-spoke for active multi-device
4. Server provides fallback if primary device permanently lost

---

## Related Documentation

- `DEVICE_REGISTRY_ALL_PHASES_COMPLETE.md` - Device system implementation
- `DEVICE_REGISTRY_QUICK_REFERENCE.md` - Device API reference
- `CloudKitSyncImplementation.md` - Sync architecture
- `CloudKit/CloudKitSyncGuidelines.md` - Sync best practices
- `PASSKEY_INTEGRATION_PLAN.md` - Future server recovery plans

---

**Author**: Claude (AI Assistant)
**Reviewed**: Pending
**Status**: Draft for Discussion
