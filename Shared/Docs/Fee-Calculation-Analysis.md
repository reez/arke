# Fee Calculation Analysis

**Date**: 2026-04-07  
**Context**: Investigation into exit fee calculation issues revealed in debug logs

---

## Problem Summary

From the debug logs (temp_logs.txt), we observed:

1. **Extremely High Fee Rates**: Exit progression is calculating fee rates of **2092 sat/vB** on Signet
2. **Insufficient Balance Errors**: Multiple exits failing because 10,000 sats onchain balance is insufficient for exits requiring 11,096 to 44,490 sats
3. **No Fee Rate Control**: `progressExits()` is called with `feeRateSatPerVb: nil`, delegating fee calculation entirely to the Bark Rust library

### Example Error (Line 1041-1048 in logs):
```
VTXO f5e9270fa551d1c1aedde89f87d9cf4fc6df597e08f3711d47f6258cd7ffcd8f:0: Start(ExitStartState { tip_height: 298996 })
  Error: Insufficient Fee Error: Your balance is 0.00010000 BTC but an estimated 0.00011096 BTC (fee rate of 2092) is required to exit the VTXO
```

---

## Current Implementation

### 1. **Exit Progression Service** (ExitProgressionService.swift:138)
```swift
let statuses = try await wallet.progressExits(feeRateSatPerVb: nil)
```
- Passes `nil` for fee rate
- No user control over fees
- No environment-aware fee selection

### 2. **BarkWalletFFI** (BarkWalletFFI.swift:1849)
```swift
let statuses = try await wallet.progressExits(
    onchainWallet: onchainWallet, 
    feeRateSatPerVb: feeRateSatPerVb
)
```
- Simply forwards the `nil` to Rust FFI
- No default fee rate handling
- No environment detection

### 3. **Bark Rust Library** (FFI)
When `feeRateSatPerVb` is `nil`:
- Uses **internal fee estimation** based on onchain fee market
- Appears to fetch **mainnet fee rates** even on Signet
- Results in **extremely high fees** (2092 sat/vB) inappropriate for test networks

---

## Root Cause Analysis

### Why 2092 sat/vB?

This fee rate is likely:
1. **Mainnet Fee Market Rate**: The Bark library may be querying mainnet mempool APIs for fee estimation
2. **High-Priority Fee Tier**: Could be targeting next-block confirmation during network congestion
3. **No Network Context**: Fee estimator doesn't distinguish between mainnet (where 2092 sat/vB might be reasonable) and signet (where 1-10 sat/vB is typical)

### Why This Matters

**Signet Characteristics**:
- Test network with regular 10-minute blocks
- Minimal mempool competition
- **Typical fee rates**: 1-10 sat/vB
- **Reasonable fee rate**: 5-20 sat/vB maximum

**Impact**:
- 10,000 sat balance insufficient for even small VTXO exits
- Users unable to test exit functionality
- Unnecessarily expensive on production (if same logic applies to mainnet)

---

## How Fee Calculation Currently Works

### Exit Transaction Structure

Each unilateral exit involves multiple transactions:
1. **Parent Transaction**: Initial exit transaction (may have low/zero fees)
2. **CPFP Transaction**: Child transaction that bumps parent fee via P2A output
3. **Claim Transaction**: Final transaction to claim exited funds

### Fee Calculation Flow

```
User calls startExit()
  ↓
Bark creates exit transactions
  ↓
ExitProgressionService.progressExits(feeRateSatPerVb: nil)
  ↓
BarkWalletFFI.progressExits(feeRateSatPerVb: nil)
  ↓
Bark Rust Library (FFI)
  ├─ Checks if fee rate provided
  ├─ If nil: Estimates fee from network
  │   └─ Queries fee estimation API
  │       └─ Returns mainnet-style high fees
  └─ Calculates total package fees needed
      └─ Result: 2092 sat/vB * transaction size
```

### Config Fallback (BarkWalletFFI.swift:144)
```swift
self.config = Config(
    // ...
    fallbackFeeRate: nil,  // Use default fee rate
    // ...
)
```
- Config has `fallbackFeeRate` option, but set to `nil`
- Could be used to set reasonable defaults

---

## Issues with Current Approach

### 1. **No Network-Aware Fee Logic**
- Same fee estimation logic for mainnet and signet
- No distinction between test and production environments
- Signet should use much lower fees

### 2. **No User Control**
- Users can't specify fee priority (low/medium/high)
- No way to override automatic estimation
- All exits use same fee calculation

### 3. **No Fallback Protection**
- No maximum fee rate cap
- No sanity checks on estimated fees
- Can result in impossible-to-complete exits

### 4. **No Transaction Size Consideration**
- Complex exit chains can require significant fees
- User balance not checked before starting exits
- Can create stuck exits that can't progress

### 5. **Config Not Utilized**
- `fallbackFeeRate` parameter available but unused
- Could provide reasonable defaults per network

---

## Comparison: Expected vs Actual

### Signet Expected Behavior
| Scenario | Expected Fee Rate | Expected Total Fee (for 500 byte tx) |
|----------|------------------|--------------------------------------|
| Low Priority | 1-2 sat/vB | 500-1,000 sats |
| Medium Priority | 5-10 sat/vB | 2,500-5,000 sats |
| High Priority | 10-20 sat/vB | 5,000-10,000 sats |

### Signet Actual Behavior
| Scenario | Actual Fee Rate | Actual Total Fee (for 500 byte tx) |
|----------|----------------|-------------------------------------|
| All Exits | 2092 sat/vB | 1,046,000 sats (1.046 million!) |

**Problem**: A 500-byte transaction requires **over 1 million sats** in fees on Signet!

---

## Recommended Solutions

### Solution 1: Network-Aware Default Fees (RECOMMENDED)

**Implementation**: Add network-specific fee defaults in BarkWalletFFI initialization

```swift
init?(networkConfig: NetworkConfig = .signet, securityService: SecurityService? = nil) {
    // ... existing code ...
    
    // Set network-appropriate fallback fee rate
    let fallbackFeeRate: UInt64 = switch networkConfig.networkType {
        case .mainnet: 50        // 50 sat/vB for mainnet (will be overridden by estimation)
        case .signet: 10         // 10 sat/vB for signet (reasonable default)
        case .regtest: 1         // 1 sat/vB for regtest (minimal)
        default: 10
    }
    
    self.config = Config(
        serverAddress: networkConfig.aspBaseURL,
        esploraAddress: networkConfig.esploraBaseURL,
        // ...
        fallbackFeeRate: fallbackFeeRate,  // ✅ Use network-specific default
        // ...
    )
}
```

**Benefits**:
- ✅ Simple, one-line change
- ✅ Network-appropriate fees automatically
- ✅ No changes to Rust library needed
- ✅ Backward compatible

**Location**: `Shared/Data/BarkWalletFFI.swift:144`

---

### Solution 2: Explicit Fee Rate in ExitProgressionService

**Implementation**: Pass explicit fee rate instead of nil

```swift
// In ExitProgressionService.swift:138
func checkAndProgressExits() async {
    // ... existing code ...
    
    // Get network-appropriate fee rate
    let feeRate = getNetworkFeeRate()
    
    // Progress with explicit fee rate
    let statuses = try await wallet.progressExits(feeRateSatPerVb: feeRate)
    
    // ... existing code ...
}

private func getNetworkFeeRate() -> UInt64 {
    // Could check wallet config, or use sensible defaults
    // For now, simple environment detection:
    #if DEBUG
        return 10  // Signet/Regtest default
    #else
        return 50  // Mainnet default (will be estimated higher if needed)
    #endif
}
```

**Benefits**:
- ✅ Service-level control over fees
- ✅ Can implement fee estimation here
- ✅ Easier to add user preferences later

**Drawbacks**:
- ❌ Need to determine fee at service level
- ❌ More code changes required

---

### Solution 3: Fee Priority System

**Implementation**: Add user-selectable fee priority

```swift
enum FeePriority {
    case low      // 1x base rate
    case medium   // 2x base rate
    case high     // 3x base rate
    case custom(UInt64)
}

class ExitProgressionService {
    var feePriority: FeePriority = .medium
    
    private func getFeeRate() -> UInt64 {
        let baseRate: UInt64 = networkType == .mainnet ? 50 : 10
        
        switch feePriority {
        case .low: return baseRate
        case .medium: return baseRate * 2
        case .high: return baseRate * 3
        case .custom(let rate): return rate
        }
    }
}
```

**Benefits**:
- ✅ User control over fees
- ✅ Can optimize for cost vs speed
- ✅ Flexible for future enhancements

**Drawbacks**:
- ❌ Requires UI changes
- ❌ More complex implementation
- ❌ Need to explain fee tiers to users

---

### Solution 4: Fee Estimation Service

**Implementation**: Create dedicated fee estimation service

```swift
class FeeEstimationService {
    func estimateExitFee(
        networkType: NetworkType,
        priority: FeePriority = .medium
    ) async -> UInt64 {
        // Query fee estimation APIs
        // Apply network-specific logic
        // Return sensible fee rate
    }
    
    func validateFeeRate(_ rate: UInt64, for network: NetworkType) -> Bool {
        let maxRate = network == .mainnet ? 1000 : 100
        return rate <= maxRate
    }
}
```

**Benefits**:
- ✅ Centralized fee logic
- ✅ Can query multiple sources
- ✅ Validates reasonable fees
- ✅ Reusable across app

**Drawbacks**:
- ❌ Most complex solution
- ❌ Need API integrations
- ❌ Longer implementation time

---

## Recommended Immediate Fix

### Quick Fix (5 minutes)

**File**: `Shared/Data/BarkWalletFFI.swift:144`

**Change**:
```swift
fallbackFeeRate: nil,  // ❌ Before
```

**To**:
```swift
fallbackFeeRate: networkConfig.networkType == .mainnet ? nil : 10,  // ✅ After
```

**Rationale**:
- Mainnet: Keep `nil` to use network estimation (fee market is real)
- Signet/Regtest: Use 10 sat/vB (reasonable test network rate)
- Single line change
- Immediate improvement

---

## Long-Term Improvements

### Phase 1: Configuration (Week 1)
1. ✅ Implement network-aware fallback fees
2. ✅ Add fee rate validation
3. ✅ Add max fee rate caps per network

### Phase 2: User Control (Week 2-3)
1. Add fee priority selection to exit UI
2. Show estimated fees before exits
3. Allow custom fee rates for advanced users

### Phase 3: Smart Estimation (Month 2)
1. Query multiple fee estimation APIs
2. Implement moving average for stability
3. Add fee history tracking
4. Provide fee recommendations

### Phase 4: Optimization (Month 3+)
1. Batch exits to save fees
2. Implement fee prediction
3. Add fee alerts for unusual rates
4. Optimize CPFP timing

---

## Testing Plan

### Test Scenarios

1. **Signet Small Exit** (750 sats VTXO)
   - Expected fee: 5,000-10,000 sats
   - Should: Complete successfully
   - Currently: Fails (requires 34,750+ sats)

2. **Signet Large Exit** (63,000 sats VTXO)
   - Expected fee: 10,000-20,000 sats
   - Should: Complete successfully
   - Currently: Fails (requires 115,000+ sats)

3. **Mainnet Exit** (100,000 sats VTXO)
   - Expected fee: Variable based on mempool
   - Should: Use market rates
   - Currently: Unknown (likely same issue)

### Validation Criteria

- ✅ Exits complete with <10 sat/vB on Signet
- ✅ Fees scale appropriately with transaction size
- ✅ No "Insufficient Fee" errors for adequately funded exits
- ✅ CPFP transactions broadcast successfully
- ✅ User balance sufficient for typical exit scenarios

---

## Related Files

- `Shared/Services/ExitProgressionService.swift` - Exit progression logic
- `Shared/Data/BarkWalletFFI.swift` - FFI wallet implementation
- `Shared/Data/BDKCpfpHelper.swift` - CPFP transaction creation
- `Shared/Models/NetworkConfig.swift` - Network configuration
- `Shared/Models/FeePriority.swift` - Fee priority enum (exists)

---

## Conclusion

The current fee calculation has a critical flaw: **it doesn't account for network type when estimating fees**. The Bark Rust library appears to use mainnet-style fee estimation (2092 sat/vB) even on Signet, where typical fees are 1-10 sat/vB.

**Immediate Action**: Set `fallbackFeeRate` to network-appropriate defaults (10 sat/vB for Signet)

**Impact**: 
- Reduces exit fees by **~200x** on Signet (from 2092 to 10 sat/vB)
- Makes exits feasible with reasonable onchain balances
- Maintains market-rate estimation on mainnet

**Effort**: Minimal (single line change)

**Risk**: Low (improves test network behavior, preserves mainnet estimation)
