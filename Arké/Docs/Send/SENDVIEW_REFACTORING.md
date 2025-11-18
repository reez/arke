# SendView Refactoring Summary

## Date: November 18, 2025

## Problem Statement

The original `SendView` had a single `recipient` TextField that was trying to serve multiple conflicting purposes:

1. **Input field** for manual address entry
2. **Display field** showing the full BIP-21 URI after selection
3. **Parser source** for extracting payment destinations
4. **Context holder** for maintaining payment alternatives

This led to confusing UX where users would see the full BIP-21 URI (e.g., `bitcoin:tb1p...?amount=0.001&ark=tark1...`) in the input field, even after selecting a specific payment method.

## Solution: State-Based Component Architecture

We separated concerns by introducing **two distinct modes** with dedicated UI components:

### Mode 1: Manual Entry (`RecipientInputSection`)
- Clean input field for typing/pasting addresses
- Real-time validation feedback
- "Continue" button to lock in the payment request
- Used when: User is entering an address or viewing clipboard banner

### Mode 2: Confirmed Destination (`ConfirmedDestinationCard`)
- **Non-editable** card showing the selected payment destination
- Displays only the actual address being used (e.g., `tark1pm6sr0fpz...`)
- Shows payment metadata (label, message, amount)
- "Change" button for switching between payment methods
- "Clear" button to return to manual entry
- Used when: Payment destination is locked in and ready to send

### Shared Component: `AmountInputSection`
- Extracted amount input logic to separate component
- Handles locked amounts (Lightning invoices with embedded amounts)
- Shows balance and fee information

## Key Changes

### New Files Created

1. **`RecipientInputSection.swift`**
   - Handles manual address input
   - Validates payment requests in real-time
   - Shows helpful feedback (valid/invalid/idle states)

2. **`ConfirmedDestinationCard.swift`**
   - Displays locked-in payment destination
   - Shows only the selected address (not full BIP-21 URI)
   - Manages payment method switching
   - Displays payment metadata

3. **`AmountInputSection.swift`**
   - Reusable amount input component
   - Handles amount locking for invoices
   - Shows balance and fee information

### SendView Changes

#### State Management
```swift
// NEW: Mode tracking
enum Mode {
    case manualEntry
    case confirmedDestination
}
@State private var mode: Mode = .manualEntry

// NEW: Separate input state for manual entry
@State private var manualInput = ""

// REMOVED: Single recipient field
// @State private var recipient = ""

// REMOVED: No longer needed
// @State private var clipboardRawString: String?
// @State private var isManualDestinationSelection = false
```

#### New Functions

1. **`lockInPaymentRequest(_ paymentRequest: PaymentRequest)`**
   - Parses and ranks payment destinations
   - Selects optimal destination
   - Switches to `.confirmedDestination` mode
   - Pre-fills amount if specified in request

2. **`clearAll()`**
   - Resets all state
   - Returns to `.manualEntry` mode
   - Clears errors and selections

3. **`handleInitialSetup()`**
   - Replaces inline `onAppear` logic
   - Handles pre-filled recipients
   - Checks clipboard for payment requests

#### Removed Functions
- `handleRecipientChange()` - Logic moved to `RecipientInputSection` and `lockInPaymentRequest()`
- `iconForDestination()` - Moved to `ConfirmedDestinationCard`
- `colorForDestination()` - Moved to `ConfirmedDestinationCard`

#### Updated Computed Properties
- `isLightningInvoiceWithAmount` → `isAmountLocked` + `lockedAmountReason`
- More descriptive names for better clarity

## User Flow Improvements

### Before (Confusing)
```
1. User copies BIP-21 URI to clipboard
2. Opens SendView, sees clipboard banner
3. Clicks "Use Payment Request"
4. TextField shows: "bitcoin:tb1p...?amount=0.001&ark=tark1..."  ← Confusing!
5. Changes payment method
6. TextField still shows full BIP-21 URI  ← Still confusing!
```

### After (Clear)
```
1. User copies BIP-21 URI to clipboard
2. Opens SendView, sees clipboard banner
3. Clicks "Use Payment Request"
4. Card displays: "🟣 Ark Address: tark1pm6sr0fpz..."  ← Clear!
5. Changes payment method
6. Card updates: "⚡ Lightning Invoice: lnbc1..."  ← Clear!
7. Can click "Clear" to start over with manual entry
```

## Benefits

### 1. **Clarity**
- Users see exactly what address will be used
- No confusion with BIP-21 URIs or raw addresses
- Clear distinction between input and confirmation

### 2. **Simplicity**
- Each component has a single responsibility
- Less state management complexity
- Easier to reason about

### 3. **Maintainability**
- Components are isolated and reusable
- Easier to test individually
- Clear separation of concerns

### 4. **Extensibility**
- Easy to add new entry methods (QR scanning, NFC, etc.)
- Can add more sophisticated validation in `RecipientInputSection`
- Can enhance `ConfirmedDestinationCard` with more metadata

### 5. **Better UX**
- Progressive disclosure (amount only shown when destination confirmed)
- Clear affordances for changing payment methods
- Easy to start over with "Clear" button

## Testing Checklist

- [ ] Manual address entry
- [ ] Clipboard banner → Use payment request
- [ ] Pre-filled recipient via navigation
- [ ] Contact selection
- [ ] BIP-21 with multiple payment options
- [ ] Lightning invoice with embedded amount
- [ ] Switching payment methods
- [ ] Clearing and starting over
- [ ] Error handling for invalid addresses
- [ ] Network compatibility checks
- [ ] Amount pre-filling
- [ ] Send button enabled/disabled states

## Future Enhancements

1. **QR Code Scanning**
   - Add camera button to `RecipientInputSection`
   - Parse scanned QR codes as payment requests

2. **Contact Browser**
   - Add "Browse Contacts" button in manual entry
   - Show contact picker sheet

3. **Recent Recipients**
   - Show list of recent payment destinations
   - Quick-select from history

4. **Payment Request Preview**
   - In `RecipientInputSection`, show rich preview when valid
   - Preview all available payment options before locking in

5. **Edit Destination**
   - Allow editing destination in confirmed mode
   - Return to manual entry with pre-filled value

## Migration Notes

### No Breaking Changes
- All existing functionality preserved
- Same initialization parameters
- Same navigation behavior
- Backward compatible with all entry points

### Key Differences
- `recipient` state variable removed (replaced with `manualInput`)
- UI now uses mode-based switching instead of conditional rendering
- Address display shows only selected destination, not full BIP-21 URI
