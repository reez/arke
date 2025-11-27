//
//  Example: App with CloudKit Setup (Alpha Version)
//  Ark wallet prototype
//

import SwiftUI
import SwiftData

@main
struct ArkWalletApp: App {
    
    // CloudKit-enabled model container for alpha testing
    let modelContainer: ModelContainer = {
        SwiftDataHelper.createModelContainer(
            for: PersistentTransaction.self,
                 PersistentTag.self,
                 TransactionTagAssignment.self,
                 PersistentContact.self,
                 TransactionContactAssignment.self,
                 ArkBalanceModel.self,
                 OnchainBalanceModel.self,
                 // Add any other @Model classes here
            cloudKitEnabled: true  // 🌥️ Enabled for alpha
        )
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Alpha Testing Notes
//
// ✅ CloudKit sync is ENABLED by default
// 
// All data syncs across devices signed into the same iCloud account:
// • Transactions (including amounts, addresses, notes)
// • Tags and tag assignments
// • Contacts and contact assignments  
// • Balance information
//
// To test sync:
// 1. Ensure you're signed into iCloud (System Settings → Apple ID)
// 2. Run app on Device 1, create some test data
// 3. Run app on Device 2 with same iCloud account
// 4. Data should appear within ~10-30 seconds
//
// To disable CloudKit temporarily, change:
//   cloudKitEnabled: true  →  cloudKitEnabled: false
