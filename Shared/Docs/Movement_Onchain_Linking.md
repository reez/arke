# Movement-Onchain Transaction Linking

## Problem Statement

Boarding, offboarding, and unilateral exits create both:
1. A movement record from the Ark server
2. One or more onchain Bitcoin transactions

Currently, the app shows both separately in the activity transaction list, resulting in duplication and confusion. This is especially problematic for exits, which can have multiple intermediate onchain transactions plus a final claim transaction.

## Current State Analysis

### Transaction ID Conventions
- Movement transactions: `"movement_{id}"`
- Onchain transactions: `"onchain_{txid}"`
- Both merged by `UnifiedTransactionService` but never semantically linked

### Existing Deduplication
**None.** The different txid prefixes prevent collisions but don't establish relationships. Users see duplicate entries for the same logical operation.

### Available Linking Data
The codebase provides these linking points:
- **Boarding**: `BoardMetadata.chainAnchor` contains the blockchain anchor (txid:vout)
- **Offboarding**: `metadata_json` contains `offboard_txid` (confirmed in server JSON samples)
- **Exits**: `ExitTransactionStatus.allTransactionIds` contains all exit-related txids including claim

Note: `RoundMetadata.fundingTxid` exists but refers to the round's funding transaction, not individual user transactions. This is separate from offboarding.

## Design Decisions

### 1. Storage Strategy
**Decision**: Persist relationships in SwiftData using bidirectional search

**Rationale**: These are permanent relationships that should survive app restarts. Not temporary cache data.

**Implementation**: Add linking fields to `PersistentTransaction`:
- `parentTxid: String?` - References the parent movement txid (established link)
- `childTxids: [String]?` - Array of linked onchain txids (established links)

**Simplified Approach**: No separate expectation tracking needed. When either side arrives, we search for the matching counterpart and link if found. This keeps the data model simple while still handling race conditions correctly.

### 2. Linking Timing
**Decision**: Establish links during transaction upsert with bidirectional search

**Rationale**:
- Ensures links are created as soon as data is available
- Leverages existing parsing infrastructure
- Allows immediate use in UI without lazy loading complexity
- Handles race conditions where either side can arrive first

**Implementation Points**:
- `TransactionService+Upsert.swift` - When upserting movements
- `OnchainTransactionService.swift` - When upserting onchain transactions
- Bidirectional search: movements search for expected onchain, onchain searches for expected movements

**Race Condition Handling**:
Bidirectional search solves timing issues:
- **Movement arrives first**: Extracts linkable onchain txids → searches for matching onchain transactions → links if found
- **Onchain arrives first**: Searches unlinked movements → extracts their linkable txids → links if matches
- **Later arrival**: When the missing side arrives, the search finds it and establishes the link

**Performance Optimization**:
- Filter movements to only search unlinked ones (`childTxids == nil`)
- Movement count is typically small (tens to hundreds)
- Metadata extraction can be cached if needed

### 3. Activity List Display
**Decision**: Always show the movement with status indicators; hide linked onchain transactions

**Rationale**:
- Movement provides the most semantic meaning (boarding, offboarding, exit)
- Onchain transactions are implementation details
- Exit status indicators already show progression state
- Maintains single entry per logical operation

**Implementation**:
- Filter out transactions where `parentTxid != nil` in activity list query
- Show linked onchain details in transaction detail views
- Use exit status for additional state visualization

### 4. Metadata Field Discovery
**Confirmed**: The server JSON contains `offboard_txid` in metadata_json (see sample data below)

**Action Required**: Update `MovementMetadata.swift` to parse offboarding metadata:
- Add `OffboardMetadata` struct
- Parse `offboard_txid` field
- Make available via `MovementMetadata.asOffboard`

## Boarding

Movement data sample:
{
    "completed_at" : "2026-04-26T18:14:45.349143+02:00",
    "created_at" : "2026-04-26T12:44:22.699948+02:00",
    "effective_balance_sats" : 100000,
    "exited_vtxo_ids" : [

    ],
    "id" : 3,
    "input_vtxo_ids" : [

    ],
    "intended_balance_sats" : 100000,
    "metadata_json" : "{\"chain_anchor\":\"03312c56aefe632deacb69c693ae9a41188ca4beee37e58c24fbe572449bdc03:0\",\"onchain_fee_sat\":213}",
    "offchain_fee_sats" : 0,
    "output_vtxo_ids" : [
      "da705ab69aeb49e009dfa9170c35bd64e65006009772f1373eee854100127bea:0"
    ],
    "received_on_addresses" : [

    ],
    "sent_to_addresses" : [

    ],
    "status" : "successful",
    "subsystem_kind" : "board",
    "subsystem_name" : "bark.board",
    "updated_at" : "2026-04-26T12:44:22.721039+02:00"
}

Linking logic:
The "chain_anchor" (format <txid>:<vout>) in "metadata_json" contains the onchain transaction ID.

## Offboarding

Movement data sample:

{
    "completed_at" : "2026-04-27T12:34:34.621870+02:00",
    "created_at" : "2026-04-27T12:26:36.909650+02:00",
    "effective_balance_sats" : -50338,
    "exited_vtxo_ids" : [

    ],
    "id" : 5,
    "input_vtxo_ids" : [
      "81ff674363e31ec095fcd7bbdbbc543a49248da4cf816648913e7da6517efd36:0"
    ],
    "intended_balance_sats" : -50000,
    "metadata_json" : "{\"offboard_txid\":\"9be422dd30750e2e19943422dbddf844801ffb64162176a61cc8ca75887ddf92\",\"offboard_vtxos\":[\"a5e8c5ba0993bfeb9d052669b5295839eeb76fa6982ea56d1d72666c130b435d:0\"],\"offboard_tx\":\"02000000000101050924adc567115d614ef1db5a344410d2c75077197bd472db61e1cf4cded3d00000000000fdffffff0350c3000000000000225120a2e9d79b06b8af7740b8357f92130c92f85b4d85b24238e265b056349a34aa6b4a0100000000000022512063010323e8f16c42792fa5d83f880fe9ace577e9c2ec4b803bdd82746a769e4db0bb0000000000002251204eabb85f85300d7bf93597c04daa3e4406b008bffaa648a69e0825f26e20e41301408ad558da4985641543094f54ebd0c34a3ce01c4e1c6d960c3e4acb88b5eb5f3b5162a243788ebd4feec58553cc675fdeb7c543a45bb10b3c041afa9c964e29b0519b0400\"}",
    "offchain_fee_sats" : 338,
    "output_vtxo_ids" : [
      "20792afb21e185334fdd47a9caed7925d94e9702a5d9d5da0233d4455cb856f3:0"
    ],
    "received_on_addresses" : [

    ],
    "sent_to_addresses" : [
      "{\"type\":\"bitcoin\",\"value\":\"tb1p5t5a0xcxhzhhws9cx4leyycvjtu9knv9kfpr3cn9kptrfx354f4sy5nhgc\"}"
    ],
    "status" : "successful",
    "subsystem_kind" : "send_onchain",
    "subsystem_name" : "bark.offboard",
    "updated_at" : "2026-04-27T12:34:34.601088+02:00"
}

Linking logic:
"offboard_txid" (format <txid>:<vout>) in "metadata_json" contains the onchain transaction ID.

## Unilateral exits

Unilateral exits have more data to work with:
- A movement
- Exit status (see ExitTransactionStatus, ExitTransactionStatus_State.md, ExitTransactionStatus_History.md)
- Intermediate onchain transactions
- Claim onchain transaction

Movement data sample:
  
{
    "completed_at" : "2026-04-24T14:58:55.074792+02:00",
    "created_at" : "2026-04-24T14:58:55.068777+02:00",
    "effective_balance_sats" : -100000,
    "exited_vtxo_ids" : [

    ],
    "id" : 2,
    "input_vtxo_ids" : [
      "4e216cfdce303ff317571b85ce7bab4ba0e875e5fc4c82f16ba221152e30f275:0"
    ],
    "intended_balance_sats" : -100000,
    "metadata_json" : "{}",
    "offchain_fee_sats" : 0,
    "output_vtxo_ids" : [

    ],
    "received_on_addresses" : [

    ],
    "sent_to_addresses" : [
      "{\"type\":\"bitcoin\",\"value\":\"tb1plmgjlpcatww4x7zlwl33uvstelxkjvsz32z4ksrkv3w964vwtgmsf668fm\"}"
    ],
    "status" : "successful",
    "subsystem_kind" : "start",
    "subsystem_name" : "bark.exit",
    "updated_at" : "2026-04-24T14:58:55.074792+02:00"
}

Linking logic:
The state and history in the exit status contain the onchain transaction Ids. ExitTransactionStatus has a parsed state to access them.

## Implementation Plan

### Phase 1: Data Model Updates

**File**: `Shared/Models/PersistentTransaction.swift`

Add relationship fields:
```swift
// Established links (populated when both sides exist and linked)
@Attribute(.optional)
var parentTxid: String?

@Attribute(.optional)
var childTxids: [String]?
```

**Notes**:
- `parentTxid` is set on onchain transactions, references the movement txid
- `childTxids` is set on movements, contains array of linked onchain txids (with "onchain_" prefix)
- Both fields are `nil` until the link is established

### Phase 2: Metadata Parser Enhancement

**File**: `Shared/Services/Transactions/MovementMetadata.swift`

Add OffboardMetadata:
```swift
struct OffboardMetadata: Codable {
    let offboardTxid: String
    let offboardVtxos: [String]?
    let offboardTx: String?

    enum CodingKeys: String, CodingKey {
        case offboardTxid = "offboard_txid"
        case offboardVtxos = "offboard_vtxos"
        case offboardTx = "offboard_tx"
    }
}

extension MovementMetadata {
    var asOffboard: OffboardMetadata? {
        try? JSONDecoder().decode(OffboardMetadata.self, from: Data(rawJson.utf8))
    }
}
```

### Phase 3: Transaction Linking Service

**New File**: `Shared/Services/Transactions/TransactionLinkingService.swift`

Core responsibilities:
1. Extract linkable transaction IDs from movements
2. Search for matching transactions bidirectionally
3. Establish links when both sides exist
4. Handle all categories: boarding, offboarding, exits

Key methods:
```swift
class TransactionLinkingService {
    // Extract onchain txids from movement metadata/exit status
    func extractLinkableTransactionIds(
        from movement: PersistentTransaction,
        exitStatus: ExitTransactionStatus?
    ) -> [String]

    // Called when upserting a movement
    func establishLinksForMovement(movementTxid: String, context: ModelContext)

    // Called when upserting an onchain transaction
    func establishLinksForOnchain(onchainTxid: String, context: ModelContext)

    // Core linking logic - establishes bidirectional link
    private func linkParentToChild(
        parent: PersistentTransaction,
        child: PersistentTransaction,
        onchainTxid: String
    )

    // Search for parent movement that should link to this onchain txid
    private func findParentMovement(
        for onchainTxid: String,
        context: ModelContext
    ) -> PersistentTransaction?
}
```

**Linking Flow - Movement Arrives**:
1. Extract linkable onchain txids from metadata/exit status
2. For each txid:
   - Check if `onchain_{txid}` exists in database
   - If exists: establish link immediately
   - If not exists: no action (link will be established when onchain arrives)

**Linking Flow - Onchain Arrives**:
1. Extract actual txid (remove "onchain_" prefix)
2. Fetch all unlinked movements (where `childTxids == nil`)
3. For each movement:
   - Extract its linkable txids
   - If contains current txid: establish link and break
4. If no match found: no action (not all onchain txs have parent movements)

**Extraction Logic by Category**:
- **Boarding**: Parse `chainAnchor` from BoardMetadata, extract txid portion (before colon)
- **Offboarding**: Parse `offboardTxid` from OffboardMetadata
- **Exit**: Query `ExitTransactionStatus.allTransactionIds` for all exit-related txids

**Performance Notes**:
- Movement search is filtered to unlinked movements only
- Typical movement count: tens to hundreds
- Metadata parsing happens once per movement during search

### Phase 4: Integration into Upsert

**File**: `Shared/Services/Transactions/TransactionService+Upsert.swift`

After upserting movement transactions:
```swift
// After creating/updating PersistentTransaction for movement
let movementTxid = "movement_\(movement.id)"

// Attempt to link with matching onchain transactions
linkingService.establishLinksForMovement(
    movementTxid: movementTxid,
    context: modelContext
)
```

**File**: `Shared/Services/Onchain/OnchainTransactionService.swift`

After upserting onchain transactions:
```swift
// After creating PersistentTransaction for onchain tx
let onchainTxid = "onchain_\(onchainTransaction.txid)"

// Attempt to find and link parent movement
linkingService.establishLinksForOnchain(
    onchainTxid: onchainTxid,
    context: modelContext
)
```

**Key Points**:
- Linking happens immediately after upsert
- Idempotent: safe to call multiple times (checks if already linked)
- No expectations to store - just direct search and link

### Phase 5: Activity List Filtering

**File**: `ArkeMobile/Views/Activity/TransactionList_iOS.swift`

Update query to exclude child transactions:
```swift
@Query(
    filter: #Predicate<PersistentTransaction> { transaction in
        transaction.parentTxid == nil
    },
    sort: \PersistentTransaction.date,
    order: .reverse
)
private var allTransactions: [PersistentTransaction]
```

**File**: `ArkeDesktop/Views/Activity/TransactionList.swift`

Apply same filter for desktop.

### Phase 6: TransactionModel Updates

**File**: `Shared/Models/TransactionModel.swift`

Add computed properties to access linked transactions:
```swift
extension TransactionModel {
    // Fetch linked onchain transactions
    var linkedOnchainTransactions: [PersistentTransaction] {
        guard let childTxids = persistentTransaction.childTxids else { return [] }
        // Fetch from SwiftData using childTxids
        return fetchTransactions(txids: childTxids, context: modelContext)
    }

    // Check if any linked onchain transaction is confirmed
    var hasConfirmedOnchain: Bool {
        linkedOnchainTransactions.contains { $0.confirmationHeight != nil }
    }

    // Get confirmation details from linked onchain
    var onchainConfirmation: (height: UInt32, timestamp: Date)? {
        linkedOnchainTransactions
            .compactMap { tx -> (UInt32, Date)? in
                guard let height = tx.confirmationHeight,
                      let timestamp = tx.date else { return nil }
                return (height, timestamp)
            }
            .first
    }
}
```

### Phase 7: Transaction List Item Updates

**Files**:
- `Shared/Models/TransactionModel.swift` (status display logic)
- `ArkeMobile/Views/Activity/TransactionListItem.swift` (if exists)

Update status/display logic to incorporate linked onchain data:
```swift
// Update transaction display to show confirmation status from linked onchain
var displayStatus: String {
    if hasConfirmedOnchain {
        return "Confirmed"
    } else if status == .pending && !linkedOnchainTransactions.isEmpty {
        return "Onchain Pending"
    }
    // ... existing status logic
}

// Update icon/color based on confirmation
var statusColor: Color {
    if hasConfirmedOnchain {
        return .green
    }
    // ... existing color logic
}
```

**Notes**:
- Movements show combined status (movement + linked onchain confirmation)
- Exit movements can show exit status + claim confirmation
- Boarding shows movement + onchain confirmation status

### Phase 8: Detail View Enhancements

**Files**:
- `ArkeMobile/Views/Activity/TransactionDetailView_iOS.swift`
- `ArkeDesktop/Views/Activity/TransactionDetailView.swift`

Display linked onchain transaction details:
```swift
// Onchain Confirmation Section (for movements with linked onchain)
if let childTxids = transaction.childTxids, !childTxids.isEmpty {
    Section("Onchain Confirmations") {
        ForEach(transaction.linkedOnchainTransactions, id: \.txid) { onchainTx in
            VStack(alignment: .leading, spacing: 8) {
                // Transaction ID
                LabeledContent("Transaction ID") {
                    Text(onchainTx.txid.replacingOccurrences(of: "onchain_", with: ""))
                        .monospaced()
                }

                // Confirmation status
                if let height = onchainTx.confirmationHeight {
                    LabeledContent("Block Height") {
                        Text("\(height)")
                    }
                }

                // Fees
                if let fee = onchainTx.fees {
                    LabeledContent("Network Fee") {
                        Text("\(fee) sats")
                    }
                }

                // Timestamp
                LabeledContent("Confirmed At") {
                    Text(onchainTx.date, style: .date)
                }
            }
        }
    }
}
```

## Manual Testing

### Test Scenarios
1. **Boarding**: Board bitcoin onchain → verify single entry in activity list, onchain details in detail view
2. **Offboarding**: Offboard to bitcoin address → verify single entry with onchain confirmation details
3. **Exit**: Start and claim unilateral exit → verify movement shown with exit status, all intermediate/claim transactions hidden
4. **Race Conditions**:
   - Board bitcoin, check before onchain confirms → verify movement shows without onchain link
   - Wait for confirmation → verify link established automatically
5. **Detail Views**: Check transaction detail views show complete onchain data for linked transactions

### Validation Checklist
- [ ] No duplicate entries in activity list for boarding
- [ ] No duplicate entries in activity list for offboarding
- [ ] Exit movements shown with intermediate/claim transactions hidden
- [ ] `childTxids` populated on movements after linking
- [ ] `parentTxid` populated on onchain transactions after linking
- [ ] Links are bidirectional (both sides reference each other)

## Success Criteria

- [ ] No duplicate entries for boarding operations
- [ ] No duplicate entries for offboarding operations
- [ ] Exit movements shown with all intermediate/claim transactions hidden
- [ ] Detail views show complete onchain transaction information
- [ ] Existing transactions migrated and linked correctly
- [ ] Performance remains acceptable with filtering

