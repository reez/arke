# SendView Integration Quick Reference

## For Developers

### What Changed?

**Before:**
- Manual address type detection (`isBitcoinAddress()`, `isLightningInvoice()`)
- Simple balance checks based on address prefix
- Direct routing to manager methods
- Generic error messages

**After:**
- Unified payment request parsing
- Intelligent destination ranking with viability checks
- Context-aware balance display
- Detailed error messages with specific reasons
- Support for multi-destination payment requests (BIP-21)
- User choice when multiple payment methods available

### Key New Concepts

1. **PaymentRequest**: Unified representation of any payment input (single address, BIP-21, etc.)
2. **PaymentDestination**: Individual payment option with format, network, and address
3. **RankedDestination**: Destination with viability analysis, balance info, and priority
4. **PaymentContext**: Current wallet state used for ranking decisions

### State Variables Added

```swift
@State private var currentPaymentRequest: PaymentRequest?
@State private var selectedDestination: PaymentDestination?
@State private var rankedDestinations: [PaymentDestinationSelector.RankedDestination] = []
@State private var showDestinationPicker = false
```

### How Selection Works

```
User Input → Parse → Rank → Auto-select Optimal → User Can Change → Send
```

1. **Parse**: Every input becomes a `PaymentRequest`
2. **Rank**: All destinations evaluated for viability, fees, priority
3. **Auto-select**: First viable destination chosen automatically
4. **User Can Change**: If multiple viable options, user sees "Change" button
5. **Send**: Routes to correct manager method based on destination format

### When to Show Picker

```swift
if hasMultipleViableDestinations {
    // Show "Change" button
    // User can tap to open PaymentDestinationPickerView
} else {
    // Single viable option or no viable options
    // Just show indicator or error
}
```

### Accessing Balance Information

```swift
// Old way
if AddressValidator.isBitcoinAddress(recipient) {
    return manager.onchainBalance?.trustedSpendableSat ?? 0
}

// New way
guard let destination = selectedDestination else { return 0 }
return PaymentDestinationSelector.availableBalance(
    for: destination, 
    context: paymentContext
) ?? 0
```

### Error Messages

Errors now include viability reasons:

```swift
// Old
"Amount exceeds balance"

// New
"Amount + fees (100500 sats) exceeds available balance (100000 sats)"

// Or for no viable destinations
"Cannot send payment. 
 Ark: Insufficient balance (50000 < 500000 sats); 
 Bitcoin: Ark server not connected"
```

---

## For Designers

### New UI Elements

#### 1. Payment Method Indicator
**Location:** Below address field, above amount field  
**Shows when:** Destination is selected  
**Content:**
- Icon (colored by payment type)
- "Paying via [Format]" text
- "Change" button (if multiple options available)

**Visual:**
```
┌────────────────────────────────────────┐
│ 🟣 Paying via Ark            Change > │
└────────────────────────────────────────┘
```

#### 2. Payment Destination Picker Sheet
**Trigger:** Tapping "Change" button  
**Content:**
- "Available Payment Methods" section
  - Recommended option with ⭐ badge
  - Other viable options
  - Shows balance source, estimated fee
- "Unavailable" section (dimmed)
  - Shows why each is unavailable

**Visual:**
```
╔═══════════════════════════════════════╗
║ Choose Payment Method                 ║
╠═══════════════════════════════════════╣
║ Available Payment Methods             ║
║                                       ║
║ ┌─────────────────────────────────┐  ║
║ │ 🟣 Ark            ⭐ RECOMMENDED│  ║
║ │ tark1qxy...example              │  ║
║ │ 💼 Ark Balance · No fees        │  ║
║ │ ✓ Sufficient balance            │  ║
║ └─────────────────────────────────┘  ║
║                                       ║
║ ┌─────────────────────────────────┐  ║
║ │ ⚡ Lightning Invoice             │  ║
║ │ lntb100...example                │  ║
║ │ 💼 Ark Balance (via Lightning)  │  ║
║ │    ~100 sats fee                │  ║
║ │ ✓ Sufficient balance            │  ║
║ └─────────────────────────────────┘  ║
║                                       ║
║ Unavailable                           ║
║                                       ║
║ ┌─────────────────────────────────┐  ║
║ │ ₿ Bitcoin (dimmed)              │  ║
║ │ tb1qw50...pjzsx                 │  ║
║ │ 💼 Bitcoin Balance              │  ║
║ │    ~500 sats fee                │  ║
║ │ ⚠️ Insufficient balance          │  ║
║ └─────────────────────────────────┘  ║
╚═══════════════════════════════════════╝
```

#### 3. Enhanced Balance Display
**Location:** Below amount field  
**Changes:**
- Shows specific balance source (Ark/Bitcoin/Lightning)
- Shows estimated fee
- Updates when destination changes

**Before:**
```
Available: 1,000,000 sats (Spending balance)
```

**After:**
```
Available: 1,000,000 sats (Ark Balance) · No fees
```

#### 4. Improved Error Messages
**Location:** Below amount field  
**Changes:**
- Specific reasons for each destination
- Actionable information
- Multiple destination failures shown together

### Color Scheme

| Format | Icon | Color |
|--------|------|-------|
| Ark | `cube.fill` | Purple |
| Lightning | `bolt.fill` | Orange |
| Bitcoin | `bitcoinsign.circle.fill` | Orange |
| Silent Payments | `eye.slash.fill` | Blue |
| BIP-353 | `at.circle.fill` | Green |

### Interaction Flow

```
User enters address
    ↓
[If single address]
  → Shows indicator: "Paying via [Type]"
  → No Change button
    
[If BIP-21 with multiple addresses]
  → Shows indicator: "Paying via Ark · Change"
  → Tapping Change opens picker sheet
  → User selects different method
  → Indicator updates
  
[If no viable destinations]
  → Shows error explaining why
  → Send button disabled
```

---

## For QA

### Critical Test Paths

1. **Single Address Happy Path**
   - Enter Bitcoin address → Should auto-select → Send works

2. **Multi-Destination Happy Path**
   - Enter BIP-21 → Should auto-select optimal → Can change → Send works

3. **Insufficient Balance**
   - Enter request exceeding balance → Should show specific error → Send disabled

4. **Network Mismatch**
   - Enter mainnet address on testnet → Should show error → Send disabled

5. **Clipboard Detection**
   - Copy address → Open SendView → Banner appears → Use works

6. **Destination Switching**
   - Enter BIP-21 → Ark selected → Tap Change → Select Bitcoin → Send uses Bitcoin

### What to Look For

#### Visual Issues
- [ ] Indicator positioning and padding
- [ ] Icons display correctly for each format
- [ ] Colors match design spec
- [ ] "Change" button only appears when appropriate
- [ ] Picker sheet layout clean and readable
- [ ] Error messages properly formatted

#### Functional Issues
- [ ] Parsing fails silently (should show error)
- [ ] Wrong balance shown for destination type
- [ ] Send button enabled when it shouldn't be
- [ ] Destination selection doesn't update UI
- [ ] Picker selection doesn't persist
- [ ] Network filtering not working

#### Edge Cases
- [ ] Very long addresses truncate properly
- [ ] Multiple rapid destination changes
- [ ] Opening/closing picker multiple times
- [ ] Network change during send flow
- [ ] Balance updates during send flow
- [ ] Contact selection with prefilled recipient

### Regression Risks

Areas that might break:

1. **Contact Flow**: Prefilled recipients with ContactInfoBanner
2. **Clipboard Flow**: Automatic detection and banner display
3. **Amount Pre-filling**: Lightning invoices with embedded amounts
4. **Send Modal**: Progress, success, error states
5. **Balance Display**: Interaction with WalletManager updates

---

## For Product

### User-Facing Changes

#### What Users Will Notice

1. **Better Payment Method Selection**
   - App automatically chooses lowest-fee option
   - Users can see all available options
   - Clear explanation of why some options unavailable

2. **More Informative Balance Display**
   - Shows which balance will be used
   - Shows estimated fees before sending
   - Updates as user changes payment method

3. **Clearer Error Messages**
   - Specific reasons (not just "insufficient balance")
   - Shows exactly how much is needed
   - Explains server/network issues

4. **Support for Advanced Payment Requests**
   - BIP-21 URIs with multiple payment options
   - Automatically chooses best option
   - Users can override if desired

#### User Benefits

1. **Lower Fees**: Automatically selects lowest-fee option (typically Ark)
2. **More Choice**: Can manually choose Bitcoin for security, Lightning for speed
3. **Better Errors**: Understand exactly why a payment can't be sent
4. **Smoother Flow**: Pre-filled amounts, automatic selections, fewer steps

### Feature Flags

No feature flags needed - this is a pure enhancement to existing functionality.

### Metrics to Track

- **Destination selection distribution**: How often is each format chosen?
- **Manual override rate**: How often do users tap "Change"?
- **Error rate by destination**: Which destinations fail most often?
- **Fee savings**: Compare fees before/after (should decrease with Ark preference)

### Known Limitations

1. **Server status**: Currently hardcoded `arkServerConnected = true`  
   → TODO: Get real status from WalletManager

2. **Lightning capability**: Currently hardcoded `hasLightningCapability = true`  
   → TODO: Get real status from WalletManager

3. **User preferences**: Currently uses `.default` preferences  
   → Future: Allow users to customize priority order, reserves, etc.

4. **Fee estimation**: Still shows "Fee calculation not implemented yet" note  
   → Future: Replace placeholder fees with real estimation

---

## For Support

### Common User Questions

**Q: Why did it choose Ark instead of Bitcoin?**  
A: The app automatically selects the lowest-fee option. Ark typically has no fees, while Bitcoin has network fees. You can tap "Change" to use Bitcoin if preferred.

**Q: I have enough money, why can't I send?**  
A: Check which balance is being used. If sending to a Bitcoin address, you need Bitcoin balance. If sending to Ark, you need Ark balance. The error message shows specifically which balance is insufficient.

**Q: What does "Paying via Ark" mean?**  
A: This shows which payment method will be used. Different payment methods use different balances and have different fees.

**Q: The "Change" button doesn't appear**  
A: The "Change" button only appears when multiple payment methods are available and viable. If you're sending to a single Bitcoin address, only Bitcoin is available.

**Q: Why is the amount field disabled?**  
A: Some Lightning invoices have the amount embedded. The recipient set the amount, so you can't change it.

### Troubleshooting

**Issue: Send button disabled even with sufficient balance**  
Check:
1. Is a destination selected? (Indicator visible below address field)
2. Is amount filled in? (Unless Lightning invoice with embedded amount)
3. Check console logs for viability errors

**Issue: Wrong balance shown**  
- Clear recipient field and re-enter
- Verify network matches address (testnet vs. mainnet)
- Check console logs for ranking output

**Issue: Picker shows all destinations as unavailable**  
- Likely insufficient balance across all methods
- Check total balance vs. requested amount
- Consider network fees

**Issue: Network mismatch error**  
- Address is for different network (mainnet/testnet/signet)
- Verify wallet is on correct network
- Use address matching your network

---

## Quick Debug

### Enable Debug Logging

Already enabled! Look for:
- 🔍 `[SendView]` - Parsing and clipboard detection
- 🎯 `[SendView]` - Ranking results
- ✨ `[SendView]` - Destination selection
- ⚠️ `[SendView]` - Errors and warnings

### Common Console Patterns

**Successful Parse:**
```
🔍 [SendView] Parsed payment request details:
   Destinations: 1
   ...
🎯 [SendView] Ranked destinations:
   ✓ [1] Bitcoin
   ...
✨ [SendView] Auto-selected optimal destination: Bitcoin
```

**Parsing Failure:**
```
🔍 [SendView] Could not parse recipient as payment request: [address]
```

**No Viable Destinations:**
```
🎯 [SendView] Ranked destinations:
   ✗ [1] Ark
      Reason: Insufficient balance (50000 < 500000 sats)
   ✗ [2] Bitcoin
      Reason: Insufficient balance (100000 < 500500 sats)
⚠️ [SendView] No viable destinations found
```

### Break Points

Useful break points for debugging:

1. `handleRecipientChange()` - When address changes
2. `sendPayment()` - When send button tapped
3. `rankDestinations()` - Destination ranking logic
4. `checkViability()` - Viability checks

---

## Migration Notes

### No Breaking Changes

This is a pure enhancement. All existing functionality preserved:
- Single addresses still work
- Contact selection still works
- Clipboard detection still works
- Amount pre-filling still works

### Backward Compatibility

Old address validation functions still exist but are now used internally:
- `AddressValidator.isBitcoinAddress()` - Still works
- `AddressValidator.isLightningInvoice()` - Still works
- `AddressValidator.parsePaymentRequest()` - Enhanced, not replaced

### Data Migration

None needed - no persistent state changes.

### API Changes

None - `WalletManager` interface unchanged.

---

## Resources

- [Full Implementation Summary](SENDVIEW_INTEGRATION_SUMMARY.md)
- [Flow Diagrams](SENDVIEW_FLOW_DIAGRAMS.md)
- [Test Scenarios](SENDVIEW_TEST_SCENARIOS.md)
- [PaymentDestinationSelector Examples](PaymentDestinationSelectorExamples.swift)
- [Selector README](PAYMENT_DESTINATION_SELECTOR_README.md)
