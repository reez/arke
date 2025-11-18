# Payment Destination Selector - Quick Reference

## 🚀 Quick Start

```swift
// 1. Parse payment request
let paymentRequest = AddressValidator.parsePaymentRequest(input)

// 2. Create context
let context = PaymentDestinationSelector.PaymentContext(
    arkBalance: walletManager.arkBalance?.spendableSat,
    bitcoinBalance: walletManager.onchainBalance?.trustedSpendableSat,
    networkConfig: walletManager.networkConfig ?? NetworkConfig.signet
)

// 3. Get optimal destination
let optimal = paymentRequest.selectOptimalDestination(context: context)

// 4. Proceed with payment
if let destination = optimal {
    executePayment(destination)
}
```

## 💡 Key Concepts

### Balance Sources

| Format              | Uses Balance     | Deducts From    |
|---------------------|------------------|-----------------|
| Ark                 | arkBalance       | arkBalance      |
| Lightning           | arkBalance       | arkBalance      |
| Lightning Invoice   | arkBalance       | arkBalance      |
| Lightning Address   | arkBalance       | arkBalance      |
| Bitcoin             | bitcoinBalance   | bitcoinBalance  |
| Silent Payments     | bitcoinBalance   | bitcoinBalance  |

**⚠️ Important:** Ark and Lightning share the same balance!

### Default Priority (Lowest Fees First)

1. 🟣 **Ark** - Free, instant
2. ⚡ **Lightning** - ~100 sats, fast
3. 🔵 **Silent Payments** - ~600 sats, private
4. 🟠 **Bitcoin** - ~500 sats, reliable

## 📋 Common Use Cases

### Use Case 1: Automatic Selection
```swift
if let optimal = paymentRequest.selectOptimalDestination(context: context) {
    // Use this destination automatically
    proceedWithPayment(optimal)
}
```

### Use Case 2: Show User All Options
```swift
let ranked = paymentRequest.rankedDestinations(context: context)
showDestinationPicker(ranked) // Use PaymentDestinationPickerView
```

### Use Case 3: Check Payment Feasibility
```swift
let (feasible, suggested) = PaymentDestinationSelector.canFulfillPayment(
    paymentRequest,
    with: context
)

if !feasible {
    showError("Insufficient balance for all payment methods")
}
```

### Use Case 4: Custom Preferences
```swift
let preferences = PaymentDestinationSelector.PaymentPreferences(
    priorityOrder: [.bitcoin, .ark, .lightning],
    preferOnChainForLargeAmounts: true,
    largeAmountThreshold: 1_000_000,
    minimumArkReserve: 50_000
)

let context = PaymentDestinationSelector.PaymentContext(
    arkBalance: arkBalance,
    bitcoinBalance: bitcoinBalance,
    networkConfig: networkConfig,
    userPreferences: preferences
)
```

### Use Case 5: Check Individual Destination
```swift
let isViable = PaymentDestinationSelector.isViable(
    destination: arkDestination,
    amount: 100_000,
    context: context
)
```

## 🔍 Understanding RankedDestination

```swift
struct RankedDestination {
    let destination: PaymentDestination       // The actual destination
    let balanceSource: BalanceSource         // Which balance it uses
    let availableBalance: Int?               // Available balance in sats
    let estimatedFee: Int?                   // Estimated fee in sats
    let viable: Bool                         // Can we use this?
    let reason: String                       // Why viable/not viable
    let priority: Int                        // Lower = higher priority
}
```

Example:
```swift
for ranked in paymentRequest.rankedDestinations(context: context) {
    print("\(ranked.destination.format.displayName)")
    print("  Balance: \(ranked.availableBalance ?? 0) sats")
    print("  Fee: ~\(ranked.estimatedFee ?? 0) sats")
    print("  Viable: \(ranked.viable ? "✓" : "✗")")
    print("  Reason: \(ranked.reason)")
}
```

## ⚙️ Configuration Options

### PaymentContext

```swift
PaymentDestinationSelector.PaymentContext(
    arkBalance: Int?,                    // Ark balance in sats
    bitcoinBalance: Int?,                // Bitcoin balance in sats
    networkConfig: NetworkConfig,        // Current network
    userPreferences: PaymentPreferences, // User settings
    arkServerConnected: Bool,            // Server status
    hasLightningCapability: Bool         // Lightning available
)
```

### PaymentPreferences

```swift
PaymentDestinationSelector.PaymentPreferences(
    priorityOrder: [AddressFormat],      // Custom priority
    preferOnChainForLargeAmounts: Bool,  // Prefer on-chain for large
    largeAmountThreshold: Int,           // Large amount threshold
    minimumArkReserve: Int               // Minimum Ark reserve
)
```

## 🛡️ Safety Features

### Reserve Protection
```swift
// Prevents draining Ark balance below minimum
preferences.minimumArkReserve = 10_000 // Keep 10k sats
```

### Server Connectivity
```swift
// Automatically skips Lightning when server offline
context.arkServerConnected = false
```

### Network Filtering
```swift
// Only shows destinations matching current network
destinations.filter { $0.isCompatible(with: networkConfig) }
```

### Balance Validation
```swift
// Checks if sufficient balance before marking viable
if availableBalance < (amount + estimatedFee) {
    viable = false
}
```

## 🎯 Best Practices

### ✅ DO

```swift
// DO: Check viability before payment
if paymentRequest.canFulfill(with: context) {
    proceedWithPayment()
}

// DO: Show balance source to user
print("Will use: \(balanceSource.displayName)")

// DO: Handle server connectivity
let context = PaymentDestinationSelector.PaymentContext(
    arkServerConnected: arkSDK.isConnected
)

// DO: Respect user preferences
let context = PaymentDestinationSelector.PaymentContext(
    userPreferences: userSettings.paymentPreferences
)

// DO: Give user choice when multiple options
if viableOptions.count > 1 {
    showPicker(viableOptions)
}
```

### ❌ DON'T

```swift
// DON'T: Assume first destination is always best
let destination = paymentRequest.destinations.first // ❌

// DON'T: Ignore viability checks
executePayment(destination) // ❌ Check viability first!

// DON'T: Forget about reserves
// Could drain account to zero ❌

// DON'T: Ignore server status
// Could try Lightning when offline ❌

// DON'T: Use hardcoded fees
// Use estimatedFee from RankedDestination ❌
```

## 🐛 Debugging

### Get Detailed Report
```swift
let report = PaymentDestinationSelector.viabilityReport(
    from: paymentRequest,
    context: context
)
print(report)
```

Output:
```
Payment Destination Analysis:
Amount: 100000 sats
Ark Balance: 500000 sats
Bitcoin Balance: 1000000 sats

Destinations:

1. Ark
   Address: tark1qxy...example
   Balance Source: Ark Balance
   Available: 500000 sats
   Estimated Fee: 0 sats
   Viable: ✓
   Reason: Sufficient balance
   Priority: #1

2. Lightning Invoice
   Address: lntb100n1...example
   Balance Source: Ark Balance (via Lightning)
   Available: 500000 sats
   Estimated Fee: 100 sats
   Viable: ✓
   Reason: Sufficient balance
   Priority: #2
...
```

## 📊 Common Scenarios

| Scenario | Ark Balance | BTC Balance | Amount | Selected |
|----------|-------------|-------------|--------|----------|
| All sufficient | 500k | 1M | 100k | Ark (lowest fee) |
| Ark insufficient | 300k | 1M | 500k | Bitcoin (fallback) |
| Only Ark sufficient | 500k | 200k | 300k | Ark |
| Server offline | 500k | 1M | 100k | Bitcoin (fallback) |
| Large payment | 2M | 2M | 1.5M | Bitcoin (if enabled) |
| Reserve protection | 500k | 1M | 495k | Bitcoin (preserve) |

## 🔗 Integration Points

### With AddressValidator
```swift
let request = AddressValidator.parsePaymentRequest(input)
let optimal = request.selectOptimalDestination(context: context)
```

### With WalletManager
```swift
let context = PaymentDestinationSelector.PaymentContext(
    arkBalance: walletManager.arkBalance?.spendableSat,
    bitcoinBalance: walletManager.onchainBalance?.trustedSpendableSat,
    networkConfig: walletManager.networkConfig ?? NetworkConfig.signet
)
```

### With SendView
```swift
// Show picker if multiple options
if ranked.filter({ $0.viable }).count > 1 {
    sheet(isPresented: $showPicker) {
        PaymentDestinationPickerView(rankedDestinations: ranked) { destination in
            selectedDestination = destination
        }
    }
}
```

## 📚 Related Files

- `PaymentDestinationSelector.swift` - Main implementation
- `PaymentDestinationSelectorTests.swift` - Test suite
- `PaymentDestinationSelectorExamples.swift` - Usage examples
- `PaymentDestinationPickerView.swift` - SwiftUI picker
- `PAYMENT_DESTINATION_SELECTOR_README.md` - Full documentation
- `PAYMENT_SELECTION_FLOW_DIAGRAM.md` - Visual flow diagrams

## 🎓 Learn More

See full documentation in:
- `IMPLEMENTATION_SUMMARY.md` - Complete implementation details
- `PAYMENT_DESTINATION_SELECTOR_README.md` - Architecture and design
- `PAYMENT_SELECTION_FLOW_DIAGRAM.md` - Visual diagrams

## ⚡ TL;DR

```swift
// Parse → Create Context → Select → Pay
let request = AddressValidator.parsePaymentRequest(input)
let context = PaymentDestinationSelector.PaymentContext(
    arkBalance: walletManager.arkBalance?.spendableSat,
    bitcoinBalance: walletManager.onchainBalance?.trustedSpendableSat,
    networkConfig: walletManager.networkConfig ?? NetworkConfig.signet
)
if let optimal = request.selectOptimalDestination(context: context) {
    executePayment(optimal)
}
```

**Remember:** 
- Ark and Lightning share arkBalance
- Always check viability
- Show user the balance source
- Handle server connectivity
- Protect reserves

That's it! 🚀
