# Live Activity for Exit Progression - Implementation Plan

**Date:** 2026-05-11  
**Status:** Planning  
**Platform:** iOS 16.1+

---

## Executive Summary

This document outlines the implementation plan for adding Live Activity support to the exit progression system in Arke. Live Activities will provide persistent, always-visible status updates on the lock screen and Dynamic Island during the multi-hour unilateral exit process.

**Core Strategy:** Live Activities provide status display, while local notifications provide reliable check-in reminders. The user opening the app progresses exits and updates the Live Activity.

### Why Live Activity + Local Notifications is the Right Approach

1. **Long-running process**: Exits involve 4-8 onchain transactions over many hours (2-8 hours total)
2. **Critical timing**: Users need to check in every ~1.5 hours to progress exits
3. **iOS background limitations**: Live Activities cannot wake the app or execute code
4. **Reliable reminders**: Local notifications have 99%+ delivery reliability
5. **Beautiful status display**: Live Activity shows current state when fresh
6. **No server required**: Local notifications work without backend infrastructure
7. **Battery friendly**: No background processing, just passive display + notification delivery

---

## Current System Analysis

### ExitProgressionService (Arke/Shared/Services/ExitProgressionService.swift:31)

**Current Design:**
- Timer-based: Checks every 5 minutes (configurable)
- Foreground only: Pauses when app backgrounds
- Automatic: Handles full lifecycle from Start → Claimed
- SDK-driven: Polls Bark SDK, which manages complex exit state machine

**Exit Flow (Fully Automatic):**
1. User starts exit → SDK creates exit transactions (fee pre-approved)
2. Service auto-progresses: Start → Processing → AwaitingDelta → Claimable
3. Service auto-claims: Claimable → ClaimInProgress → Claimed
4. Exit complete - funds moved to onchain wallet

**Key Operations:**
- `checkAndProgressExits()`: Main progression loop (runs every 5 min)
- `progressExitsManually()`: Manual trigger for UI buttons
- `autoClaimExits()`: Automatically claims when VTXOs become claimable

### Exit States (Parsed from Bark SDK)

**Primary States:**
- `Start`: Exit initiated, waiting for first broadcast
- `Processing`: Transactions being broadcast/confirmed (has transaction chain)
- `AwaitingDelta`: Waiting for block height delta before claimable
- `Claimable`: Ready to claim funds
- `ClaimInProgress`: Claim transaction broadcast
- `Claimed`: Exit complete, funds claimed

**Transaction States:**
- `VerifyInputs`: Verifying transaction inputs
- `NeedsSignedPackage`: Needs transaction signing
- `NeedsBroadcasting`: Ready to broadcast
- `BroadcastWithCpfp`: Broadcast with CPFP (Child Pays For Parent)
- `AwaitingInputConfirmation`: Waiting for parent tx confirmation
- `Confirmed`: Transaction confirmed onchain

### Current UI Components

1. **ExitStatusDetailView_iOS**: Full detailed view of exit status
   - Shows parsed state, transaction chain, confirmation status
   - VTXO information and amounts
   
2. **TransactionExitDetailsView**: Expandable section in transaction detail
   - Summary of VTXOs exiting
   - Individual VTXO details
   - Linked onchain transactions

3. **Data Views**: Various exit-related data views
   - `UnilateralExitListView_iOS`: List all active exits
   - `ExitVtxoRowView_iOS`: Individual VTXO row
   - `ActiveExitAlertView_iOS`: Alert for active exits

---

## Proposed Architecture

### 1. Live Activity Structure

```swift
// New file: Arke/ArkeMobile/LiveActivity/ExitProgressActivityAttributes.swift

import ActivityKit
import Foundation

struct ExitProgressActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Current exit state
        var currentStep: ExitStep
        var totalSteps: Int
        var stepDescription: String
        
        // Transaction progress
        var transactionsConfirmed: Int
        var totalTransactions: Int
        
        // Timing information
        var lastUpdated: Date
        var needsCheckIn: Bool  // NEW: Indicates staleness, user should check in
        
        // Block information (optional, for advanced users)
        var currentBlockHeight: UInt32?
        var targetBlockHeight: UInt32?
        var blocksRemaining: Int?
        
        // Status indicators
        var isWaitingForBlocks: Bool
        var isClaimable: Bool
        var hasError: Bool
        var errorMessage: String?
    }
    
    // Static data (doesn't change during the activity)
    var exitId: String  // Primary VTXO ID or exit batch identifier
    var totalAmountSats: UInt64
    var startTime: Date
}

enum ExitStep: Int, Codable {
    case start = 1
    case broadcasting = 2
    case confirming = 3
    case awaitingDelta = 4
    case claiming = 5
    case completed = 6
    
    var displayName: String {
        switch self {
        case .start: return "Starting"
        case .broadcasting: return "Broadcasting"
        case .confirming: return "Confirming"
        case .awaitingDelta: return "Waiting"
        case .claiming: return "Claiming"
        case .completed: return "Complete"
        }
    }
}
```

### 2. Live Activity Widget

```swift
// New file: Arke/ArkeMobile/LiveActivity/ExitProgressLiveActivity.swift

import ActivityKit
import WidgetKit
import SwiftUI

struct ExitProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExitProgressActivityAttributes.self) { context in
            // Lock screen / banner UI
            ExitProgressLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.needsCheckIn ? 
                        "exclamationmark.circle.fill" : "arrow.down.circle")
                        .foregroundColor(context.state.needsCheckIn ? .orange : .blue)
                        .symbolEffect(.bounce, value: context.state.needsCheckIn)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Text(context.state.stepDescription)
                            .font(.headline)
                        if context.state.needsCheckIn {
                            Text("Check app to continue")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("\(context.state.transactionsConfirmed)/\(context.state.totalTransactions)")
                            .font(.caption)
                        Text("confirmed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        ProgressView(value: Double(context.state.currentStep.rawValue), 
                                    total: Double(context.state.totalSteps))
                        Text("\(context.state.currentStep.rawValue)/\(context.state.totalSteps)")
                            .font(.caption)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.needsCheckIn ? 
                    "exclamationmark.triangle.fill" : "arrow.down.circle")
                    .foregroundColor(context.state.needsCheckIn ? .orange : .blue)
            } compactTrailing: {
                Text("\(context.state.currentStep.rawValue)/\(context.state.totalSteps)")
                    .font(.caption2)
            } minimal: {
                Image(systemName: context.state.needsCheckIn ? 
                    "exclamationmark.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(context.state.needsCheckIn ? .orange : .blue)
            }
        }
    }
}
```

### 3. Integration with ExitProgressionService

**Enhanced Service Methods:**

```swift
// Add to ExitProgressionService

/// Active Live Activity for exit progression
private var currentActivity: Activity<ExitProgressActivityAttributes>?

/// Start Live Activity when exit begins
func startLiveActivity(for exitVtxos: [ExitVtxo]) async {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        print("⚠️ Live Activities not enabled")
        return
    }
    
    let totalAmount = exitVtxos.reduce(0) { $0 + $1.amountSats }
    let attributes = ExitProgressActivityAttributes(
        exitId: exitVtxos.first?.vtxoId ?? "unknown",
        totalAmountSats: totalAmount,
        startTime: Date()
    )
    
    let initialState = ExitProgressActivityAttributes.ContentState(
        currentStep: .start,
        totalSteps: 6,
        stepDescription: "Starting exit process",
        transactionsConfirmed: 0,
        totalTransactions: 0,
        lastCheckTime: Date(),
        estimatedNextCheckTime: Date().addingTimeInterval(5 * 60),
        isWaitingForBlocks: false,
        isClaimable: false,
        hasError: false
    )
    
    do {
        currentActivity = try Activity.request(
            attributes: attributes,
            content: .init(state: initialState, staleDate: nil)
        )
        print("✅ Live Activity started: \(currentActivity?.id ?? "unknown")")
    } catch {
        print("❌ Failed to start Live Activity: \(error)")
    }
}

/// Update Live Activity with current exit state
func updateLiveActivity(with status: ExitTransactionStatus) async {
    guard let activity = currentActivity else { return }
    
    let contentState = buildContentState(from: status)
    
    await activity.update(
        ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(10 * 60) // Stale after 10 min
        )
    )
}

/// End Live Activity when exit completes
func endLiveActivity(success: Bool) async {
    guard let activity = currentActivity else { return }
    
    let finalState = ExitProgressActivityAttributes.ContentState(
        currentStep: success ? .completed : .start,
        totalSteps: 6,
        stepDescription: success ? "Exit completed!" : "Exit stopped",
        transactionsConfirmed: 0,
        totalTransactions: 0,
        lastCheckTime: Date(),
        isWaitingForBlocks: false,
        isClaimable: false,
        hasError: !success
    )
    
    await activity.end(
        ActivityContent(state: finalState, staleDate: nil),
        dismissalPolicy: .after(.now + 3600) // Dismiss after 1 hour
    )
    
    currentActivity = nil
}

/// Build ContentState from ExitTransactionStatus
private func buildContentState(from status: ExitTransactionStatus) -> ExitProgressActivityAttributes.ContentState {
    // Parse status to determine current step, progress, etc.
    let parsed = ExitStatusParser.parseState(status.state)
    
    let (step, description, isWaiting, isClaimable) = parseExitState(parsed)
    
    return ExitProgressActivityAttributes.ContentState(
        currentStep: step,
        totalSteps: 6,
        stepDescription: description,
        transactionsConfirmed: countConfirmedTransactions(status),
        totalTransactions: status.transactionCount,
        lastCheckTime: Date(),
        estimatedNextCheckTime: Date().addingTimeInterval(checkInterval),
        currentBlockHeight: extractCurrentBlockHeight(parsed),
        targetBlockHeight: extractTargetBlockHeight(parsed),
        isWaitingForBlocks: isWaiting,
        isClaimable: isClaimable,
        hasError: false
    )
}

private func parseExitState(_ parsed: ParsedExitState?) -> (ExitStep, String, Bool, Bool) {
    guard let parsed = parsed else {
        return (.start, "Processing...", false, false)
    }
    
    switch parsed {
    case .start:
        return (.start, "Starting exit", false, false)
    case .processing:
        return (.broadcasting, "Broadcasting transactions", false, false)
    case .awaitingDelta(let data):
        let blocksLeft = data.claimableHeight > data.tipHeight ? 
            data.claimableHeight - data.tipHeight : 0
        return (.awaitingDelta, "Waiting for \(blocksLeft) blocks", true, false)
    case .claimable:
        return (.claiming, "Claiming funds", false, true)
    case .claimInProgress:
        return (.claiming, "Claim transaction confirming", false, false)
    case .claimed:
        return (.completed, "Exit complete", false, false)
    case .unparsed:
        return (.start, "Processing...", false, false)
    }
}
```

**Modified checkAndProgressExits():**

```swift
private func checkAndProgressExits() async {
    // ... existing code ...
    
    // Update Live Activity if active
    if let currentActivity = currentActivity {
        let exitVtxos = try? await wallet.getExitVtxos()
        if let firstVtxo = exitVtxos?.first {
            if let status = try? await wallet.getExitStatus(
                vtxoId: firstVtxo.vtxoId,
                includeHistory: false,
                includeTransactions: true
            ) {
                await updateLiveActivity(with: status)
            }
        }
    }
    
    // Check if all exits completed
    let hasPending = try? await wallet.hasPendingExits()
    if hasPending == false && currentActivity != nil {
        await endLiveActivity(success: true)
    }
}
```

### 4. Lock Screen View with Check-In State

```swift
// New file: Arke/ArkeMobile/LiveActivity/ExitProgressLockScreenView.swift

import ActivityKit
import SwiftUI

struct ExitProgressLockScreenView: View {
    let context: ActivityViewContext<ExitProgressActivityAttributes>
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: context.state.needsCheckIn ? 
                    "exclamationmark.circle.fill" : "arrow.down.circle")
                    .foregroundColor(context.state.needsCheckIn ? .orange : .blue)
                
                Text(context.state.stepDescription)
                    .font(.headline)
                
                Spacer()
            }
            
            // Progress bar
            ProgressView(value: Double(context.state.currentStep.rawValue), 
                        total: Double(context.state.totalSteps))
                .tint(context.state.needsCheckIn ? .orange : .blue)
            
            HStack {
                Text("Step \(context.state.currentStep.rawValue) of \(context.state.totalSteps)")
                    .font(.caption)
                Spacer()
                if context.state.needsCheckIn {
                    Text("⚠️ Check-in needed")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("\(context.state.transactionsConfirmed)/\(context.state.totalTransactions) confirmed")
                        .font(.caption)
                }
            }
            
            // Time since last update
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("Updated \(context.state.lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if context.state.needsCheckIn {
                    Text("Tap notification to update")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}
```

### 5. Coordinated Service Implementation

**Primary Strategy:** Live Activity + Local Notifications working together.

```swift
// Add to ExitProgressionService

class ExitProgressionService {
    
    private var currentActivity: Activity<ExitProgressActivityAttributes>?
    private var scheduledNotificationIds: [String] = []
    private var lastCheckTime: Date?
    
    // MARK: - Start Exit Monitoring
    
    func startExitMonitoring(for exitVtxos: [ExitVtxo]) async {
        print("🚀 Starting exit monitoring for \(exitVtxos.count) VTXO(s)")
        
        // Start Live Activity
        await startLiveActivity(for: exitVtxos)
        
        // Schedule check-in reminder sequence
        await scheduleCheckInSequence()
    }
    
    // MARK: - Check-In Notification Sequence
    
    private func scheduleCheckInSequence() async {
        // Clear any existing notifications
        cancelAllCheckInReminders()
        
        // Schedule reminders at 90-minute intervals
        let intervals: [TimeInterval] = [
            90 * 60,      // 1.5 hours
            90 * 60,      // 3.0 hours
            90 * 60,      // 4.5 hours
            90 * 60,      // 6.0 hours
            90 * 60       // 7.5 hours
        ]
        
        var cumulativeTime: TimeInterval = 0
        for (index, interval) in intervals.enumerated() {
            cumulativeTime += interval
            let notificationDate = Date().addingTimeInterval(cumulativeTime)
            
            let id = await scheduleCheckInNotification(
                at: notificationDate,
                checkNumber: index + 1
            )
            scheduledNotificationIds.append(id)
        }
        
        print("✅ Scheduled \(intervals.count) check-in reminders")
    }
    
    private func scheduleCheckInNotification(at date: Date, checkNumber: Int) async -> String {
        let id = "exit-check-\(UUID().uuidString)"
        
        let content = UNMutableNotificationContent()
        content.title = "Exit Progress Check-In"
        content.body = "Tap to check on your exit and keep it moving"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0
        
        // Action category for future interactive notifications
        content.categoryIdentifier = "EXIT_PROGRESS"
        
        // Deep link data
        content.userInfo = [
            "action": "check_exit_progress",
            "checkNumber": checkNumber,
            "scheduledFor": date.timeIntervalSince1970
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: date.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📅 Scheduled check-in #\(checkNumber) for \(date)")
        } catch {
            print("❌ Failed to schedule notification: \(error)")
        }
        
        return id
    }
    
    // MARK: - User Check-In Handler
    
    func userCheckedIn() async {
        print("👤 User checked in")
        lastCheckTime = Date()
        
        // Progress exits
        await checkAndProgressExits()
        
        // Update Live Activity to "fresh" state
        await updateLiveActivityAfterCheckIn()
        
        // Reschedule notifications (reset the clock)
        await scheduleCheckInSequence()
    }
    
    private func updateLiveActivityAfterCheckIn() async {
        guard let activity = currentActivity else { return }
        
        // Get latest exit status
        guard let status = try? await getLatestExitStatus() else {
            print("⚠️ Could not get exit status for Live Activity update")
            return
        }
        
        let contentState = buildContentState(
            from: status,
            needsCheckIn: false  // User just checked in!
        )
        
        await activity.update(
            ActivityContent(
                state: contentState,
                staleDate: Date().addingTimeInterval(120 * 60) // Stale in 2 hours
            )
        )
        
        print("✅ Live Activity updated (fresh)")
    }
    
    // MARK: - Staleness Detection
    
    func markLiveActivityAsNeedingCheckIn() async {
        guard let activity = currentActivity else { return }
        
        let currentState = await activity.contentState
        
        // Only update if not already marked
        guard !currentState.needsCheckIn else { return }
        
        var updatedState = currentState
        updatedState.needsCheckIn = true
        
        await activity.update(
            ActivityContent(state: updatedState, staleDate: nil)
        )
        
        print("⚠️ Marked Live Activity as needing check-in")
    }
    
    // MARK: - Cleanup
    
    private func cancelAllCheckInReminders() {
        guard !scheduledNotificationIds.isEmpty else { return }
        
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: scheduledNotificationIds)
        
        print("🗑️ Cancelled \(scheduledNotificationIds.count) pending notifications")
        scheduledNotificationIds.removeAll()
    }
    
    func stopExitMonitoring(success: Bool) async {
        print("🛑 Stopping exit monitoring (success: \(success))")
        
        await endLiveActivity(success: success)
        cancelAllCheckInReminders()
    }
    
    // MARK: - Helper Methods
    
    private func buildContentState(from status: ExitTransactionStatus, needsCheckIn: Bool) -> ExitProgressActivityAttributes.ContentState {
        let parsed = ExitStatusParser.parseState(status.state)
        let (step, description, isWaiting, isClaimable) = parseExitState(parsed)
        
        return ExitProgressActivityAttributes.ContentState(
            currentStep: step,
            totalSteps: 6,
            stepDescription: description,
            transactionsConfirmed: countConfirmedTransactions(status),
            totalTransactions: status.transactionCount,
            lastUpdated: Date(),
            needsCheckIn: needsCheckIn,
            currentBlockHeight: extractCurrentBlockHeight(parsed),
            targetBlockHeight: extractTargetBlockHeight(parsed),
            blocksRemaining: extractBlocksRemaining(parsed),
            isWaitingForBlocks: isWaiting,
            isClaimable: isClaimable,
            hasError: false
        )
    }
}
```

### 6. App Delegate Integration

```swift
// In AppDelegate or SceneDelegate

func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    let userInfo = response.notification.request.content.userInfo
    
    if userInfo["action"] as? String == "check_exit_progress" {
        // User tapped the notification
        Task {
            await walletManager.exitProgressionService?.userCheckedIn()
        }
        
        // Navigate to exit status screen
        navigateToExitStatus()
    }
    
    completionHandler()
}

// Also handle foreground app activation
func sceneWillEnterForeground(_ scene: UIScene) {
    // User opened app - check if we have active exits
    Task {
        if await walletManager.exitProgressionService?.hasActiveExits() == true {
            // Progress exits and update Live Activity
            await walletManager.exitProgressionService?.userCheckedIn()
        }
    }
}
```

**Info.plist Changes:**

```xml
<!-- Add to ArkeMobile Info.plist -->
<key>NSSupportsLiveActivities</key>
<true/>
```

---

## Implementation Phases

### Phase 1: Core Live Activity Infrastructure (Week 1)
**Goal:** Basic Live Activity that shows exit status

**Tasks:**
1. Create `ExitProgressActivityAttributes` with ContentState
2. Create `ExitProgressLiveActivity` widget with basic UI
   - Lock screen view
   - Dynamic Island minimal UI
3. Add Live Activity entitlements to ArkeMobile
4. Add `NSSupportsLiveActivities` to Info.plist
5. Test basic Live Activity start/update/end lifecycle

**Deliverable:** Live Activity appears on lock screen showing "Exit in progress" with basic step count.

### Phase 2: ExitProgressionService Integration (Week 2)
**Goal:** Automatically manage Live Activity during exit progression

**Tasks:**
1. Add Live Activity management methods to `ExitProgressionService`
   - `startLiveActivity(for:)`
   - `updateLiveActivity(with:)`
   - `endLiveActivity(success:)`
2. Integrate Live Activity updates into `checkAndProgressExits()`
3. Add helper methods to parse `ExitTransactionStatus` into `ContentState`
4. Handle Live Activity lifecycle (start when exit begins, end when complete)
5. Test with real exit progression

**Deliverable:** Live Activity automatically updates as exit progresses through states.

### Phase 3: Rich Dynamic Island UI (Week 2-3)
**Goal:** Beautiful, informative Dynamic Island experience

**Tasks:**
1. Design and implement expanded Dynamic Island regions
   - Leading: Progress indicator / icon
   - Trailing: Transaction count / block info
   - Center: Step description
   - Bottom: Detailed status / time until next check
2. Add compact and minimal states
3. Implement animations for state transitions
4. Add color coding (orange for in-progress, green for claimable/complete)
5. Test on iPhone 14 Pro+ with Dynamic Island

**Deliverable:** Rich, animated Dynamic Island that shows detailed exit progress.

### Phase 4: Local Notification Integration (Week 3)
**Goal:** Reliable check-in reminders via local notifications

**Tasks:**
1. Implement notification scheduling in `ExitProgressionService`
   - `scheduleCheckInSequence()` for 90-minute intervals
   - `scheduleCheckInNotification()` with deep link data
2. Add notification handling in AppDelegate
   - Handle `userNotificationCenter(_:didReceive:)`
   - Call `userCheckedIn()` when notification tapped
3. Implement foreground activation handling
   - Auto-progress when app comes to foreground with active exits
4. Add notification permission request flow
5. Test notification delivery and app activation
6. Test deep linking to exit status screen

**Deliverable:** Reliable check-in reminders that open app and progress exits.

### Phase 5: Polish & Edge Cases (Week 4)
**Goal:** Handle all edge cases and error scenarios

**Tasks:**
1. Handle multiple exits (show aggregate status)
2. Handle exit errors (display error in Live Activity)
3. Handle app termination (restore Live Activity on restart)
4. Add user preference to disable Live Activity
5. Handle system dismissal of Live Activity
6. Add analytics/logging for Live Activity lifecycle
7. Test on various iOS versions (16.1+)
8. Test on devices without Dynamic Island

**Deliverable:** Robust Live Activity system that handles all scenarios.

### Phase 6: Testing & Refinement (Week 5)
**Goal:** Comprehensive testing and user feedback

**Tasks:**
1. End-to-end testing on real Bitcoin (signet/testnet)
2. Test background execution over extended periods
3. Test with poor network conditions
4. Verify battery impact (should be minimal - just status updates)
5. User feedback and iteration
6. Documentation for users

**Deliverable:** Production-ready Live Activity for exit progression.

---

## Technical Considerations

### Live Activity Limitations

1. **Size Limits**: Activities have memory and update frequency limits
   - Keep ContentState small (<4KB recommended)
   - Limit updates to every 30-60 seconds minimum
   
2. **Duration**: Live Activities can last up to 8 hours before iOS dismisses them
   - For longer exits, may need to restart the activity
   
3. **Background Updates**: Can only update from background during specific circumstances
   - Background App Refresh
   - Silent push notifications (requires server)
   - Location updates (not applicable)

### Primary Strategy: Live Activity + Local Notifications

**Core Principle:** Don't fight iOS limitations - work with them.

**How It Works:**
1. **Live Activity** displays last known status (passive, no execution)
2. **Local Notifications** reliably remind user to check in (99%+ delivery)
3. **User opens app** → exits progress → Live Activity updates (reliable)
4. **Repeat** every 90 minutes until exit complete

**Why This Works:**
- ✅ No unreliable background tasks (BGProcessingTask has 10-30% success rate)
- ✅ No server infrastructure needed (no silent push notifications)
- ✅ Battery friendly (no background processing)
- ✅ Simple architecture (easy to maintain)
- ✅ Reliable (local notifications work, user controls progression)

**User Experience:**
```
0:00 - Start exit
       └─ Live Activity: "Starting exit..."
       └─ Notifications scheduled: 1.5h, 3h, 4.5h, 6h, 7.5h

1:30 - 🔔 Notification: "Tap to check on your exit"
       └─ User taps → App opens → Exits progress → Live Activity updates
       └─ Notifications rescheduled from now

3:00 - 🔔 Next reminder
       └─ Repeat...

4:15 - Exit complete!
       └─ Live Activity: "✅ Complete!"
       └─ All notifications cancelled
```

### Exit Process Considerations

**From Analysis:**
- Exits are unilateral (don't depend on ASP server)
- Require broadcasting onchain transactions to Bitcoin network
- Transaction confirmations take ~10 minutes per block
- Total exit time: 4-8 transactions × ~10 min/tx = 40-80 minutes minimum
- Plus timelock waits (AwaitingDelta phase) which can be hours
- **Total duration: 2-8 hours typical**

**Why Local Notifications Work:**
- 90-minute check-in interval is reasonable for 2-8 hour process
- 4-5 notifications max per exit (not spammy)
- Delays if user misses notification don't break the exit
- Live Activity shows staleness ("Last updated: 2 hours ago")

**User Behavior:**
- Most users will respond to 1st or 2nd notification
- Some will ignore and check manually later
- Either way, exit progresses when they open app
- No funds lost if user is slow to respond

### Privacy & Security

**Considerations:**
1. Live Activity is visible on lock screen (no authentication needed)
   - Don't show exact amounts (or make optional)
   - Don't show full addresses/transaction IDs
   - Keep descriptions generic ("Exit in progress")

2. Sensitive data in ContentState
   - ContentState is logged by system
   - Avoid including seed phrases, private keys (obviously!)
   - Consider using exit IDs rather than VTXO IDs

---

## User Permissions Required

### Overview

This feature requires **one** user permission:

| Permission | Required? | When to Request | What Happens if Denied |
|------------|-----------|-----------------|------------------------|
| **Notifications** | Yes | Before starting first exit | No check-in reminders, Live Activity still works but goes stale |
| **Live Activities** | No (automatic) | N/A | User can disable in iOS Settings if desired |

### 1. Notification Permission (REQUIRED)

**iOS Permission:** `UNAuthorizationOptions: [.alert, .sound, .badge]`

**When to Request:**
- When user starts their **first exit**
- Show explanation dialog first (see below)
- Don't request on app launch (feels invasive)

**Permission Request Flow:**

```swift
// Step 1: Show explanation sheet BEFORE requesting permission
struct NotificationPermissionExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Stay Updated on Your Exit")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Exits take 2-8 hours and require periodic check-ins. We'll send you reminders every 90 minutes so you don't have to keep the app open.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                PermissionBenefitRow(
                    icon: "clock",
                    title: "Timely Reminders",
                    description: "Get notified every 90 minutes to check on your exit"
                )
                
                PermissionBenefitRow(
                    icon: "lock.shield",
                    title: "Keep Your Funds Safe",
                    description: "Don't miss check-ins and risk delays"
                )
                
                PermissionBenefitRow(
                    icon: "iphone",
                    title: "Close the App",
                    description: "No need to keep Arke open for hours"
                )
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            Button("Enable Notifications") {
                dismiss()
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Button("Continue Without Notifications") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

// Step 2: Request actual permission
func requestNotificationPermission() async -> Bool {
    let center = UNUserNotificationCenter.current()
    
    // Check if already determined
    let settings = await center.notificationSettings()
    
    switch settings.authorizationStatus {
    case .authorized:
        print("✅ Notifications already authorized")
        return true
        
    case .denied:
        print("❌ Notifications previously denied")
        // Show alert directing user to Settings
        await showNotificationsDeniedAlert()
        return false
        
    case .notDetermined:
        // Request permission for the first time
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied by user")
                // Show alert explaining implications
                await showNotificationsDeclinedAlert()
            }
            
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
        
    case .provisional, .ephemeral:
        // Treat as not having full permission
        return false
        
    @unknown default:
        return false
    }
}

// Step 3: Handle "Denied" state - direct to Settings
func showNotificationsDeniedAlert() async {
    let alert = UIAlertController(
        title: "Notifications Disabled",
        message: "Enable notifications in Settings to receive exit check-in reminders. Without reminders, you'll need to manually check the app every 90 minutes.",
        preferredStyle: .alert
    )
    
    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    })
    
    alert.addAction(UIAlertAction(title: "Continue Anyway", style: .cancel))
    
    // Present alert
    await MainActor.run {
        // Get top view controller and present
    }
}

// Step 4: Handle "Declined" state - explain implications
func showNotificationsDeclinedAlert() async {
    let alert = UIAlertController(
        title: "Check-In Reminders Disabled",
        message: "Without notifications, you'll need to manually check the app every 90 minutes during your exit. You can enable notifications later in iOS Settings.",
        preferredStyle: .alert
    )
    
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    
    // Present alert
}
```

**Integration into Exit Flow:**

```swift
// In UI where user initiates exit
Button("Start Exit") {
    Task {
        // Check notification permission first
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        
        if notificationSettings.authorizationStatus == .notDetermined {
            // Show explanation sheet
            showNotificationExplanation = true
        } else {
            // Already determined, proceed
            await startExit()
        }
    }
}
.sheet(isPresented: $showNotificationExplanation) {
    NotificationPermissionExplanationSheet {
        Task {
            let granted = await requestNotificationPermission()
            await startExit()
        }
    }
}
```

**Note:** Arke already has notification settings in `SettingsView_iOS.swift` (lines 144-173). Ensure this setting is also easily accessible from exit-related views for users who initially declined but later want to enable.

**What Happens if Permission Denied:**
- ✅ Live Activity still works (shows status when fresh)
- ❌ No check-in reminders sent
- ⚠️ Show in-app banner with settings link: "Enable notifications for check-in reminders"
- ⚠️ Live Activity will go stale unless user manually checks app
- 💡 Suggest: "Set a timer to check back every 90 minutes"

**Recommended UI Enhancements:**

1. **Exit Status View Banner** (when notifications disabled):
```swift
// Show banner at top of exit status view
if notificationStatus == .denied {
    Banner(
        icon: "bell.slash.fill",
        title: "Notifications Disabled",
        message: "Enable notifications in Settings to receive check-in reminders",
        action: {
            // Deep link to Settings or show sheet explaining how to enable
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        },
        actionLabel: "Open Settings"
    )
    .padding()
}
```

2. **Quick Settings Toggle** (in exit detail view):
```swift
// In UnilateralExitListView_iOS or ExitStatusDetailView_iOS
Section {
    Toggle("Check-in Reminders", isOn: $notificationsEnabled)
        .onChange(of: notificationsEnabled) { _, newValue in
            if newValue {
                Task {
                    await checkAndRequestNotificationPermission()
                }
            }
        }
} footer: {
    Text("Get notified every 90 minutes to check on your exit progress")
}
```

3. **Settings Deep Link** (from exit views):
```swift
// Add to navigation bar or as button
Button("Notification Settings") {
    // Navigate to settings or show notification permission sheet
}
```

### 2. Live Activity Permission (Automatic)

**Good News:** Live Activities don't require explicit permission!

**How it Works:**
- iOS automatically allows Live Activities
- User can disable in Settings → [App Name] → Live Activities
- Your code should check: `ActivityAuthorizationInfo().areActivitiesEnabled`
- If disabled, skip starting Live Activity (no error, just silently skip)

```swift
func startLiveActivity(for exitVtxos: [ExitVtxo]) async {
    // Check if Live Activities are enabled
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        print("⚠️ Live Activities disabled by user")
        // This is OK - continue without Live Activity
        // Notifications will still work
        return
    }
    
    // Proceed to start Live Activity
    // ...
}
```

**User Can Disable:**
- Settings → Arke → Live Activities → Toggle Off
- No permission dialog needed
- No re-prompting possible (user's choice)

### 3. Background App Refresh (Optional)

**Not required for this implementation** (we're not using background tasks), but mentioned for completeness:

**If you add background tasks later:**
- Settings → Arke → Background App Refresh
- User can disable per-app
- No explicit permission request
- Check with: `UIApplication.shared.backgroundRefreshStatus`

### Permission Summary

**User Will See:**
1. ✅ **One permission dialog**: Notifications (first exit)
2. ❌ **No permission dialog**: Live Activities (automatic)
3. ✅ **Can disable later**: Both in iOS Settings

**Best Practices:**
- Request notifications **in context** (when starting first exit)
- Show **clear explanation** before requesting
- Handle **all denial scenarios** gracefully
- Provide **fallback experience** (manual checking)
- Show **helpful in-app guidance** if permissions denied
- **Never repeatedly prompt** (respect user's decision)

### Testing Permission States

```swift
// Test helper to check all permission states
func checkAllPermissions() async -> PermissionStatus {
    let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
    let liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    
    return PermissionStatus(
        notifications: notificationSettings.authorizationStatus,
        liveActivities: liveActivitiesEnabled
    )
}

struct PermissionStatus {
    let notifications: UNAuthorizationStatus
    let liveActivities: Bool
    
    var isOptimal: Bool {
        notifications == .authorized && liveActivities
    }
    
    var canSendReminders: Bool {
        notifications == .authorized
    }
    
    var canShowLiveActivity: Bool {
        liveActivities
    }
    
    var userFacingMessage: String {
        switch (notifications, liveActivities) {
        case (.authorized, true):
            return "✅ All features enabled"
        case (.authorized, false):
            return "⚠️ Live Activity disabled (check-ins still work)"
        case (.denied, true):
            return "⚠️ Notifications disabled (Live Activity works but will go stale)"
        case (.denied, false):
            return "❌ Both disabled (manual checking required)"
        default:
            return "⚠️ Notifications not configured"
        }
    }
}
```

---

## Critical Reminders & Gotchas

### Live Activities

#### 1. **Entitlements & Info.plist (REQUIRED)**
```xml
<!-- Info.plist -->
<key>NSSupportsLiveActivities</key>
<true/>
```

Without this, `Activity.request()` will fail silently or throw an error.

#### 2. **Widget Extension Target**
Live Activities require a **Widget Extension** target:
- Create new target: File → New → Target → Widget Extension
- Name it something like `ArkeWidgets`
- Include Live Activity in the extension
- The widget extension runs in a separate process

#### 3. **Shared Code Between App and Widget**
Widget extension needs access to:
- `ExitProgressActivityAttributes` (must be in shared framework)
- Any models used in ContentState
- Asset catalog (SF Symbols work, custom assets need to be in widget target)

**Solution:** Put Live Activity code in `Shared` target or create shared framework.

#### 4. **ContentState Size Limits**
- Keep ContentState **under 4KB** (system limit)
- Avoid large strings, arrays, or nested objects
- Use primitive types where possible
- Don't include: full transaction hex, large arrays of data

#### 5. **Update Frequency Limits**
- iOS throttles updates if you update too frequently
- Minimum recommended interval: **30-60 seconds**
- Our case: Update only when user checks in (every 90 min) - perfect!

#### 6. **Live Activity Lifetime**
- Maximum duration: **8 hours** (iOS dismisses after this)
- Can be dismissed by user at any time (swipe away)
- Can be dismissed by system if too many activities active
- **Handle dismissal gracefully** - check if activity is still active before updating

#### 7. **Testing Live Activities**
- Simulator support is limited (no Dynamic Island preview)
- **Must test on real device** for accurate behavior
- iPhone 14 Pro+ for Dynamic Island testing
- Live Activities don't appear in notification center

#### 8. **Activity State Persistence**
- Activities persist across app termination
- Must handle case where app restarts but activity is still live
- Store activity ID in UserDefaults to reattach
- Use `Activity<T>.activities` to enumerate existing activities

```swift
// Reattach to existing activity on app launch
func reattachToExistingActivity() async {
    for activity in Activity<ExitProgressActivityAttributes>.activities {
        if activity.attributes.exitId == currentExitId {
            self.currentActivity = activity
            print("✅ Reattached to existing Live Activity")
            return
        }
    }
}
```

### Local Notifications

#### 1. **Permission Request (REQUIRED)**
Local notifications require explicit user permission:

```swift
func requestNotificationPermission() async -> Bool {
    let center = UNUserNotificationCenter.current()
    
    do {
        let granted = try await center.requestAuthorization(
            options: [.alert, .sound, .badge]
        )
        print(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")
        return granted
    } catch {
        print("❌ Failed to request notification permission: \(error)")
        return false
    }
}
```

**When to request:**
- When user starts their first exit
- Show explanation dialog first ("We'll remind you to check in")
- Don't request on app launch (feels spammy)

#### 2. **Do Not Disturb / Focus Modes**
- Notifications are suppressed during Do Not Disturb
- Use `.timeSensitive` interruption level to break through DND
- Requires "Time Sensitive Notifications" capability
- Still respects user's "Always Allow" vs "Deliver Quietly" settings

```swift
content.interruptionLevel = .timeSensitive  // Break through DND
content.relevanceScore = 1.0  // High priority
```

#### 3. **Notification Scheduling Limits**
- iOS limits to **64 pending notifications** per app
- Scheduling more causes oldest to be dropped
- Our case: Max 5 notifications per exit - well within limit

#### 4. **Time Zones & Date Handling**
- `UNTimeIntervalNotificationTrigger` uses relative time (seconds from now)
- Handles time zone changes automatically
- Don't use `UNCalendarNotificationTrigger` for our use case (too complex)

#### 5. **Notification Identifiers**
- Must be unique for each notification
- Use UUID to avoid collisions: `"exit-check-\(UUID().uuidString)"`
- Store IDs to cancel later: `scheduledNotificationIds.append(id)`
- Cancel old notifications before rescheduling

#### 6. **App State When Notification Taps**
Three scenarios:
```swift
// 1. App not running → App launches
// 2. App in background → App comes to foreground
// 3. App in foreground → Notification banner appears, tap does nothing special

// Handle all three in:
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    // Your handling code
    completionHandler()  // MUST call this!
}
```

#### 7. **Notification Categories (Optional but Useful)**
Register categories for interactive notifications (v2 feature):

```swift
let viewAction = UNNotificationAction(
    identifier: "VIEW_EXIT",
    title: "View Progress",
    options: [.foreground]
)

let category = UNNotificationCategory(
    identifier: "EXIT_PROGRESS",
    actions: [viewAction],
    intentIdentifiers: [],
    options: []
)

UNUserNotificationCenter.current().setNotificationCategories([category])
```

### Development & Debugging

#### 1. **Simulator Limitations**
- ✅ Local notifications work in simulator
- ❌ Live Activities have limited simulator support (no Dynamic Island)
- ❌ Background execution doesn't work realistically in simulator
- **Solution:** Use real device for accurate testing

#### 2. **Xcode Debugging Live Activities**
- Widget extension runs in separate process
- Attach debugger: Debug → Attach to Process → ArkeWidgets
- Or set breakpoint and it will pause when hit
- Use `print()` statements (show up in Console)

#### 3. **Live Activity Not Appearing?**
Check these:
- [ ] `NSSupportsLiveActivities` in Info.plist
- [ ] Widget extension target created and included in scheme
- [ ] `ActivityAttributes` is `Codable` and `Hashable`
- [ ] ContentState is under 4KB
- [ ] Not on iOS < 16.1
- [ ] Activity authorization: `ActivityAuthorizationInfo().areActivitiesEnabled`

#### 4. **Notification Not Firing?**
Check these:
- [ ] Permission granted (`requestAuthorization`)
- [ ] Notification identifier is unique
- [ ] Trigger time is in the future
- [ ] App has network connectivity (for time sync)
- [ ] Device not in Low Power Mode (delays non-critical notifications)
- [ ] Not in Do Not Disturb (unless `.timeSensitive`)

#### 5. **Testing Notification Scheduling**
Override trigger time for testing:

```swift
#if DEBUG
let trigger = UNTimeIntervalNotificationTrigger(
    timeInterval: 10,  // 10 seconds instead of 90 minutes
    repeats: false
)
#else
let trigger = UNTimeIntervalNotificationTrigger(
    timeInterval: 90 * 60,
    repeats: false
)
#endif
```

### Production Considerations

#### 1. **Analytics & Monitoring**
Track these metrics:
- Live Activity start success rate
- Live Activity update success rate
- Notification delivery rate (check pending vs delivered)
- User response time to notifications
- Exit completion rate with vs without Live Activity

#### 2. **Error Handling**
Always handle failures gracefully:

```swift
do {
    currentActivity = try Activity.request(...)
} catch {
    print("❌ Failed to start Live Activity: \(error)")
    // Continue without Live Activity - notifications still work
}
```

#### 3. **User Settings**
Allow users to disable:
- Live Activity (some users find it distracting)
- Notification reminders (some users want manual checking)
- At least one should be enabled (warn if both disabled)

#### 4. **Battery Testing**
- Live Activities are passive (minimal battery impact)
- Local notifications are lightweight
- Test on real device over 8+ hour period
- Monitor battery usage in Settings → Battery

#### 5. **Accessibility**
- Live Activity text should work with Dynamic Type
- Use `.minimumScaleFactor()` for text that must fit
- Provide VoiceOver labels for icons
- Test with VoiceOver enabled

### Common Pitfalls

❌ **Don't:**
- Store large objects in ContentState
- Update Live Activity more than once per minute
- Assume background tasks will run (they won't reliably)
- Force unwrap `currentActivity` (can be nil if dismissed)
- Forget to call notification completion handler

✅ **Do:**
- Keep ContentState minimal and primitive
- Check if activity exists before updating
- Handle all three notification app states
- Test on real device, not just simulator
- Provide fallback if Live Activity fails
- Request notification permission at right time
- Cancel old notifications before rescheduling

---

## UI/UX Design Guidelines

### Lock Screen View States

**Fresh State (< 30 minutes old):**
```
┌─────────────────────────────────────┐
│ 🔵 Confirming Transactions          │
│ ■■■□□□ Step 3 of 6                  │
│ 2 of 5 transactions confirmed       │
│ Updated 5 minutes ago               │
└─────────────────────────────────────┘
```

**Needs Check-In State (> 90 minutes old):**
```
┌─────────────────────────────────────┐
│ ⚠️ Confirming Transactions          │
│ ■■■□□□ Step 3 of 6                  │
│ ⚠️ Check-in needed                  │
│ Updated 2 hours ago                 │
│ Tap notification to update          │
└─────────────────────────────────────┘
```

**Complete State:**
```
┌─────────────────────────────────────┐
│ ✅ Exit Complete                    │
│ ■■■■■■ Step 6 of 6                  │
│ All transactions confirmed          │
│ Funds available in wallet           │
└─────────────────────────────────────┘
```

### Dynamic Island

**Minimal State:**
- Single icon: Arrow down circle (exit symbol)
- Shows when island is collapsed to smallest size

**Compact State:**
- Leading: Exit icon
- Trailing: "3/6" (step progress)

**Expanded State:**
- **Top Leading**: Large exit icon with animation
- **Top Trailing**: Transaction count (2/5 confirmed)
- **Center**: Current step description ("Confirming transactions")
- **Bottom**: Progress bar + "Next check in 3 minutes"

**Colors:**
- Orange: In progress
- Blue: Waiting for blocks
- Green: Claimable/Complete
- Red: Error

### Error Handling

**If exit encounters error:**
- Show red icon in Live Activity
- Description: "Exit needs attention"
- Tapping opens app to error details
- Don't auto-dismiss - keep visible until user resolves

### Completion

**When exit completes:**
- Show green checkmark
- Description: "Exit complete! Funds claimed."
- Keep visible for 1 hour
- Add haptic feedback when completed

---

## Testing Plan

### Unit Tests
- ContentState serialization/deserialization
- Exit state parsing logic
- Progress calculation methods

### Integration Tests
- Live Activity start/update/end lifecycle
- Background task scheduling
- Notification scheduling

### Manual Testing Scenarios

1. **Happy Path**
   - Start exit
   - Verify Live Activity appears
   - Watch it update through each state
   - Verify completion and dismissal

2. **Background Progression**
   - Start exit
   - Background app
   - Wait 1+ hours
   - Check if Live Activity updated
   - Check if notifications sent

3. **App Termination**
   - Start exit with Live Activity
   - Force quit app
   - Relaunch app
   - Verify Live Activity still active and syncs

4. **Multiple Exits**
   - Start exit with multiple VTXOs
   - Verify aggregate status shown correctly

5. **Error Scenarios**
   - Trigger exit error
   - Verify Live Activity shows error state
   - Resolve error, verify recovery

6. **Network Issues**
   - Start exit
   - Disable network
   - Verify graceful handling
   - Re-enable network, verify recovery

7. **Long-Running Exit**
   - Monitor exit over full 4-8 hour duration
   - Verify Live Activity doesn't get dismissed
   - Check battery impact

---

## Success Metrics

### Technical Metrics
- Live Activity successfully starts: >95% of exits
- Notification delivery: >99% (local notifications are reliable)
- User responds to notification within 2 hours: >80% (target)
- Completion detection: 100% of exits
- Battery impact: <1% per hour (minimal - just notifications)

### User Experience Metrics
- User satisfaction with check-in reminders: Measured via feedback
- Users enable notifications: >85% (critical for functionality)
- Exit completion time: Same as current (no improvement expected, but no regression)
- User complaints about "missed check-ins": <5%

---

## Future Enhancements

### V2 Features (Post-MVP)
1. **Silent Push Notifications**: Add server infrastructure for guaranteed background updates (70-90% reliability)
2. **Interactive Notifications**: Action buttons to view details or claim immediately
3. **Multiple Exit Support**: Show aggregate status for multiple concurrent exits
4. **Block Explorer Links**: Tap Live Activity to view transactions in block explorer
5. **Estimated Completion Time**: Show "~2 hours remaining" based on current state
6. **Smart Notification Timing**: Adjust reminder frequency based on exit phase

### Advanced Features
1. **Watch App Integration**: Show exit status on Apple Watch, notifications appear on wrist
2. **Widget**: Home screen widget showing current exit status (static, updates when app opens)
3. **StandBy Mode**: Full-screen exit progress view optimized for StandBy mode
4. **Settings**: Customizable notification frequency (60/90/120 minutes)
5. **Background App Refresh**: Opportunistic updates when system allows (best effort, don't rely on it)

---

## Open Questions

1. **Multiple Exits**: If user has multiple exits running, show one aggregate Live Activity or multiple?
   - **Recommendation**: Single aggregate showing overall progress
   
2. **Amount Display**: Show exact sat amounts or keep generic?
   - **Recommendation**: Make configurable, default to generic for privacy
   
3. **Background Refresh Frequency**: 1 hour? 1.5 hours? 30 minutes?
   - **Recommendation**: 1 hour (balances battery vs. freshness)
   
4. **Notification Strategy**: Always notify? Only if background refresh fails?
   - **Recommendation**: Always schedule as backup, cancel if background succeeds
   
5. **Exit Restart**: If iOS dismisses activity after 8 hours, restart it?
   - **Recommendation**: Yes, restart with notification to user

---

## Dependencies

### System Requirements
- iOS 16.1+ (Live Activities)
- iPhone 14 Pro+ for Dynamic Island (fallback to lock screen on other devices)
- User permission for notifications (for fallback)

### Framework Dependencies
- ActivityKit (iOS 16.1+)
- WidgetKit (for widget configuration)
- BackgroundTasks (for background execution)
- UserNotifications (for notification fallback)

### Arke Dependencies
- `ExitProgressionService` (existing)
- `BarkWalletFFI` exit methods (existing)
- `ExitStatusParser` (existing)
- `WalletManager` (existing)

### New Files Required
1. `ExitProgressActivityAttributes.swift` - Activity attributes
2. `ExitProgressLiveActivity.swift` - Widget configuration
3. `ExitProgressLockScreenView.swift` - Lock screen UI
4. `ExitProgressDynamicIslandViews.swift` - Dynamic Island UI components
5. `ExitProgressionBackgroundTask.swift` - Background task handler
6. `ExitProgressionNotifications.swift` - Notification manager
7. `ExitProgressionService+LiveActivity.swift` - Extension for Live Activity integration

---

## Conclusion

Live Activities + Local Notifications are an **excellent solution** for exit progression in Arke. This approach:

✅ **Works reliably** - Local notifications have 99%+ delivery rate  
✅ **No server required** - Everything runs on-device  
✅ **Battery friendly** - No background processing  
✅ **Simple architecture** - Easy to implement and maintain  
✅ **Great UX** - Beautiful status display + reliable reminders  
✅ **iOS-friendly** - Works with platform limitations, not against them  

**The Reality:**
- Live Activities **cannot** execute code or wake the app
- Background tasks (BGProcessingTask) are **unreliable** (10-30% success rate)
- Local notifications **are reliable** and work perfectly for this use case
- User opening the app is what progresses exits (this is fine!)
**Why This is Better Than Current State:**
- Current: User must keep app open for hours (bad UX)
- With this: User gets lock screen status + reminders, checks in every 90 min (good UX)

**Implementation Strategy:**
1. **Phase 1-2**: Core Live Activity with basic UI (1-2 weeks)
2. **Phase 3**: Rich Dynamic Island UI (1 week)
3. **Phase 4**: Local notification integration (1 week)
4. **Phase 5**: Polish and edge cases (1 week)
5. **Phase 6**: Testing and refinement (1 week)

**Total Timeline:** ~6 weeks to production-ready

**Recommendation: Proceed with implementation.** This is the right balance of features, reliability, and complexity. Future v2 can add server-based silent push if deeper background integration is needed, but start with this solid foundation.

