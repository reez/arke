# SendView Payment Flow Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                           SendView                               │
│                                                                  │
│  ┌────────────────┐         ┌───────────────────────────┐      │
│  │ User Input     │────────▶│ AddressValidator          │      │
│  │ - Text field   │         │ parsePaymentRequest()     │      │
│  │ - Clipboard    │         └───────────────────────────┘      │
│  │ - Contact      │                      │                      │
│  └────────────────┘                      ▼                      │
│                              ┌───────────────────────────┐      │
│                              │ PaymentRequest            │      │
│                              │ - destinations[]          │      │
│                              │ - amount                  │      │
│                              │ - label, message          │      │
│                              └───────────────────────────┘      │
│                                          │                      │
│                                          ▼                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ PaymentDestinationSelector                             │    │
│  │ rankDestinations(paymentRequest, paymentContext)       │    │
│  │                                                         │    │
│  │  Input Context:                                         │    │
│  │  • arkBalance, bitcoinBalance                          │    │
│  │  • networkConfig                                       │    │
│  │  • userPreferences                                     │    │
│  │  • arkServerConnected                                  │    │
│  │                                                         │    │
│  │  Output: RankedDestination[]                          │    │
│  │  • destination (format, network, address)             │    │
│  │  • balanceSource (ark/bitcoin/arkViaServer)           │    │
│  │  • availableBalance                                    │    │
│  │  • estimatedFee                                        │    │
│  │  • viable (true/false)                                 │    │
│  │  • reason (detailed explanation)                       │    │
│  │  • priority (ranking order)                            │    │
│  └────────────────────────────────────────────────────────┘    │
│                                          │                      │
│                                          ▼                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Destination Selection Logic                             │   │
│  │                                                          │   │
│  │  if viableCount == 0:                                   │   │
│  │    → Show error with reasons                            │   │
│  │  else if viableCount == 1:                              │   │
│  │    → Auto-select, show indicator                        │   │
│  │  else if viableCount > 1:                               │   │
│  │    → Auto-select optimal, show "Change" button          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                          │                      │
│                                          ▼                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ UI State Update                                          │   │
│  │  • selectedDestination = optimal                         │   │
│  │  • rankedDestinations = all ranked                       │   │
│  │  • Show payment method indicator                         │   │
│  │  • Update balance display                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## User Interaction Flows

### Flow 1: Single Address Entry

```
User enters address
    │
    ▼
Parse as PaymentRequest
    │
    ▼
Rank destinations (1 destination)
    │
    ├─▶ Viable? ─────────────▶ Auto-select
    │                             │
    │                             ▼
    │                         Show indicator:
    │                         "Paying via Bitcoin"
    │                             │
    │                             ▼
    │                         User enters amount
    │                             │
    │                             ▼
    │                         User taps Send
    │                             │
    │                             ▼
    │                         Route to manager method
    │
    └─▶ Not viable? ──────────▶ Show error:
                                "Insufficient Bitcoin balance"
```

### Flow 2: Multi-Destination BIP-21 URI

```
User pastes BIP-21 URI
    │
    ▼
Parse as PaymentRequest
    │
    ▼
Rank destinations (e.g., Ark, Lightning, Bitcoin)
    │
    ▼
┌──────────────────────────────┐
│ Ranked Results:              │
│ 1. ✓ Ark (recommended)       │
│ 2. ✓ Lightning               │
│ 3. ✓ Bitcoin                 │
└──────────────────────────────┘
    │
    ▼
Auto-select #1 (Ark)
    │
    ▼
Show indicator: "Paying via Ark · Change"
    │
    ├─▶ User happy with selection? ───▶ Enter amount & send
    │
    └─▶ User taps "Change"? ──────────▶ Show PaymentDestinationPickerView
                                            │
                                            ▼
                                        User selects Lightning
                                            │
                                            ▼
                                        Update indicator:
                                        "Paying via Lightning · Change"
                                            │
                                            ▼
                                        Enter amount & send
```

### Flow 3: Clipboard Detection

```
SendView appears
    │
    ▼
Check clipboard
    │
    ├─▶ Empty or invalid ──────────▶ Continue normally
    │
    └─▶ Valid PaymentRequest ──────▶ Show ClipboardAddressBanner
                                        │
                                        ▼
                                    Display:
                                    • Primary destination
                                    • Alternative destinations
                                    • Amount (if embedded)
                                        │
                                        ├─▶ User dismisses ───────▶ Hide banner
                                        │
                                        └─▶ User taps "Use" ──────▶ Fill recipient field
                                                                        │
                                                                        ▼
                                                                    Trigger destination
                                                                    selection flow
```

### Flow 4: Insufficient Balance Across All Methods

```
User enters payment request
    │
    ▼
Parse & rank destinations
    │
    ▼
Check viability:
    • Ark: ✗ Insufficient (need 1000k, have 300k)
    • Lightning: ✗ Requires Ark balance
    • Bitcoin: ✗ Insufficient (need 1000k, have 500k)
    │
    ▼
No viable destinations
    │
    ▼
Show detailed error:
"Cannot send payment:
 • Ark: Insufficient balance (300k < 1000k sats)
 • Lightning: Ark balance too low
 • Bitcoin: Insufficient balance (500k < 1000k sats)"
    │
    ▼
Disable Send button
```

## Component Interaction

```
┌─────────────────┐
│   SendView      │
│                 │
│  State:         │
│  • recipient    │◀─────────────┐
│  • amount       │              │
│  • selected     │              │
│    Destination  │              │
│  • ranked       │              │
│    Destinations │              │
└─────────────────┘              │
        │                        │
        │ Shows                  │ User
        ▼                        │ selects
┌──────────────────────────┐    │
│ PaymentDestination       │    │
│ PickerView               │────┘
│                          │
│ ┌──────────────────────┐ │
│ │ Recommended (⭐)     │ │
│ │ PaymentDestination   │ │
│ │ Row                  │ │
│ └──────────────────────┘ │
│                          │
│ ┌──────────────────────┐ │
│ │ PaymentDestination   │ │
│ │ Row                  │ │
│ └──────────────────────┘ │
│                          │
│ ┌──────────────────────┐ │
│ │ Unavailable          │ │
│ │ PaymentDestination   │ │
│ │ Row (dimmed)         │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

## Data Flow During Send

```
User taps Send button
    │
    ▼
Validate:
    • selectedDestination exists?
    • amount valid (unless embedded)?
    │
    ▼
Check viability of selectedDestination
    │
    ├─▶ Not viable ──────────▶ Show error with reason
    │
    └─▶ Viable ──────────────▶ Check amount + fee ≤ available
                                    │
                                    ├─▶ Insufficient ──▶ Show detailed error
                                    │
                                    └─▶ Sufficient ────▶ Route to manager
                                                            │
                                                            ▼
                                        switch destination.format:
                                            │
                                            ├─▶ .bitcoin ──────▶ sendOnchain()
                                            ├─▶ .ark ──────────▶ send()
                                            ├─▶ .lightning ────▶ payLightningInvoice()
                                            └─▶ .silentPayments ▶ sendOnchain()
                                                            │
                                                            ▼
                                                    Show SendModalView
                                                    (sending → success/error)
```

## Balance Display Logic

```
selectedDestination exists?
    │
    ├─▶ No ───────────────────▶ Show total balance
    │                           "Available: 1.5M (Total balance)"
    │
    └─▶ Yes ──────────────────▶ Get balance source
                                    │
                                    ▼
                                switch balanceSource:
                                    │
                                    ├─▶ .ark ────────────▶ "Available: 500k (Ark Balance) · No fees"
                                    │
                                    ├─▶ .bitcoin ────────▶ "Available: 1M (Bitcoin Balance) · Est. fee: 500 sats"
                                    │
                                    └─▶ .arkViaServer ───▶ "Available: 500k (Ark Balance via Lightning) · Est. fee: 100 sats"
```

## State Transitions

```
[Empty]
    │
    └─▶ User enters address ──▶ [Parsing]
                                    │
                                    ├─▶ Invalid ──────────▶ [Error: Invalid address]
                                    │
                                    └─▶ Valid ────────────▶ [Ranking]
                                                                │
                                                                ├─▶ No viable ──▶ [Error: No viable destinations]
                                                                │
                                                                └─▶ Has viable ─▶ [Destination Selected]
                                                                                        │
                                                                                        ├─▶ 1 viable ────▶ [Show indicator]
                                                                                        │
                                                                                        └─▶ >1 viable ───▶ [Show indicator + Change button]
                                                                                                                │
                                                                                                                └─▶ User taps Change ──▶ [Show Picker]
                                                                                                                                                │
                                                                                                                                                └─▶ User selects ──▶ [Update Selection]
```
