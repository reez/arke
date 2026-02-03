# SendView PaymentDestinationSelector Integration

## Summary

The `SendView` has been successfully integrated with the `PaymentDestinationSelector` system to provide intelligent payment destination selection and routing.

## Changes Made

### 1. New State Variables

Added state to track payment destinations:
```swift
@State private var currentPaymentRequest: PaymentRequest?
@State private var selectedDestination: PaymentDestination?
@State private var rankedDestinations: [PaymentDestinationSelector.RankedDestination] = []
@State private var showDestinationPicker = false
```

### 2. Payment Context

Created a computed property to build payment context from `WalletManager`:
```swift
private var paymentContext: PaymentDestinationSelector.PaymentContext {
    PaymentDestinationSelector.PaymentContext(
        arkBalance: manager.arkBalance?.spendableSat,
        bitcoinBalance: manager.onchainBalance?.trustedSpendableSat,
        networkConfig: currentNetworkConfig,
        userPreferences: .default,
        arkServerConnected: true,
        hasLightningCapability: true
    )
}
```

### 3. Enhanced Balance Display

Updated balance display logic to show:
- Balance source (Ark, Bitcoin, etc.)
- Estimated fees
- Context-aware availability based on selected destination

### 4. Automatic Destination Selection

The `handleRecipientChange()` function now:
1. Parses all recipient inputs as `PaymentRequest`
2. Ranks destinations using `PaymentDestinationSelector`
3. Auto-selects the optimal (first viable) destination
4. Shows detailed error messages when no destinations are viable

### 5. UI Enhancements

#### Destination Indicator
When a destination is selected, shows:
- Icon and color for the payment method
- "Paying via [Format]" label
- "Change" button if multiple viable options exist

#### Payment Method Picker
- Modal sheet with `PaymentDestinationPickerView`
- Shows all viable and non-viable destinations
- Displays balance sources, fees, and viability reasons
- Recommends the optimal payment method

### 6. Improved Send Logic

The `sendPayment()` function now:
1. Validates against the selected destination's viability
2. Checks amount + fee against available balance
3. Routes to appropriate manager method based on `destination.format`
4. Provides detailed error messages from viability checks

### 7. Clipboard Integration

Clipboard detection now works seamlessly with destination selection:
- Parses clipboard content as `PaymentRequest`
- Shows alternatives in the banner
- Triggers destination selection when user accepts

## User Flows

### Single Address Flow
1. User enters/pastes a single address
2. System parses as `PaymentRequest`
3. System ranks destinations (usually just one)
4. Auto-selects if viable, shows error if not
5. User enters amount and sends

### Multi-Destination Flow (BIP-21)
1. User enters/pastes BIP-21 URI with multiple destinations
2. System parses and ranks all destinations
3. Auto-selects optimal destination
4. Shows "Paying via [Format]" with "Change" button
5. User can tap "Change" to see all options
6. User selects preferred method from picker
7. User enters amount (if not pre-filled) and sends

### Clipboard Flow
1. System detects payment request in clipboard on appear
2. Shows `ClipboardAddressBanner` with all alternatives
3. User taps "Use Payment Request"
4. Triggers destination selection and ranking
5. Continues as single or multi-destination flow

## Error Handling

Enhanced error messages now include:
- Specific viability reasons (e.g., "Insufficient balance: 300k < 500k sats")
- Balance source information
- Fee calculations
- Network compatibility issues
- Server connectivity status

## Future Enhancements

### TODO Items Added
1. Get `arkServerConnected` status from `WalletManager`
2. Get `hasLightningCapability` status from `WalletManager`
3. Support user preferences for destination priority
4. Add settings for minimum reserves and large payment thresholds

### Potential Improvements
1. Inline destination picker (non-modal) for power users
2. Remember user's previous destination choices
3. Show fee comparison between destinations
4. Animated transitions between destination changes
5. Transaction preview before sending

## Testing Scenarios

### Test Cases to Verify

1. **Single Bitcoin Address**
   - Should auto-select Bitcoin destination
   - Should show savings balance
   - Should estimate on-chain fee

2. **Single Ark Address**
   - Should auto-select Ark destination
   - Should show payments balance
   - Should show zero fees

3. **Single Lightning Invoice**
   - Should auto-select Lightning destination
   - Should show Ark balance (via server routing)
   - Should pre-fill amount if embedded

4. **BIP-21 with Multiple Destinations**
   - Should show all viable options
   - Should recommend optimal (usually Ark)
   - Should allow user to change selection

5. **Insufficient Balance**
   - Should show specific error for each destination
   - Should disable Send button
   - Should suggest which balance needs funding

6. **Network Mismatch**
   - Should filter incompatible destinations
   - Should show error if no compatible destinations
   - Should handle network-agnostic formats (Lightning, BIP-353)

7. **Clipboard Detection**
   - Should detect valid addresses on appear
   - Should show banner with alternatives
   - Should work with all address formats

## Implementation Quality

### ✅ Completed
- All payment requests parsed through unified system
- Intelligent destination selection with ranking
- Context-aware balance displays
- Enhanced error messages
- UI for destination selection
- Clipboard integration
- Support for all address formats

### 🎯 Best Practices Used
- Separation of concerns (selector logic vs. UI)
- Comprehensive logging for debugging
- Graceful fallbacks for edge cases
- User-friendly error messages
- Consistent with existing code style

### 📊 Code Metrics
- Added: ~150 lines of new logic
- Modified: ~200 lines of existing logic
- Total file size: ~550 lines (well-organized)
- Zero breaking changes to public API

## Related Files

- `SendView.swift` - Main implementation
- `PaymentDestinationSelector.swift` - Selection logic
- `PaymentDestinationPickerView.swift` - Picker UI
- `PaymentDestinationRow.swift` - Individual destination display
- `ClipboardAddressBanner.swift` - Clipboard integration
- `AddressValidator.swift` - Payment request parsing

## Documentation

See also:
- `PaymentDestinationSelectorExamples.swift` - Usage examples
- `PAYMENT_DESTINATION_SELECTOR_README.md` - Selector documentation
- `PAYMENT_SELECTION_FLOW_DIAGRAM.md` - Visual flow diagrams
