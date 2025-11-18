# SendView Testing Scenarios

This document provides concrete testing scenarios to verify the PaymentDestinationSelector integration in SendView.

## Setup

### Test Wallets

**Wallet A: Well-funded**
- Ark Balance: 1,000,000 sats
- Bitcoin Balance: 2,000,000 sats
- Network: Signet

**Wallet B: Low Ark Balance**
- Ark Balance: 50,000 sats
- Bitcoin Balance: 1,000,000 sats
- Network: Signet

**Wallet C: Low Bitcoin Balance**
- Ark Balance: 1,000,000 sats
- Bitcoin Balance: 50,000 sats
- Network: Signet

**Wallet D: Empty**
- Ark Balance: 0 sats
- Bitcoin Balance: 0 sats
- Network: Signet

---

## Scenario 1: Single Bitcoin Address

### Test Input
```
tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx
```

### Expected Behavior (Wallet A)
1. ✅ Parse as PaymentRequest with 1 Bitcoin destination
2. ✅ Rank destinations → Bitcoin viable
3. ✅ Auto-select Bitcoin destination
4. ✅ Show indicator: "Paying via Bitcoin"
5. ✅ Show balance: "Available: 2,000,000 sats (Bitcoin Balance) · Est. fee: 500 sats"
6. ✅ No "Change" button (only 1 destination)
7. ✅ User enters 100,000 sats
8. ✅ Send button enabled
9. ✅ Clicking Send calls `manager.sendOnchain()`

### Console Output
```
🔍 [SendView] Parsed payment request details:
   Destinations: 1
   Primary format: bitcoin (Bitcoin)
   Primary network: Signet
   ...

🎯 [SendView] Ranked destinations:
   ✓ [1] Bitcoin
      Balance: Bitcoin Balance
      Available: 2000000 sats
      Fee: ~500 sats
      Reason: Sufficient balance

✨ [SendView] Auto-selected optimal destination: Bitcoin
```

---

## Scenario 2: Single Ark Address

### Test Input
```
tqwertyuiopasdfghjklzxcvbnm1234567890
```

### Expected Behavior (Wallet A)
1. ✅ Parse as PaymentRequest with 1 Ark destination
2. ✅ Rank destinations → Ark viable
3. ✅ Auto-select Ark destination
4. ✅ Show indicator: "Paying via Ark"
5. ✅ Show balance: "Available: 1,000,000 sats (Ark Balance) · No fees"
6. ✅ No "Change" button
7. ✅ User enters 50,000 sats
8. ✅ Send button enabled
9. ✅ Clicking Send calls `manager.send()`

---

## Scenario 3: Lightning Invoice with Amount

### Test Input
```
lntb500n1pjq8xyzpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq
```
(Assuming this decodes to 50,000 sats)

### Expected Behavior (Wallet A)
1. ✅ Parse as PaymentRequest with Lightning destination
2. ✅ Detect embedded amount: 50,000 sats
3. ✅ Pre-fill amount field with "50000"
4. ✅ Amount field disabled
5. ✅ Show note: "(amount set by invoice)"
6. ✅ Auto-select Lightning destination
7. ✅ Show indicator: "Paying via Lightning Invoice"
8. ✅ Show balance: "Available: 1,000,000 sats (Ark Balance via Lightning) · Est. fee: 100 sats"
9. ✅ Send button enabled immediately (amount pre-filled)
10. ✅ Clicking Send calls `manager.payLightningInvoice(invoice: ..., amount: nil)`

---

## Scenario 4: BIP-21 with Multiple Destinations

### Test Input
```
bitcoin:tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx?amount=0.001&ark=tqxyzexample&lightning=lntb100000n1example
```

### Expected Behavior (Wallet A)
1. ✅ Parse as BIP-21 with 3 destinations
2. ✅ Extract amount: 100,000 sats
3. ✅ Pre-fill amount field
4. ✅ Rank destinations:
   - Ark: ✓ Viable (Priority 0)
   - Lightning: ✓ Viable (Priority 1)  
   - Bitcoin: ✓ Viable (Priority 2)
5. ✅ Auto-select Ark (highest priority, lowest fee)
6. ✅ Show indicator: "Paying via Ark · Change"
7. ✅ "Change" button visible (3 viable destinations)
8. ✅ User taps "Change"
9. ✅ PaymentDestinationPickerView opens
10. ✅ Shows Ark with ⭐ RECOMMENDED badge
11. ✅ Shows Lightning and Bitcoin as alternatives
12. ✅ User selects Lightning
13. ✅ Indicator updates: "Paying via Lightning Invoice · Change"
14. ✅ Balance updates: "Ark Balance via Lightning"
15. ✅ Clicking Send calls `manager.payLightningInvoice()`

### Picker Display
```
Available Payment Methods
  ⭐ Ark
     Address: tqxy...example
     Ark Balance
     ~0 sats fee
     ✓ Sufficient balance

  Lightning Invoice
     Address: lntb100...example
     Ark Balance (via Lightning)
     ~100 sats fee
     ✓ Sufficient balance

  Bitcoin
     Address: tb1qw50...pjzsx
     Bitcoin Balance
     ~500 sats fee
     ✓ Sufficient balance
```

---

## Scenario 5: Insufficient Ark Balance

### Test Input
```
bitcoin:tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx?amount=0.005&ark=tqxyzexample
```
(500,000 sats requested)

### Expected Behavior (Wallet B: 50k Ark, 1M Bitcoin)
1. ✅ Parse as BIP-21 with 2 destinations
2. ✅ Extract amount: 500,000 sats
3. ✅ Rank destinations:
   - Ark: ✗ Not viable (50k < 500k)
   - Bitcoin: ✓ Viable
4. ✅ Auto-select Bitcoin (only viable option)
5. ✅ Show indicator: "Paying via Bitcoin"
6. ✅ No "Change" button (only 1 viable)
7. ✅ Balance shows Bitcoin balance
8. ✅ Amount pre-filled
9. ✅ Send enabled

### Picker Display (if manually opened)
```
Available Payment Methods
  Bitcoin
     Bitcoin Balance
     ~500 sats fee
     ✓ Sufficient balance

Unavailable
  Ark (dimmed)
     Ark Balance
     ~0 sats fee
     ✗ Insufficient balance (50000 < 500000 sats)
```

---

## Scenario 6: All Destinations Insufficient

### Test Input
```
bitcoin:tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx?amount=0.01&ark=tqxyzexample
```
(1,000,000 sats requested)

### Expected Behavior (Wallet B: 50k Ark, 1M Bitcoin but need 1M + fees)
1. ✅ Parse as BIP-21
2. ✅ Extract amount: 1,000,000 sats
3. ✅ Rank destinations:
   - Ark: ✗ Not viable (50k < 1M)
   - Bitcoin: ✗ Not viable (1M < 1M + 500 fee)
4. ✅ No viable destinations
5. ✅ selectedDestination = nil
6. ✅ Show error:
   ```
   Cannot send payment. 
   Ark: Insufficient balance (50000 < 1000000 sats); 
   Bitcoin: Insufficient balance (1000000 < 1000500 sats)
   ```
7. ✅ Send button disabled
8. ✅ Balance shows: "Available: 0 sats (Total balance)"

---

## Scenario 7: Network Mismatch

### Test Input
```
bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4
```
(Mainnet address, but wallet is on Signet)

### Expected Behavior (Wallet A on Signet)
1. ✅ Parse as PaymentRequest
2. ✅ Detect Bitcoin Mainnet address
3. ✅ Rank destinations with network filtering
4. ✅ No network-compatible destinations
5. ✅ Show error: "Cannot send payment. Bitcoin: Network mismatch (Mainnet address on Signet network)"
6. ✅ Send button disabled

---

## Scenario 8: Clipboard Detection

### Setup
Copy to clipboard:
```
bitcoin:tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx?amount=0.001&label=Coffee%20Shop&ark=tqxyz
```

### Expected Behavior
1. ✅ SendView appears
2. ✅ Clipboard checked automatically
3. ✅ ClipboardAddressBanner appears
4. ✅ Shows:
   - "Payment request found in clipboard"
   - Primary: Bitcoin (Signet)
   - Amount: 100,000 sats
   - Label: Coffee Shop
   - Alternative: Ark
5. ✅ User taps "Use Payment Request"
6. ✅ Banner dismisses
7. ✅ Recipient field filled with BIP-21 URI
8. ✅ Destination selection triggered
9. ✅ Ark auto-selected (optimal)
10. ✅ Amount pre-filled: 100000
11. ✅ Indicator shows: "Paying via Ark · Change"

---

## Scenario 9: Manual Destination Change

### Test Input
```
bitcoin:tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx?amount=0.002&ark=tqxyz&lightning=lntb200000n1example
```

### Expected Behavior (Wallet A)
1. ✅ Enter URI, Ark auto-selected
2. ✅ User taps "Change" button
3. ✅ PaymentDestinationPickerView sheet opens
4. ✅ Three options displayed with ⭐ on Ark
5. ✅ User taps Lightning row
6. ✅ Sheet dismisses
7. ✅ selectedDestination updates to Lightning
8. ✅ Indicator updates: "Paying via Lightning Invoice · Change"
9. ✅ Balance display updates to show Ark balance (via Lightning)
10. ✅ Estimated fee changes from 0 to ~100 sats
11. ✅ User can still change back via "Change" button
12. ✅ Clicking Send calls `manager.payLightningInvoice()`

---

## Scenario 10: Contact Selection with Prefilled Recipient

### Setup
Contact: "Alice" with Bitcoin address `tb1qaliceaddress`

### Expected Behavior
1. ✅ SendView opens with prefilledRecipient and prefilledContact
2. ✅ ContactInfoBanner shows: "Sending to Alice"
3. ✅ Recipient field pre-filled with address
4. ✅ Destination selection runs immediately
5. ✅ Bitcoin destination auto-selected
6. ✅ Indicator shows: "Paying via Bitcoin"
7. ✅ User enters amount
8. ✅ User taps Send
9. ✅ Payment sent to Alice's address

---

## Scenario 11: Lightning Invoice Without Amount

### Test Input
```
lnbc1pvjluezsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygspp5...
```
(No embedded amount)

### Expected Behavior (Wallet A)
1. ✅ Parse as Lightning Invoice
2. ✅ No amount detected
3. ✅ Amount field NOT pre-filled
4. ✅ Amount field enabled (not disabled)
5. ✅ No "(amount set by invoice)" text
6. ✅ User must enter amount manually
7. ✅ User enters 75,000 sats
8. ✅ Send enabled
9. ✅ Clicking Send calls `manager.payLightningInvoice(invoice: ..., amount: 75000)`

---

## Scenario 12: Empty Wallet

### Test Input
```
bitcoin:tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx?amount=0.001&ark=tqxyz
```

### Expected Behavior (Wallet D: Empty)
1. ✅ Parse BIP-21
2. ✅ Rank destinations:
   - Ark: ✗ Not viable (0 < 100k)
   - Bitcoin: ✗ Not viable (0 < 100k)
3. ✅ No viable destinations
4. ✅ Show error: 
   ```
   Cannot send payment. 
   Ark: Insufficient balance (0 < 100000 sats); 
   Bitcoin: Insufficient balance (0 < 100000 sats)
   ```
5. ✅ Send button disabled
6. ✅ Suggest funding wallet

---

## Scenario 13: Large Payment Preference

### Test Input
```
bitcoin:tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx?amount=0.015&ark=tqxyz
```
(1,500,000 sats - large payment)

### Expected Behavior (with preferOnChainForLargeAmounts = true, threshold = 1M)
1. ✅ Parse BIP-21
2. ✅ Detect amount > threshold
3. ✅ Rank destinations with preference applied
4. ✅ Bitcoin ranked higher despite Ark being cheaper
5. ✅ Auto-select Bitcoin
6. ✅ Show indicator: "Paying via Bitcoin"
7. ✅ User can still change to Ark if desired

---

## Scenario 14: Reserve Balance Protection

### Test Input (enter amount that would drain reserve)
Amount: 990,000 sats to Ark address

### Expected Behavior (Wallet A with 1M Ark, 10k reserve preference)
1. ✅ Parse Ark address
2. ✅ User enters 990,000
3. ✅ Would leave only 10,000 - 990,000 = -980,000 (below reserve)
4. ✅ Validate on Send:
   ```
   Cannot send: Would drain below minimum Ark reserve
   ```
5. ✅ Send disabled
6. ✅ Max suggested: 990,000 (keeping 10k reserve)

---

## Error Message Examples

### Good Error Messages to Verify

1. **Insufficient Balance**
   ```
   Amount + fees (100,500 sats) exceeds available balance (100,000 sats)
   ```

2. **Network Mismatch**
   ```
   Cannot send payment. Bitcoin: This address is for Mainnet, but you're on Signet
   ```

3. **All Destinations Unavailable**
   ```
   Cannot send payment. 
   Ark: Insufficient balance (50000 < 500000 sats); 
   Bitcoin: Insufficient balance (100000 < 500500 sats)
   ```

4. **Server Offline**
   ```
   Cannot send payment. Lightning Invoice: Ark server not connected
   ```

5. **Invalid Address**
   ```
   Invalid address or payment request
   ```

---

## Console Logging Tests

Verify detailed logs appear for debugging:

### Sample Expected Log
```
🔍 [SendView] Parsed payment request details:
   Destinations: 3
   Primary format: bitcoin (Bitcoin)
   Primary network: Signet
   Primary address: tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx
   Amount: 100000 sats
   Label: Coffee Shop
   Message: Thanks for the coffee
   Has alternatives: true
   Alternative destinations:
     [1] Ark: tqxy...example
     [2] Lightning Invoice: lntb10...example

🎯 [SendView] Ranked destinations:
   ✓ [1] Ark
      Balance: Ark Balance
      Available: 1000000 sats
      Fee: ~0 sats
      Reason: Sufficient balance
   ✓ [2] Lightning Invoice
      Balance: Ark Balance (via Lightning)
      Available: 1000000 sats
      Fee: ~100 sats
      Reason: Sufficient balance
   ✓ [3] Bitcoin
      Balance: Bitcoin Balance
      Available: 2000000 sats
      Fee: ~500 sats
      Reason: Sufficient balance

✨ [SendView] Auto-selected optimal destination: Ark
```

---

## Visual Regression Testing

### Indicator Display
- [ ] Icon matches destination format
- [ ] Color matches destination format
- [ ] "Change" button only appears with multiple viable options
- [ ] Indicator has proper padding and background

### Balance Text
- [ ] Shows correct balance source
- [ ] Shows estimated fee
- [ ] Updates when destination changes
- [ ] Properly formatted amounts

### Error Display
- [ ] Error banner appears with proper styling
- [ ] Retry button works (if applicable)
- [ ] Dismiss button clears error
- [ ] Multiple error scenarios display correctly

### Picker Sheet
- [ ] Recommended badge on optimal destination
- [ ] Viable destinations in top section
- [ ] Non-viable destinations in bottom section (dimmed)
- [ ] Proper icons and colors for each format
- [ ] Cancel button works
- [ ] Selecting destination dismisses sheet

---

## Performance Tests

1. **Large BIP-21 URI** (with 10+ destinations)
   - Should rank all destinations quickly (< 100ms)
   - UI should remain responsive

2. **Rapid Address Changes**
   - Type/delete addresses rapidly
   - Should debounce properly
   - No crashes or state corruption

3. **Memory**
   - Open/close SendView repeatedly
   - No memory leaks from sheet presentations
   - State properly cleared on dismiss
