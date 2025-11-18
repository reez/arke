# Payment Destination Selection Flow Diagram

## High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    User Scans QR Code                           │
│     bitcoin:tb1q...?amount=0.001&ark=tark1q...&ln=lntb...      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   AddressValidator                              │
│                  .parsePaymentRequest()                         │
│                                                                 │
│   Parses URI and extracts:                                     │
│   ✓ Primary address (Bitcoin)                                  │
│   ✓ Alternative addresses (Ark, Lightning)                     │
│   ✓ Amount (if specified)                                      │
│   ✓ Labels and metadata                                        │
│                                                                 │
│   Returns: PaymentRequest with multiple destinations           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              PaymentDestinationSelector                         │
│              .rankDestinations()                                │
│                                                                 │
│   Context:                                                      │
│   • Ark Balance: 500,000 sats                                  │
│   • Bitcoin Balance: 1,000,000 sats                            │
│   • Network: Signet                                            │
│   • Ark Server: Connected                                      │
│                                                                 │
│   Analysis for each destination:                               │
│   ┌───────────────────────────────────────────────────────┐   │
│   │ 1. Ark (Priority #1)                                  │   │
│   │    Balance Source: arkBalance                         │   │
│   │    Available: 500,000 sats                            │   │
│   │    Required: 100,000 sats + 0 fee                     │   │
│   │    Result: ✅ VIABLE                                  │   │
│   └───────────────────────────────────────────────────────┘   │
│   ┌───────────────────────────────────────────────────────┐   │
│   │ 2. Lightning (Priority #2)                            │   │
│   │    Balance Source: arkBalance (via server)            │   │
│   │    Available: 500,000 sats                            │   │
│   │    Required: 100,000 sats + 100 fee                   │   │
│   │    Result: ✅ VIABLE                                  │   │
│   └───────────────────────────────────────────────────────┘   │
│   ┌───────────────────────────────────────────────────────┐   │
│   │ 3. Bitcoin (Priority #3)                              │   │
│   │    Balance Source: bitcoinBalance                     │   │
│   │    Available: 1,000,000 sats                          │   │
│   │    Required: 100,000 sats + 500 fee                   │   │
│   │    Result: ✅ VIABLE                                  │   │
│   └───────────────────────────────────────────────────────┘   │
│                                                                 │
│   Returns: [RankedDestination] sorted by viability & priority  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                        UI Layer                                 │
│                                                                 │
│   ┌─────────────────────────────────────────────────────┐     │
│   │  If single viable option:                           │     │
│   │    → Auto-select and proceed                        │     │
│   │                                                      │     │
│   │  If multiple viable options:                        │     │
│   │    → Show PaymentDestinationPickerView             │     │
│   │                                                      │     │
│   │    ┌────────────────────────────────────┐          │     │
│   │    │ ⭐ RECOMMENDED                      │          │     │
│   │    │ Ark                                │          │     │
│   │    │ tark1qxy...example                 │          │     │
│   │    │ 💰 Ark Balance  •  ~0 sats         │          │     │
│   │    └────────────────────────────────────┘          │     │
│   │    ┌────────────────────────────────────┐          │     │
│   │    │ Lightning Invoice                  │          │     │
│   │    │ lntb100n1...example                │          │     │
│   │    │ 💰 Ark Balance (via Lightning)     │          │     │
│   │    │    ~100 sats                       │          │     │
│   │    └────────────────────────────────────┘          │     │
│   │    ┌────────────────────────────────────┐          │     │
│   │    │ Bitcoin                            │          │     │
│   │    │ tb1qw508...kxpjzsx                 │          │     │
│   │    │ 💰 Bitcoin Balance  •  ~500 sats   │          │     │
│   │    └────────────────────────────────────┘          │     │
│   └─────────────────────────────────────────────────────┘     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Payment Execution                             │
│            (WalletManager, ArkSDK, etc.)                        │
│                                                                 │
│   Based on selected destination:                               │
│   • Ark → VTxO transfer                                        │
│   • Lightning → Server-routed payment                          │
│   • Bitcoin → On-chain transaction                             │
└─────────────────────────────────────────────────────────────────┘
```

## Fallback Scenario (Insufficient Ark Balance)

```
┌─────────────────────────────────────────────────────────────────┐
│                    User Scans QR Code                           │
│     bitcoin:tb1q...?amount=0.006&ark=tark1q...&ln=lntb...      │
│                  (Amount: 600,000 sats)                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              PaymentDestinationSelector                         │
│                                                                 │
│   Context:                                                      │
│   • Ark Balance: 500,000 sats         ⚠️ INSUFFICIENT         │
│   • Bitcoin Balance: 1,000,000 sats   ✅ SUFFICIENT           │
│                                                                 │
│   Analysis:                                                     │
│   ┌───────────────────────────────────────────────────────┐   │
│   │ 1. Ark (Priority #1)                                  │   │
│   │    Available: 500,000 sats                            │   │
│   │    Required: 600,000 sats + 0 fee                     │   │
│   │    Result: ❌ INSUFFICIENT BALANCE                    │   │
│   └───────────────────────────────────────────────────────┘   │
│   ┌───────────────────────────────────────────────────────┐   │
│   │ 2. Lightning (Priority #2)                            │   │
│   │    Available: 500,000 sats (same as Ark!)            │   │
│   │    Required: 600,000 sats + 100 fee                   │   │
│   │    Result: ❌ INSUFFICIENT BALANCE                    │   │
│   └───────────────────────────────────────────────────────┘   │
│   ┌───────────────────────────────────────────────────────┐   │
│   │ 3. Bitcoin (Priority #3)                              │   │
│   │    Available: 1,000,000 sats                          │   │
│   │    Required: 600,000 sats + 500 fee                   │   │
│   │    Result: ✅ VIABLE → AUTO-SELECT                   │   │
│   └───────────────────────────────────────────────────────┘   │
│                                                                 │
│   Decision: Automatically select Bitcoin (only viable option)  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      UI Notification                            │
│                                                                 │
│   ┌──────────────────────────────────────────────────────┐    │
│   │  ℹ️ Payment Method Selected                          │    │
│   │                                                       │    │
│   │  Using Bitcoin on-chain                              │    │
│   │  (Ark balance insufficient)                          │    │
│   │                                                       │    │
│   │  [Confirm Payment]                                   │    │
│   └──────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Reserve Protection Scenario

```
┌─────────────────────────────────────────────────────────────────┐
│                 Payment Request: 495,000 sats                   │
│                                                                 │
│   User Preferences:                                             │
│   • Minimum Ark Reserve: 10,000 sats                           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              PaymentDestinationSelector                         │
│                                                                 │
│   Context:                                                      │
│   • Ark Balance: 500,000 sats                                  │
│   • Bitcoin Balance: 1,000,000 sats                            │
│   • Reserve: 10,000 sats                                       │
│                                                                 │
│   Analysis:                                                     │
│   ┌───────────────────────────────────────────────────────┐   │
│   │ 1. Ark (Priority #1)                                  │   │
│   │    Available: 500,000 sats                            │   │
│   │    Required: 495,000 sats + 0 fee = 495,000          │   │
│   │    Remaining: 500,000 - 495,000 = 5,000 sats         │   │
│   │                                                       │   │
│   │    5,000 < 10,000 (Reserve)                          │   │
│   │                                                       │   │
│   │    Result: ❌ WOULD DRAIN BELOW RESERVE              │   │
│   └───────────────────────────────────────────────────────┘   │
│   ┌───────────────────────────────────────────────────────┐   │
│   │ 2. Bitcoin (Priority #3)                              │   │
│   │    Available: 1,000,000 sats                          │   │
│   │    Required: 495,000 sats + 500 fee = 495,500        │   │
│   │                                                       │   │
│   │    Result: ✅ VIABLE → SELECT TO PROTECT RESERVE     │   │
│   └───────────────────────────────────────────────────────┘   │
│                                                                 │
│   Decision: Use Bitcoin to preserve Ark reserve                │
└─────────────────────────────────────────────────────────────────┘
```

## Server Connectivity Scenario

```
┌─────────────────────────────────────────────────────────────────┐
│                    Ark Server: OFFLINE ⚠️                       │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              PaymentDestinationSelector                         │
│                                                                 │
│   Context:                                                      │
│   • Ark Balance: 500,000 sats                                  │
│   • Bitcoin Balance: 1,000,000 sats                            │
│   • arkServerConnected: false  🔴                              │
│                                                                 │
│   Analysis:                                                     │
│   ┌───────────────────────────────────────────────────────┐   │
│   │ 1. Ark (Priority #1)                                  │   │
│   │    Requires Server: Yes                               │   │
│   │    Server Connected: No                               │   │
│   │    Result: ❌ SERVER NOT CONNECTED                    │   │
│   └───────────────────────────────────────────────────────┘   │
│   ┌───────────────────────────────────────────────────────┐   │
│   │ 2. Lightning (Priority #2)                            │   │
│   │    Requires Server: Yes (routing)                     │   │
│   │    Server Connected: No                               │   │
│   │    Result: ❌ SERVER NOT CONNECTED                    │   │
│   └───────────────────────────────────────────────────────┘   │
│   ┌───────────────────────────────────────────────────────┐   │
│   │ 3. Bitcoin (Priority #3)                              │   │
│   │    Requires Server: No                                │   │
│   │    Result: ✅ VIABLE → AUTO-SELECT                   │   │
│   └───────────────────────────────────────────────────────┘   │
│                                                                 │
│   Decision: Fall back to Bitcoin (server-independent)          │
└─────────────────────────────────────────────────────────────────┘
```

## Balance Source Mapping

```
┌─────────────────────────────────────────────────────────────────┐
│                      User's Wallet                              │
│                                                                 │
│   ┌─────────────────────────┐    ┌──────────────────────────┐ │
│   │   Ark Balance Pool      │    │  Bitcoin Balance Pool    │ │
│   │   500,000 sats          │    │  1,000,000 sats          │ │
│   └──────────┬──────────────┘    └────────┬─────────────────┘ │
│              │                             │                   │
│              │                             │                   │
│      Used by │                             │ Used by           │
│              ▼                             ▼                   │
│   ┌─────────────────────┐      ┌────────────────────────┐    │
│   │ Payment Formats:    │      │ Payment Formats:       │    │
│   │                     │      │                        │    │
│   │ • Ark transfers     │      │ • Bitcoin on-chain     │    │
│   │ • Lightning (via    │      │ • Silent Payments      │    │
│   │   Ark server)       │      │                        │    │
│   │ • Lightning invoices│      │                        │    │
│   │ • Lightning address │      │                        │    │
│   └─────────────────────┘      └────────────────────────┘    │
│                                                                 │
│   Key Insight:                                                  │
│   Both Ark AND Lightning use the SAME balance pool!            │
│   This is why selector must be smart about fallbacks.          │
└─────────────────────────────────────────────────────────────────┘
```

## Decision Tree

```
                      Payment Request Received
                               │
                               ▼
                    Parse with AddressValidator
                               │
                               ▼
                    Create PaymentContext
                    (balances, network, prefs)
                               │
                               ▼
                ┌──────────────┴──────────────┐
                │                             │
                ▼                             ▼
         Multiple Destinations?        Single Destination
                │                             │
                ▼                             ▼
         Rank all destinations         Check viability
                │                             │
                ▼                             │
         Filter viable ones                   │
                │                             │
                ▼                             │
         ┌──────────────┐                     │
         │              │                     │
         ▼              ▼                     ▼
    Zero viable    One viable           Is viable?
         │              │                     │
         │              │              ┌──────┴──────┐
         │              │              │             │
         ▼              ▼              ▼             ▼
     Show error    Auto-select      Proceed      Show error
                   & proceed                    (insufficient
                                                  balance)
         Multiple viable
               │
               ▼
    Show picker to user
               │
               ▼
    User selects option
               │
               ▼
          Proceed with
       selected destination
```

This visual representation helps understand the complete flow from QR code scan to payment execution!
