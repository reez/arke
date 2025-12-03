# SendView Architecture Diagram

## Component Hierarchy

```
SendView (Parent Container)
│
├── Mode: .manualEntry
│   ├── ContactInfoBanner? (if pre-filled contact)
│   ├── ClipboardAddressBanner? (if clipboard has payment request)
│   └── RecipientInputSection
│       ├── TextField (manual input)
│       ├── Validation feedback
│       └── Continue button
│
└── Mode: .confirmedDestination
    ├── ContactInfoBanner? (if pre-filled contact)
    ├── ConfirmedDestinationCard
    │   ├── Payment destination display (read-only)
    │   ├── Metadata (label, message)
    │   ├── Change button → PaymentDestinationPicker
    │   └── Clear button → return to .manualEntry
    ├── AmountInputSection
    │   ├── Amount TextField
    │   ├── Balance info
    │   └── Fee estimation
    ├── ErrorView? (if error)
    └── Send button
```

## State Flow Diagram

```
┌─────────────────┐
│  Initial Load   │
└────────┬────────┘
         │
         ├──[Has prefilledRecipient]──→ Parse → lockInPaymentRequest()
         │                                            ↓
         └──[No prefill]──→ checkClipboard()    [Mode: .confirmedDestination]
                                   ↓
                        ┌──────────┴──────────┐
                        │                     │
                   [Found]              [Not Found]
                        │                     │
                        ↓                     ↓
              clipboardPaymentRequest   [Mode: .manualEntry]
                        │                     │
                        │                     ↓
                        │         ┌─────────────────────────┐
                        │         │  RecipientInputSection  │
                        │         │                         │
                        │         │  User types/pastes      │
                        │         │  address or BIP-21 URI  │
                        │         └────────┬────────────────┘
                        │                  │
                        ↓                  ↓
              ┌─────────────────────────────────────┐
              │    ClipboardAddressBanner           │
              │                                     │
              │  User clicks "Use Payment Request"  │
              └────────┬────────────────────────────┘
                       │
                       ↓
           lockInPaymentRequest(paymentRequest)
                       │
                       ├──→ Parse destinations
                       ├──→ Rank by viability
                       ├──→ Select optimal
                       ├──→ Pre-fill amount (if any)
                       └──→ mode = .confirmedDestination
                                    ↓
              ┌─────────────────────────────────────┐
              │   ConfirmedDestinationCard          │
              │                                     │
              │   Shows: Selected destination only  │
              │          (not full BIP-21 URI)      │
              └────────┬─────────┬──────────────────┘
                       │         │
            [Change]───┘         └───[Clear]
                │                        │
                ↓                        ↓
    PaymentDestinationPicker     clearAll()
    (user selects new dest)              │
                │                        └──→ mode = .manualEntry
                │                             (reset state)
                └──→ Update selectedDestination
                     (preserves BIP-21 context)
                                ↓
                     ┌──────────────────────┐
                     │  AmountInputSection  │
                     │                      │
                     │  User enters amount  │
                     └──────────┬───────────┘
                                │
                                ↓
                        ┌───────────────┐
                        │  Send Button  │
                        └───────┬───────┘
                                │
                                ↓
                        sendPayment()
                                │
                        ┌───────┴───────┐
                        │               │
                  [Success]        [Error]
                        │               │
                        ↓               ↓
                   dismiss()    Show error in ErrorView
```

## Data Flow: BIP-21 URI Handling

### Example: `bitcoin:tb1p...?amount=0.001&ark=tark1...&lightning=lnbc1...`

```
┌────────────────────────────────────────────────────────────────┐
│ Step 1: User Copies BIP-21 to Clipboard                        │
│ Raw string: "bitcoin:tb1p...?amount=0.001&ark=tark1..."        │
└──────────────────────────────┬─────────────────────────────────┘
                               │
                               ↓
┌────────────────────────────────────────────────────────────────┐
│ Step 2: checkClipboardForAddress()                             │
│ - Parses raw string → PaymentRequest                           │
│ - Extracts: 3 destinations (Bitcoin, Ark, Lightning)           │
│ - Extracts: amount = 100000 sats, label, message               │
│ - Stores as: clipboardPaymentRequest                           │
└──────────────────────────────┬─────────────────────────────────┘
                               │
                               ↓
┌────────────────────────────────────────────────────────────────┐
│ Step 3: ClipboardAddressBanner Displays                        │
│ Shows:                                                          │
│   ⭐ Will pay via Ark (optimal)                                │
│   tark1pm6sr0fpz... (short address)                            │
│   Amount: 100000 sats                                          │
│   Alternative payment methods: Bitcoin, Lightning              │
│                                                                 │
│ [Use Payment Request] [X]                                      │
└──────────────────────────────┬─────────────────────────────────┘
                               │
                      [User clicks "Use"]
                               │
                               ↓
┌────────────────────────────────────────────────────────────────┐
│ Step 4: lockInPaymentRequest(paymentRequest)                   │
│ - currentPaymentRequest = paymentRequest                       │
│ - Ranks destinations:                                           │
│   ✓ Ark (viable, 500000 sats available, ~100 sat fee)         │
│   ✓ Lightning (viable, 300000 sats available, ~1 sat fee)     │
│   ✗ Bitcoin (insufficient balance)                             │
│ - selectedDestination = Ark (optimal)                          │
│ - amount = "100000" (pre-filled)                               │
│ - mode = .confirmedDestination                                 │
└──────────────────────────────┬─────────────────────────────────┘
                               │
                               ↓
┌────────────────────────────────────────────────────────────────┐
│ Step 5: ConfirmedDestinationCard Displays                      │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ Payment Destination                           [Clear]      │ │
│ │                                                             │ │
│ │ 🟣 Ark Address                                              │ │
│ │ tark1pm6sr0fpz...ghz7a2rx7w                                │ │
│ │                                                             │ │
│ │ 2 payment options available         [Change] →             │ │
│ └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ✅ Only shows selected address, NOT full BIP-21 URI            │
└──────────────────────────────┬─────────────────────────────────┘
                               │
                    [User clicks "Change"]
                               │
                               ↓
┌────────────────────────────────────────────────────────────────┐
│ Step 6: PaymentDestinationPickerView Opens                     │
│ Shows all viable destinations:                                 │
│   • ⚡ Lightning Invoice (recommended, lowest fees)            │
│   • 🟣 Ark Address (instant, low fees)                        │
│                                                                 │
│ [User selects Lightning]                                       │
└──────────────────────────────┬─────────────────────────────────┘
                               │
                               ↓
┌────────────────────────────────────────────────────────────────┐
│ Step 7: ConfirmedDestinationCard Updates                       │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ Payment Destination                           [Clear]      │ │
│ │                                                             │ │
│ │ ⚡ Lightning Invoice                                        │ │
│ │ lnbc1...xyz                                                 │ │
│ │                                                             │ │
│ │ 2 payment options available         [Change] →             │ │
│ └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ✅ Updates to show new address, preserves BIP-21 context       │
└─────────────────────────────────────────────────────────────────┘
```

## Key Architectural Decisions

### 1. Mode-Based Rendering
**Decision:** Use enum-based mode switching instead of complex conditionals

**Rationale:**
- Clearer state management
- Easier to reason about which UI is shown when
- Prevents impossible states (e.g., showing both input and confirmed card)
- More predictable behavior

### 2. Separate Components for Input vs Display
**Decision:** Create `RecipientInputSection` and `ConfirmedDestinationCard` as separate components

**Rationale:**
- Single Responsibility Principle
- Input and display have fundamentally different UX patterns
- Easier to test independently
- More reusable

### 3. PaymentRequest as Context Holder
**Decision:** Store full `PaymentRequest` in `currentPaymentRequest`, display only selected destination

**Rationale:**
- Preserves all BIP-21 alternatives
- Allows switching between payment methods without re-parsing
- Clean separation between data (full request) and view (selected destination)
- User never sees confusing raw URIs

### 4. lockInPaymentRequest() as Single Entry Point
**Decision:** All paths (clipboard, manual, prefilled) go through `lockInPaymentRequest()`

**Rationale:**
- Single source of truth for parsing and ranking logic
- Consistent behavior regardless of entry method
- Easier to debug (one function to trace)
- Reduces code duplication

### 5. Clear State Reset Function
**Decision:** `clearAll()` resets everything and returns to manual entry

**Rationale:**
- Users can easily start over
- Prevents stale state bugs
- Clear mental model: "Clear" means "start fresh"
- No partial state issues
```
