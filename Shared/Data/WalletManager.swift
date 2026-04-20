//
//  WalletManager.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import Foundation
import SwiftUI
import SwiftData
import Bark
import ArkeUI

// MARK: - Wallet Implementation Toggle
/// Set to `true` to use BarkWalletFFI (new implementation)
/// Set to `false` to use BarkWallet (CLI-based implementation)
private let USE_FFI_WALLET = true

// MARK: - Export Data Structure
struct WalletExportData: Codable {
    let addresses: AddressData
    let balances: BalanceData
    let transactions: [ExportTransactionData]
    let vtxos: [VTXOModel]
    let utxos: [UTXOModel]
    let configuration: ArkConfigModel
    let arkInfo: ArkInfoModel
    let blockHeight: Int
    let exportTimestamp: Date
    
    struct AddressData: Codable {
        let arkAddress: String
        let onchainAddress: String
    }
    
    struct BalanceData: Codable {
        let arkBalance: ArkBalanceResponse?
        let onchainBalance: OnchainBalanceResponse?
        // Note: TotalBalanceModel is computed from the above, not stored
    }
    
    struct ExportTransactionData: Codable {
        let txid: String
        let movementId: Int?
        let recipientIndex: Int?
        let type: String
        let amount: Int
        let date: Date
        let status: String
        let address: String?
        let notes: String?
        
        init(from transactionModel: TransactionModel) {
            self.txid = transactionModel.txid
            self.movementId = transactionModel.movementId
            self.recipientIndex = transactionModel.recipientIndex
            // Convert enum to string
            self.type = transactionModel.type.displayName.lowercased()
            self.amount = transactionModel.amount
            self.date = transactionModel.date
            // Convert enum to string
            self.status = transactionModel.status.displayName.lowercased()
            self.address = transactionModel.address
            self.notes = transactionModel.notes
        }
    }
}

@MainActor
@Observable
class WalletManager {
    // MARK: - Coordinator State
    var isInitialized: Bool = false
    var error: String?
    var isRefreshing: Bool = false
    var hasLoadedOnce: Bool = false
    
    /// Counter for active refresh calls (used to track concurrent refresh attempts)
    private var activeRefreshCount: Int = 0
    
    /// Increments whenever persistent relationships change (contacts, tags, etc.)
    /// Views can observe this to refresh when relationship data changes
    var dataVersion: Int = 0
    
    // MARK: - Services
    private var wallet: BarkWalletProtocol?
    private let taskManager = TaskDeduplicationManager()
    private let cacheManager = WalletCacheManager()
    private var modelContext: ModelContext?
    
    private var transactionService: TransactionService?
    private var balanceService: BalanceService?
    private var addressService: AddressService?
    private var walletOperationsService: WalletOperationsService?
    private var processStateService: ProcessStateService?
    private var exitProgressionService: ExitProgressionService?
    private var roundProgressionService: RoundProgressionService?
    private var vtxoRefreshService: VTXORefreshService?
    private var lightningClaimService: LightningClaimService?
    private var onchainTransactionService: OnchainTransactionService?
    private var unifiedTransactionService: UnifiedTransactionService?  // Unified ark + onchain transactions
    private var relayRegistrationService: RelayRegistrationService?
    private var walletNotificationService: WalletNotificationService?
    // Services from ServiceContainer
    private var securityService: SecurityService { ServiceContainer.shared.securityService }
    private var tagService: TagService { ServiceContainer.shared.tagService }
    private var contactService: ContactService { ServiceContainer.shared.contactService }
    private var contactAddressService: ContactAddressService { ServiceContainer.shared.contactAddressService }
    
    // MARK: - Computed Properties - Network Info
    var currentNetworkName: String {
        wallet?.currentNetworkName ?? "Unknown"
    }
    
    var isMainnet: Bool {
        wallet?.isMainnet ?? false
    }
    
    var networkConfig: NetworkConfig? {
        wallet?.networkConfig
    }
    
    // MARK: - Computed Properties - Data Access
    var transactions: [TransactionModel] {
        unifiedTransactionService?.allTransactions ?? []  // Use unified service for merged transactions
    }
    
    /// Ark-only transactions (for debugging/admin views)
    var arkTransactionsOnly: [TransactionModel] {
        transactionService?.transactions ?? []
    }
    
    /// Onchain-only transactions (for debugging/admin views)
    var onchainTransactionsOnly: [OnchainTransactionModel] {
        onchainTransactionService?.onchainTransactions ?? []
    }
    
    var arkAddress: String {
        addressService?.arkAddress ?? ""
    }
    
    var onchainAddress: String {
        addressService?.onchainAddress ?? ""
    }
    
    var arkBalance: ArkBalanceModel? {
        balanceService?.arkBalance
    }
    
    var onchainBalance: OnchainBalanceModel? {
        balanceService?.onchainBalance
    }
    
    var totalBalance: TotalBalanceModel? {
        balanceService?.totalBalance
    }
    
    var onchainTransactions: [OnchainTransactionModel] {
        onchainTransactionService?.onchainTransactions ?? []
    }
    
    var hasOnchainTransactions: Bool {
        onchainTransactionService?.hasTransactions ?? false
    }
    
    var onchainTransactionCount: Int {
        onchainTransactionService?.transactionCount ?? 0
    }
    
    // MARK: - Tag Properties
    var tags: [TagModel] {
        tagService.tags
    }
    
    var hasTags: Bool {
        tagService.hasTags
    }
    
    var tagServiceError: String? {
        tagService.error
    }
    
    /// Access to TagService for SwiftUI environment injection
    var tagServiceForEnvironment: TagService {
        tagService
    }
    
    // MARK: - Contact Properties
    var contacts: [ContactModel] {
        contactService.contacts
    }
    
    var alphabeticalContacts: [ContactModel] {
        contactService.alphabeticalContacts
    }
    
    var recentContacts: [ContactModel] {
        contactService.recentContacts
    }
    
    var contactCount: Int {
        contactService.contactCount
    }
    
    var hasContacts: Bool {
        contactService.hasContacts
    }
    
    var contactServiceError: String? {
        contactService.error
    }
    
    /// Access to ContactService for SwiftUI environment injection
    var contactServiceForEnvironment: ContactService {
        contactService
    }
    
    // MARK: - Computed Properties - Formatted Values
    var formattedSpendableBalance: String {
        let spendableAmount = totalBalance?.totalSpendableSat ?? 0
        return BitcoinFormatter.shared.formatAmount(spendableAmount)
    }
    
    var formattedTotalBalance: String {
        let totalAmount = totalBalance?.grandTotalSat ?? 0
        return BitcoinFormatter.shared.formatAmount(totalAmount)
    }
    
    var formattedArkSpendableBalance: String {
        let arkSpendable = arkBalance?.spendableSat ?? 0
        return BitcoinFormatter.shared.formatAmount(arkSpendable)
    }
    
    var formattedOnchainSpendableBalance: String {
        let onchainSpendable = onchainBalance?.spendableSat ?? 0
        return BitcoinFormatter.shared.formatAmount(onchainSpendable)
    }
    
    // MARK: - Computed Properties - State Checks
    var hasPendingBalance: Bool {
        balanceService?.hasPendingBalance ?? false
    }
    
    var hasSpendableBalance: Bool {
        balanceService?.hasSpendableBalance ?? false
    }
    
    var isInitialLoading: Bool {
        isRefreshing && !hasLoadedOnce && !(transactionService?.hasLoadedTransactions ?? false)
    }
    
    var isRefreshingWithData: Bool {
        isRefreshing && hasLoadedOnce
    }
    
    var arkInfo: ArkInfoModel? {
        balanceService?.arkInfo
    }
    
    var estimatedBlockHeight: Int? {
        balanceService?.estimatedBlockHeight
    }
    
    var transactionServiceInstance: TransactionService? {
        transactionService
    }
    
    var unifiedTransactionServiceInstance: UnifiedTransactionService? {
        unifiedTransactionService
    }
    
    // MARK: - Computed Properties - Process State
    
    /// Access to ProcessStateService for direct service access if needed
    var processStateServiceInstance: ProcessStateService? {
        processStateService
    }
    
    // MARK: - Exit State (from Bark SDK)
    
    /// Cached exit VTXOs
    private var cachedExitVtxos: [ExitVtxo] = []
    private var exitVtxosCacheTime: Date?
    private let exitCacheTimeout: TimeInterval = 30 // 30 seconds
    
    /// Active unilateral exits (from Bark SDK)
    /// Note: Filters out claimed exits, as they are no longer active
    var activeUnilateralExits: [ExitVtxo] {
        // Get all exit VTXOs (claimed and unclaimed)
        let allExits: [ExitVtxo]
        
        // Return cached value if fresh
        if let cacheTime = exitVtxosCacheTime,
           Date().timeIntervalSince(cacheTime) < exitCacheTimeout {
            let age = Date().timeIntervalSince(cacheTime)
            print("📦 [Exit Cache] Returning cached exit VTXOs (age: \(String(format: "%.1f", age))s, count: \(cachedExitVtxos.count))")
            if !cachedExitVtxos.isEmpty {
                print("   └─ Cached VTXOs:")
                for (index, vtxo) in cachedExitVtxos.enumerated() {
                    print("      [\(index)] ID: \(vtxo.vtxoId), Amount: \(vtxo.amountSats) sats, Claimable: \(vtxo.isClaimable), State: \(vtxo.stateDisplayName)")
                }
            }
            allExits = cachedExitVtxos
        } else {
            // Otherwise return cached value but trigger background refresh
            print("🔄 [Exit Cache] Cache stale or missing, triggering background refresh (cached count: \(cachedExitVtxos.count))")
            if !cachedExitVtxos.isEmpty {
                print("   └─ Returning stale cached VTXOs:")
                for (index, vtxo) in cachedExitVtxos.enumerated() {
                    print("      [\(index)] ID: \(vtxo.vtxoId), Amount: \(vtxo.amountSats) sats, Claimable: \(vtxo.isClaimable), State: \(vtxo.stateDisplayName)")
                }
            }
            Task {
                await refreshExitCache()
            }
            allExits = cachedExitVtxos
        }
        
        // Filter out claimed exits - they're complete and no longer active
        let activeExits = allExits.filter { !$0.isClaimed }
        
        if activeExits.count < allExits.count {
            print("   └─ Filtered out \(allExits.count - activeExits.count) claimed exit(s)")
        }
        
        return activeExits
    }
    
    /// All unilateral exits (including claimed/completed ones)
    /// Use this when you need to show complete exit history
    var allUnilateralExits: [ExitVtxo] {
        // Get all exit VTXOs (claimed and unclaimed)
        let allExits: [ExitVtxo]
        
        // Return cached value if fresh
        if let cacheTime = exitVtxosCacheTime,
           Date().timeIntervalSince(cacheTime) < exitCacheTimeout {
            allExits = cachedExitVtxos
        } else {
            // Otherwise return cached value but trigger background refresh
            Task {
                await refreshExitCache()
            }
            allExits = cachedExitVtxos
        }
        
        return allExits
    }
    
    /// Exits requiring user action (claimable)
    var exitsRequiringAction: [ExitVtxo] {
        activeUnilateralExits.filter { $0.isClaimable }
    }
    
    /// Whether there are active unilateral exits
    var hasActiveUnilateralExits: Bool {
        !activeUnilateralExits.isEmpty
    }
    
    /// Whether any exits require user action
    var hasExitsRequiringAction: Bool {
        !exitsRequiringAction.isEmpty
    }
    
    /// Refresh exit cache from Bark SDK
    private func refreshExitCache() async {
        do {
            cachedExitVtxos = try await getExitVtxos()
            exitVtxosCacheTime = Date()
        } catch {
            print("⚠️ Failed to refresh exit cache: \(error)")
            // Keep stale cache on error
        }
    }
    
    /// Force immediate exit cache refresh
    func invalidateExitCache() {
        exitVtxosCacheTime = nil
        Task {
            await refreshExitCache()
        }
    }
    
    /// Refresh data after round completion (balances and transactions)
    func refreshAfterRoundCompletion() async {
        await balanceService?.refreshAfterTransaction()
        await transactionService?.refreshTransactions()
    }
    
    /// Refresh balances (called by notification service on channel lagging)
    func refreshBalances() async {
        await balanceService?.refreshBalances()
    }
    
    // MARK: - Exit Progression Service
    
    /// Manually trigger exit progression (in addition to automatic checks)
    func triggerExitProgression() {
        exitProgressionService?.triggerImmediateCheck()
    }
    
    /// Check if exit progression service is running
    var isExitProgressionRunning: Bool {
        exitProgressionService?.isRunning ?? false
    }
    
    // MARK: - VTXO Refresh Service
    
    /// Manually trigger VTXO auto-refresh check (in addition to automatic checks)
    func triggerVTXORefreshCheck() {
        vtxoRefreshService?.triggerImmediateCheck()
    }
    
    /// Check if VTXO auto-refresh service is running
    var isVTXORefreshServiceRunning: Bool {
        vtxoRefreshService?.isRunning ?? false
    }
    
    /// Number of VTXOs auto-refreshed in current session
    var vtxoAutoRefreshCount: Int {
        vtxoRefreshService?.autoRefreshCount ?? 0
    }
    
    /// Manually refresh VTXOs (for UI triggers)
    func refreshVTXOsManually() async throws {
        try await vtxoRefreshService?.refreshManually()
    }
    
    // MARK: - Other Process State
    
    /// VTXO health status
    var vtxoHealth: VTXOHealth {
        processStateService?.vtxoHealth ?? VTXOHealth()
    }
    
    /// Connection status
    var connectionStatus: ConnectionStatus {
        processStateService?.connectionStatus ?? ConnectionStatus()
    }
    
    /// Backup status
    var backupStatus: BackupStatus? {
        processStateService?.backupStatus
    }
    
    /// Whether backup reminder should be shown
    var shouldShowBackupReminder: Bool {
        processStateService?.shouldShowBackupReminder ?? false
    }
    
    /// Total count of items requiring user attention
    var attentionItemCount: Int {
        var count = 0
        
        if vtxoHealth.hasExpiredVTXOs {
            count += vtxoHealth.expiredCount
        }
        
        if hasExitsRequiringAction {
            count += exitsRequiringAction.count
        }
        
        if shouldShowBackupReminder {
            count += 1
        }
        
        return count
    }
    
    /// Whether any state needs user attention
    var needsAttention: Bool {
        return vtxoHealth.needsAttention || 
               hasExitsRequiringAction || 
               shouldShowBackupReminder ||
               connectionStatus.showWarning
    }
    
    /// Summary message of all attention items
    var attentionSummary: String? {
        var messages: [String] = []
        
        if let vtxoMessage = vtxoHealth.statusMessage {
            messages.append(vtxoMessage)
        }
        
        if hasExitsRequiringAction {
            let count = exitsRequiringAction.count
            messages.append("\(count) exit\(count == 1 ? "" : "s") ready to claim")
        }
        
        if hasActiveUnilateralExits && !hasExitsRequiringAction {
            let count = activeUnilateralExits.count
            messages.append("\(count) active exit\(count == 1 ? "" : "s") in progress")
        }
        
        if shouldShowBackupReminder {
            messages.append("Backup your wallet")
        }
        
        if connectionStatus.showWarning {
            messages.append(connectionStatus.statusMessage)
        }
        
        return messages.isEmpty ? nil : messages.joined(separator: " • ")
    }
    
    // MARK: - Initialization
    init(useMock: Bool = false, networkConfig: NetworkConfig? = nil) {
        #if DEBUG
        // Auto-enable mock mode if wallet opening is skipped for debugging
        let skipWalletOpen = ProcessInfo.processInfo.environment["SKIP_WALLET_OPEN"] == "1" ||
                             CommandLine.arguments.contains("-skipWalletOpen")
        let shouldUseMock = useMock || skipWalletOpen
        #else
        let shouldUseMock = useMock
        #endif
        
        let config = networkConfig ?? NetworkConfig.signet
        setupWallet(useMock: shouldUseMock, networkConfig: config)
        initializeServices()
        
        // Set up notification observer for mailbox updates (iOS only)
        #if os(iOS)
        setupMailboxNotificationObserver()
        #endif
        
        #if DEBUG
        if skipWalletOpen && !useMock {
            print("🎭 [DEBUG] Auto-enabled mock wallet for fast debugging")
        }
        #endif
    }
    
    #if os(iOS)
    /// Sets up observer for mailbox update notifications from APNs
    private func setupMailboxNotificationObserver() {
        print("📮 [WalletManager] Setting up mailbox update observer...")
        NotificationCenter.default.addObserver(
            forName: .mailboxUpdateReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                print("📮 [WalletManager] Mailbox update notification received, refreshing...")
                print("📮 [WalletManager] Current dataVersion: \(self.dataVersion)")
                await self.refresh()
                print("📮 [WalletManager] Refresh complete. New dataVersion: \(self.dataVersion)")
            }
        }
    }
    #endif
    
    /// Convenience initializer for different networks
    static func forNetwork(_ networkConfig: NetworkConfig, useMock: Bool = false) -> WalletManager {
        return WalletManager(useMock: useMock, networkConfig: networkConfig)
    }
    
    private func setupWallet(useMock: Bool, networkConfig: NetworkConfig) {
        if useMock {
            wallet = MockBarkWallet()
        } else {
            /*
            #if os(macOS)
            // macOS: Allow toggle between FFI and CLI implementations
            if USE_FFI_WALLET {
                wallet = BarkWalletFFI(networkConfig: networkConfig, securityService: securityService)
                if wallet == nil {
                    print("❌ Failed to initialize BarkWalletFFI with network config: \(networkConfig.name)")
                } else {
                    print("✅ Using BarkWalletFFI implementation")
                }
            } else {
                wallet = BarkWallet(networkConfig: networkConfig)
                if wallet == nil {
                    print("❌ Failed to initialize BarkWallet with network config: \(networkConfig.name)")
                } else {
                    print("✅ Using BarkWallet (CLI) implementation")
                }
            }
            #else
            */
            // iOS and other platforms: Always use FFI implementation
            wallet = BarkWalletFFI(networkConfig: networkConfig, securityService: securityService)
            if wallet == nil {
                print("❌ Failed to initialize BarkWalletFFI with network config: \(networkConfig.name)")
            } else {
                print("✅ Using BarkWalletFFI implementation")
            }
            //#endif
        }
    }
    
    private func initializeServices() {
        guard let wallet = wallet else { return }
        
        // Initialize all services with shared task manager and cache manager
        transactionService = TransactionService(wallet: wallet, taskManager: taskManager)
        balanceService = BalanceService(wallet: wallet, taskManager: taskManager, cacheManager: cacheManager)
        // AddressService requires ModelContext, so it will be initialized later in setModelContext()
        addressService = nil
        walletOperationsService = WalletOperationsService(wallet: wallet, taskManager: taskManager)
        processStateService = ProcessStateService()
        
        // Initialize exit progression service
        exitProgressionService = ExitProgressionService(wallet: wallet)
        exitProgressionService?.setWalletManager(self)
        
        // Initialize round progression service
        roundProgressionService = RoundProgressionService(wallet: wallet)
        roundProgressionService?.setWalletManager(self)
        
        // Initialize VTXO auto-refresh service
        vtxoRefreshService = VTXORefreshService(wallet: wallet)
        vtxoRefreshService?.setWalletManager(self)
        
        // Initialize Lightning claim service
        // lightningClaimService = LightningClaimService(wallet: wallet)
        // lightningClaimService?.setWalletManager(self)
        
        // Initialize onchain transaction service
        onchainTransactionService = OnchainTransactionService(wallet: wallet, taskManager: taskManager)
        
        // Initialize unified transaction service (merges ark + onchain)
        if let transactionService = transactionService,
           let onchainService = onchainTransactionService {
            unifiedTransactionService = UnifiedTransactionService(
                arkService: transactionService,
                onchainService: onchainService,
                walletManager: self
            )
            print("🔗 [WalletManager] UnifiedTransactionService initialized")
        }
        
        // Initialize relay registration service for APNs notifications
        #if os(iOS)
        let relayAPIToken = Bundle.main.object(forInfoDictionaryKey: "RelayAPIToken") as? String
        relayRegistrationService = RelayRegistrationService(relayAPIToken: relayAPIToken)
        print("📮 [WalletManager] RelayRegistrationService initialized\(relayAPIToken != nil ? " with API token" : " without API token")")
        #endif
        
        // Initialize wallet notification service for real-time movement updates
        walletNotificationService = WalletNotificationService(wallet: wallet)
        walletNotificationService?.setWalletManager(self)
        print("🔔 [WalletManager] WalletNotificationService initialized")
        
        // TagService and ContactService are initialized in init(), not here
        
        // Configure post-transaction callback
        walletOperationsService?.setTransactionCompletedCallback { [weak self] in
            await self?.balanceService?.refreshAfterTransaction()
            await self?.transactionService?.refreshTransactions()
            // Increment backup transaction count after each transaction
            self?.processStateService?.incrementBackupTransactionCount()
            // Increment dataVersion to notify UI that transaction data has changed
            self?.dataVersion += 1
            print("📊 DataVersion incremented to \(self?.dataVersion ?? 0) after transaction")
        }
    }
    
    func setModelContext(_ context: ModelContext, caller: String = #function, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print("🔧 [WalletManager] 📞 setModelContext() CALLED")
        print("   ├─ From: \(fileName):\(line)")
        print("   └─ Function: \(caller)")
        
        self.modelContext = context
        
        // Initialize AddressService now that we have a ModelContext
        if let wallet = wallet, addressService == nil {
            addressService = AddressService(wallet: wallet, taskManager: taskManager, modelContext: context)
        }
        
        transactionService?.setModelContext(context)
        transactionService?.setAddressService(addressService)  // ✅ Phase 3: Wire address service
        balanceService?.setModelContext(context)
        processStateService?.setModelContext(context)
        onchainTransactionService?.setModelContext(context)
        unifiedTransactionService?.setModelContext(context)  // Set context on unified service
        // Services are configured through ServiceContainer
        ServiceContainer.shared.configureServices(with: context)
    }
    
    // MARK: - Coordination Methods
    func initialize(caller: String = #function, file: String = #file, line: Int = #line) async {
        let fileName = (file as NSString).lastPathComponent
        print("🔧 [WalletManager] 📞 initialize() CALLED")
        print("   ├─ Time: \(Date())")
        print("   ├─ From: \(fileName):\(line)")
        print("   └─ Function: \(caller)")
        
        await taskManager.execute(key: "initialize") {
            print("🔧 [WalletManager] initialize execute at \(Date())")
            await self.performInitialization()
            print("🔧 [WalletManager] initialize execute done at \(Date())")
        }
    }
    
    private func performInitialization() async {
        guard let wallet = wallet else {
            error = "Wallet not available"
            return
        }
        
        print("🔧 [WalletManager] Starting initialization...")
        
        // Step 1: Explicitly open the wallet if it exists (FFI only)
        if let ffiWallet = wallet as? BarkWalletFFI {
            let opened = await ffiWallet.openWalletIfNeeded()
            if !opened {
                print("ℹ️ No existing wallet to open - user needs to create or import")
                isInitialized = false
                return
            }
            print("✅ Wallet opened successfully")
            
            
        }
        
        // Step 2: Check wallet existence using SecurityService (Keychain)
        let walletExists = securityService.hasMnemonic()
        
        if walletExists {
            print("✅ Wallet mnemonic found in Keychain - wallet exists on \(currentNetworkName)")
            isInitialized = true
            
            #if DEBUG
            print("📍 [ADDRESS TRACE] performInitialization() about to call refresh()")
            print("   This will trigger address generation")
            #endif
            
            // Load all wallet data for existing wallet
            await refresh()
            // Create default tags if needed (after data is loaded)
            await createDefaultTagsIfNeeded()
            // Create default contacts if needed (after data is loaded)
            await createDefaultContactsIfNeeded()
            
            // Ensure arkInfo is loaded before starting services that depend on it
            if arkInfo == nil {
                print("ℹ️ [WalletManager] arkInfo not yet loaded, caching now...")
                await balanceService?.cacheArkInfoIfNeeded()
                if arkInfo != nil {
                    print("✅ [WalletManager] arkInfo cached successfully")
                } else {
                    print("⚠️ [WalletManager] Failed to cache arkInfo")
                }
            }
            
            // Start background progression services
            exitProgressionService?.start()
            roundProgressionService?.start()
            vtxoRefreshService?.start()
            lightningClaimService?.start()
            
            // Start wallet notification service for real-time updates
            if let transactionService = transactionService {
                walletNotificationService?.setTransactionService(transactionService)
                walletNotificationService?.start()
            }
            
            // Register for push notifications now that wallet is initialized
            #if os(iOS)
            Task {
                await registerForPushNotifications()
            }
            #endif
        } else {
            print("⚠️ No mnemonic found in Keychain - wallet needs to be created or imported on \(currentNetworkName)")
            isInitialized = false
        }
    }
    
    /// Centralized refresh - orchestrates all services
    func refresh(caller: String = #function, file: String = #file, line: Int = #line) async {
        let fileName = (file as NSString).lastPathComponent
        print("🔄 [WalletManager] 📞 refresh() CALLED")
        print("   ├─ From: \(fileName):\(line)")
        print("   └─ Function: \(caller)")
        
        // Increment counter and set isRefreshing if this is the first active call
        activeRefreshCount += 1
        let refreshNumber = activeRefreshCount
        print("🔄 [REFRESH STATE] Active refresh count: \(activeRefreshCount), refresh #\(refreshNumber)")
        
        if activeRefreshCount == 1 {
            print("🔄 [REFRESH STATE] Setting isRefreshing = true (first active refresh)")
            isRefreshing = true
        } else {
            print("🔄 [REFRESH STATE] Additional concurrent refresh call (not changing isRefreshing)")
        }
        
        defer {
            // Decrement counter and clear isRefreshing only when all calls complete
            activeRefreshCount -= 1
            print("🔄 [REFRESH STATE] Refresh #\(refreshNumber) completed. Active count now: \(activeRefreshCount)")
            
            if activeRefreshCount == 0 {
                print("🔄 [REFRESH STATE] Setting isRefreshing = false (all refreshes complete)")
                isRefreshing = false
            }
        }
        
        await taskManager.execute(key: "refresh") {
            await self.performRefresh()
        }
        
        print("🔄 [REFRESH STATE] refresh() #\(refreshNumber) returning")
    }
    
    private func performRefresh() async {
        print("WalletManager.performRefresh")
        
        #if DEBUG
        print("📍 [ADDRESS TRACE] WalletManager.performRefresh() starting address load")
        print("   📞 Called from:")
        Thread.callStackSymbols.prefix(6).enumerated().forEach { index, symbol in
            print("      \(index): \(symbol)")
        }
        #endif
        
        defer { 
            hasLoadedOnce = true
        }
        
        guard wallet != nil else { 
            error = "Wallet not initialized"
            return 
        }
        
        // Track if any server communication succeeded
        var anyServerCallSucceeded = false
        
        // Step 1: Ensure server connection is fresh
        print("🔄 [Refresh] Step 1: Refreshing server connection...")
        await refreshServer()
        // Note: refreshServer() doesn't throw, it sets self.error on failure
        if error != nil {
            print("⚠️ [Refresh] Server refresh failed, but continuing with data refresh")
            // We don't return here - we'll try to continue with the refresh
        } else {
            anyServerCallSucceeded = true
            print("✅ [Refresh] Server connection successful")
        }
        
        // Step 2: Sync wallet state with ASP server
        print("🔄 [Refresh] Step 2: Syncing wallet state with server...")
        do {
            try await sync()
            anyServerCallSucceeded = true
            print("✅ [Refresh] Wallet state synced successfully")
        } catch {
            print("⚠️ [Refresh] Wallet sync failed: \(error)")
            // We'll continue with the refresh even if sync fails
            // The user's local cache might still be usable
        }
        
        // Step 3: Coordinate service refreshes in parallel where possible
        print("🔄 [Refresh] Step 3: Refreshing wallet data (balances, addresses, transactions)...")
        await withTaskGroup(of: Void.self) { group in
            // Balance service handles its own coordination
            group.addTask { 
                await self.balanceService?.refreshAllBalances() 
            }
            
            // Address loading
            group.addTask {
                #if DEBUG
                print("📍 [ADDRESS TRACE] Task group calling addressService.loadAddresses()")
                #endif
                await self.addressService?.loadAddresses() 
            }
            
            // Transaction refresh (Ark transactions)
            group.addTask { 
                await self.transactionService?.refreshTransactions() 
            }
            
            // Onchain transaction refresh (BDK transactions)
            group.addTask {
                await self.onchainTransactionService?.refreshTransactions()
            }
        }
        
        // Merge transactions from both sources after refresh
        print("🔄 [Refresh] Step 3.1: Merging ark + onchain transactions...")
        await unifiedTransactionService?.mergeTransactions()
        
        // Check for errors from services and log them for debugging
        if let addressError = addressService?.error {
            print("⚠️ [Refresh] AddressService error: \(addressError)")
            self.error = addressError
        }
        else if let transactionError = transactionService?.error {
            print("⚠️ [Refresh] TransactionService error: \(transactionError)")
            self.error = transactionError
        }
        else if let balanceError = balanceService?.error {
            print("⚠️ [Refresh] BalanceService error: \(balanceError)")
            self.error = balanceError
        }
        else if let onchainTxError = onchainTransactionService?.error {
            print("⚠️ [Refresh] OnchainTransactionService error: \(onchainTxError)")
            self.error = onchainTxError
        } else {
            error = nil
        }
        
        // Step 4: After successful refresh, update process state service and exit cache
        print("🔄 [Refresh] Step 4: Updating process states and exit cache...")
        await refreshProcessStates(isConnected: anyServerCallSucceeded)
        await refreshExitCache()
        
        if error == nil {
            print("✅ All wallet data refreshed successfully on \(currentNetworkName)")
        } else {
            print("⚠️ Wallet refresh completed with errors on \(currentNetworkName)")
        }
        
        // CRITICAL: Always increment dataVersion to trigger UI updates, even if there were errors
        // This ensures the UI shows whatever data we did manage to fetch
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after refresh (triggers UI update)")
    }
    
    /// Refresh process states after wallet data is loaded
    private func refreshProcessStates(isConnected: Bool) async {
        guard let processStateService = processStateService else { return }
        
        // Get VTXOs from wallet operations
        let vtxos: [VTXOModel]
        do {
            vtxos = try await getVTXOs()
        } catch {
            print("⚠️ Could not fetch VTXOs for process state update: \(error)")
            vtxos = []
        }
        
        let blockHeight = balanceService?.estimatedBlockHeight ?? 0
        
        // Connection status is passed in based on actual server communication success
        let connectionError = error
        
        // Update all process states
        processStateService.refreshAll(
            vtxos: vtxos,
            blockHeight: blockHeight,
            isConnected: isConnected,
            connectionError: connectionError
        )
    }
    
    // MARK: - Tag Operations (delegates to TagService)
    
    /// Create a new tag
    func createTag(_ tagModel: TagModel) async throws -> TagModel {
        return try await tagService.createTag(tagModel)
    }
    
    /// Update an existing tag
    func updateTag(_ tagModel: TagModel) async throws {
        try await tagService.updateTag(tagModel)
    }
    
    /// Delete a tag (soft delete)
    func deleteTag(_ tagId: UUID) async throws {
        try await tagService.deleteTag(tagId)
    }
    
    /// Assign a tag to a transaction
    func assignTag(_ tagId: UUID, to transactionTxid: String) async throws {
        try await tagService.assignTag(tagId, to: transactionTxid)
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after tag assignment")
    }
    
    /// Remove a tag assignment from a transaction
    func unassignTag(_ tagId: UUID, from transactionTxid: String) async throws {
        try await tagService.unassignTag(tagId, from: transactionTxid)
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after tag unassignment")
    }
    
    /// Get all transactions with a specific tag
    func getTransactionsWithTag(_ tagId: UUID) async throws -> [TransactionModel] {
        return try await tagService.getTransactionsWithTag(tagId)
    }
    
    /// Create default tags if needed
    func createDefaultTagsIfNeeded() async {
        await tagService.createDefaultTagsIfNeeded()
    }
    
    /// Create default contacts if needed
    func createDefaultContactsIfNeeded() async {
        await contactService.createDefaultContactsIfNeeded()
    }
    
    /// Get tag usage statistics
    func getTagStatistics() async throws -> [TagStatistic] {
        return try await tagService.getTagStatistics()
    }
    
    /// Get all tags assigned to a specific transaction
    func getTransactionTags(_ transactionId: String) async throws -> [TagModel] {
        return try await tagService.getTagsForTransaction(transactionId)
    }
    
    /// Check if a transaction has any tags
    func transactionHasTags(_ transactionId: String) async throws -> Bool {
        let tags = try await getTransactionTags(transactionId)
        return !tags.isEmpty
    }
    
    /// Clear tag service errors
    func clearTagError() {
        tagService.clearError()
    }
    
    // MARK: - Contact Operations (delegates to ContactService)
    
    /// Create a new contact
    func createContact(_ contactModel: ContactModel) async throws -> ContactModel {
        return try await contactService.createContact(contactModel)
    }
    
    /// Update an existing contact
    func updateContact(_ contactModel: ContactModel) async throws {
        try await contactService.updateContact(contactModel)
    }
    
    /// Delete a contact
    func deleteContact(_ contactId: UUID) async throws {
        try await contactService.deleteContact(contactId)
    }
    
    /// Assign a contact to a transaction
    func assignContact(_ contactId: UUID, to transactionTxid: String) async throws {
        try await contactService.assignContact(contactId, to: transactionTxid)
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after contact assignment")
    }
    
    /// Assign a contact to a transaction with address learning and bulk assignment
    /// - If the transaction has an address, it will be added to the contact's addresses
    /// - All other transactions with the same address (without contacts) will be auto-assigned
    /// - Returns the number of additional transactions that were auto-assigned
    @discardableResult
    func assignContactWithAddressLearning(_ contactId: UUID, to transactionTxid: String) async throws -> Int {
        guard let modelContext = modelContext else {
            throw BarkErrorArke.commandFailed("Model context not available")
        }
        
        print("🔗 Starting contact assignment with address learning for transaction: \(transactionTxid)")
        
        // First, assign the contact to the transaction
        try await contactService.assignContact(contactId, to: transactionTxid)
        print("✅ Created basic contact assignment")
        
        // Try to get the transaction and its address
        let transactionDescriptor = FetchDescriptor<PersistentTransaction>(
            predicate: #Predicate<PersistentTransaction> { $0.txid == transactionTxid }
        )
        let transactions = try modelContext.fetch(transactionDescriptor)
        
        guard let transaction = transactions.first,
              let address = transaction.address,
              !address.isEmpty else {
            // Transaction has no address, just return after basic assignment
            print("ℹ️ Transaction \(transactionTxid) has no address, skipping address learning")
            return 0
        }
        
        // Get the contact to check if it already has this address
        let contactDescriptor = FetchDescriptor<PersistentContact>(
            predicate: #Predicate<PersistentContact> { $0.id == contactId }
        )
        let contacts = try modelContext.fetch(contactDescriptor)
        
        guard let contact = contacts.first else {
            print("⚠️ Contact \(contactId) not found for address learning")
            return 0
        }
        
        // Normalize the address for comparison
        let normalizedAddress = address.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
        
        // Check if the contact already has this address
        let hasAddress = contact.addresses?.contains { 
            $0.normalizedAddress == normalizedAddress 
        } ?? false
        
        // Add the address to the contact if it's new
        if !hasAddress {
            do {
                // Determine if this should be the primary address
                let isPrimary = contact.addresses?.isEmpty ?? true
                
                let newAddress = try await contactAddressService.validateAndCreateAddress(
                    address,
                    for: contactId,
                    label: "From transaction",
                    isPrimary: isPrimary
                )
                
                print("✅ Added address to contact '\(contact.cachedName)': \(newAddress.shortAddress)")
            } catch {
                // Don't fail the whole operation if address creation fails
                print("⚠️ Failed to add address to contact: \(error)")
            }
        } else {
            print("ℹ️ Contact '\(contact.cachedName)' already has address \(address)")
        }
        
        // Step 2: Find all other transactions with the same address
        // Note: We can't use lowercased() in predicates, so we fetch all transactions with addresses
        // and filter in memory for case-insensitive comparison
        let allTransactionsWithAddressDescriptor = FetchDescriptor<PersistentTransaction>(
            predicate: #Predicate<PersistentTransaction> { transaction in
                transaction.address != nil
            }
        )
        let allTransactionsWithAddresses = try modelContext.fetch(allTransactionsWithAddressDescriptor)
        
        // Filter in memory for case-insensitive address matching
        let allTransactionsWithAddress = allTransactionsWithAddresses.filter { transaction in
            guard let txAddress = transaction.address else { return false }
            return txAddress.lowercased() == normalizedAddress
        }
        
        // Filter to only transactions without any contact assignments
        let unassignedTransactions = allTransactionsWithAddress.filter { tx in
            (tx.contactAssignments?.isEmpty ?? true) && tx.txid != transactionTxid
        }
        
        // Bulk assign the contact to all unassigned transactions
        var autoAssignedCount = 0
        for unassignedTransaction in unassignedTransactions {
            // Create the assignment
            let assignment = TransactionContactAssignment(contact: contact, transaction: unassignedTransaction)
            modelContext.insert(assignment)
            autoAssignedCount += 1
        }
        
        // Save all the new assignments at once
        if autoAssignedCount > 0 {
            do {
                contact.touch() // Update contact's timestamp
                try modelContext.save()
                print("✅ Auto-assigned contact '\(contact.cachedName)' to \(autoAssignedCount) additional transaction(s) with address \(address)")
            } catch {
                print("⚠️ Failed to save auto-assignments: \(error)")
                // Don't throw - the main assignment already succeeded
            }
        } else {
            print("ℹ️ No additional transactions to auto-assign (all transactions with this address already have contacts)")
        }
        
        // Final summary
        print("📊 Contact assignment complete - Total auto-assigned: \(autoAssignedCount)")
        
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after contact assignment with address learning")
        
        return autoAssignedCount
    }
    
    /// Remove a contact assignment from a transaction
    func unassignContact(_ contactId: UUID, from transactionTxid: String) async throws {
        try await contactService.unassignContact(contactId, from: transactionTxid)
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after contact unassignment")
    }
    
    /// Remove all contact assignments from a transaction
    func removeContactAssignment(from transactionId: String) async throws {
        try await contactService.removeAllContactsFromTransaction(transactionId)
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after removing all contact assignments")
    }
    
    /// Get all transactions with a specific contact
    func getTransactionsWithContact(_ contactId: UUID) async throws -> [TransactionModel] {
        return try await contactService.getTransactionsWithContact(contactId)
    }
    
    /// Get all contacts assigned to a specific transaction
    func getTransactionContacts(_ transactionId: String) async throws -> [ContactModel] {
        return try await contactService.getContactsForTransaction(transactionId)
    }
    
    /// Check if a transaction has any contacts
    func transactionHasContacts(_ transactionId: String) async throws -> Bool {
        let contacts = try await getTransactionContacts(transactionId)
        return !contacts.isEmpty
    }
    
    /// Search contacts by name
    func searchContacts(_ searchText: String) -> [ContactModel] {
        return contactService.searchContacts(searchText)
    }
    
    /// Get contact usage statistics
    func getContactStatistics() async throws -> [ContactStatistic] {
        return try await contactService.getContactStatistics()
    }
    
    /// Find or create contact by name
    func findOrCreateContact(name: String) async throws -> ContactModel {
        return try await contactService.findOrCreateContact(name: name)
    }
    
    /// Clear contact service errors
    func clearContactError() {
        contactService.clearError()
    }
    
    /// Refresh contacts from storage
    func refreshContacts() async {
        await contactService.refreshContacts()
    }
    
    // MARK: - Contact Address Operations (delegates to ContactAddressService)
    
    /// Validate and create a new address for a contact
    func validateAndCreateAddress(_ addressString: String, for contactId: UUID, label: String? = nil, isPrimary: Bool = false) async throws -> ContactAddressModel {
        return try await contactAddressService.validateAndCreateAddress(addressString, for: contactId, label: label, isPrimary: isPrimary)
    }
    
    /// Update an existing address with full model
    func updateAddress(_ addressModel: ContactAddressModel) async throws {
        try await contactAddressService.updateAddress(addressModel)
    }
    
    /// Delete an address
    func deleteAddress(_ addressId: UUID) async throws {
        try await contactAddressService.deleteAddress(addressId)
    }
    
    /// Get all addresses for a contact
    func getAddressesForContact(_ contactId: UUID) async -> [ContactAddressModel] {
        return await contactAddressService.loadAddressesForContact(contactId)
    }
    
    /// Validate an address format
    func validateAddress(_ addressString: String) -> Bool {
        return contactAddressService.validateAddress(addressString)
    }
    
    /// Parse a payment request and return detailed information
    func parsePaymentRequest(_ addressString: String) -> PaymentRequest? {
        return contactAddressService.parsePaymentRequest(addressString)
    }
    
    /// Set an address as primary for a contact
    func setPrimaryAddress(_ addressId: UUID, for contactId: UUID) async throws {
        try await contactAddressService.setPrimaryAddress(addressId, for: contactId)
    }
    
    /// Clear contact address service errors
    func clearContactAddressError() {
        contactAddressService.error = nil
    }
    
    /// Check if contact address service is loading
    var isContactAddressLoading: Bool {
        contactAddressService.isLoading
    }
    
    /// Get contact address service error
    var contactAddressError: String? {
        contactAddressService.error
    }
    
    // MARK: - Transaction Notes Operations (delegates to TransactionService)
    
    /// Update notes for a transaction
    /// - Parameters:
    ///   - txid: The transaction ID to update
    ///   - notes: The notes text to set (nil to clear notes, empty strings are converted to nil)
    /// - Throws: TransactionServiceError if validation fails or transaction not found
    func updateTransactionNotes(for txid: String, notes: String?) async throws {
        guard let transactionService = transactionService else {
            throw BarkErrorArke.commandFailed("Transaction service not initialized")
        }
        try await transactionService.updateNotes(for: txid, notes: notes)
        dataVersion += 1
        print("📊 DataVersion incremented to \(dataVersion) after notes update")
    }
    
    // MARK: - Preview Support (Remove when no longer needed)
    /// Set model context for preview environments
    func setPreviewContext(_ context: ModelContext) {
        ServiceContainer.shared.configureServices(with: context)
    }
    
    // MARK: - Wallet Operations (delegates to WalletOperationsService)
    
    func send(to address: String, amount: Int) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.send(to: address, amount: amount)
    }
    
    func sendOnchain(to address: String, amount: Int) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.sendOnchain(to: address, amount: amount)
    }
    
    func sendToOnchain(to address: String, amount: Int) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.sendToOnchain(to: address, amount: amount)
    }
    
    func board(amount: Int) async throws {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        try await walletOperationsService.board(amount: amount)
    }
    
    func boardAll() async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.boardAll()
    }
    
    /// Start the exit process for pending VTXOs - checks exit progress and waits
    func startExit() async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.startExit()
    }
    
    /// Synchronize wallet state with the ASP server
    func sync() async throws {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        try await wallet.sync()
    }
    
    /// Exit a specific VTXO by its ID
    func exitVTXO(vtxoId: String, to address: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.exitVTXO(vtxoId: vtxoId, to: address)
    }
    
    /// Progress unilateral exits (broadcast, fee bump, advance state machine)
    func progressExits(feeRateSatPerVb: UInt64?) async throws -> [ExitProgressStatus] {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.progressExits(feeRateSatPerVb: feeRateSatPerVb)
    }
    
    /// Sync exit state (checks status but doesn't progress)
    func syncExits() async throws {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        try await wallet.syncExits()
    }
    
    /// Get all VTXOs currently in exit process
    func getExitVtxos() async throws -> [ExitVtxo] {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.getExitVtxos()
    }
    
    /// Get pending round states
    func pendingRoundStates() async throws -> [RoundState] {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.pendingRoundStates()
    }
    
    /// Progress pending rounds (delegates to RoundProgressionService)
    func progressPendingRounds() async throws {
        guard let service = roundProgressionService else {
            throw BarkErrorArke.commandFailed("Round progression service not initialized")
        }
        try await service.progressRoundsManually()
    }
    
    /// Cancel a specific pending round
    /// - Parameter roundId: The ID of the round to cancel
    func cancelPendingRound(roundId: UInt32) async throws {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        try await wallet.cancelPendingRound(roundId: roundId)
    }
    
    /// Get the next round start time
    /// - Returns: Unix timestamp (seconds since epoch) of when the next round is scheduled to start
    func nextRoundStartTime() async throws -> UInt64 {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.nextRoundStartTime()
    }
    
    /// Drain claimable exits to an onchain address
    func drainExits(vtxoIds: [String], address: String, feeRateSatPerVb: UInt64?) async throws -> ExitClaimTransaction {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.drainExits(vtxoIds: vtxoIds, address: address, feeRateSatPerVb: feeRateSatPerVb)
    }
    
    /// Extract a raw transaction from a PSBT (Partially Signed Bitcoin Transaction)
    /// - Parameter psbtBase64: The PSBT encoded as base64
    /// - Returns: The extracted transaction as hex string
    func extractTxFromPsbt(psbtBase64: String) async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.extractTxFromPsbt(psbtBase64: psbtBase64)
    }
    
    /// Broadcast a raw transaction to the Bitcoin network
    /// - Parameter txHex: The raw transaction encoded as hex string
    /// - Returns: The transaction ID (txid) of the broadcast transaction
    func broadcastTx(txHex: String) async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.broadcastTx(txHex: txHex)
    }
    
    /**
     * Get a pull-based notification holder for this wallet.
     *
     * Call `next_notification()` in a loop to receive events.
     * Call `cancel_next_notification_wait()` to unblock a pending wait without
     * destroying the stream.
     */
    func notifications() -> NotificationHolder {
        guard let wallet = wallet else {
            fatalError("Wallet not initialized")
        }
        return wallet.notifications()
    }
    
    /// Start exit process for specific VTXOs
    func startExitForVTXOs(vtxo_ids: [String]) async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.startExitForVTXOs(vtxo_ids: vtxo_ids)
    }
    
    /// List all exits that are currently claimable
    func listClaimableExits() async throws -> [ExitVtxo] {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.listClaimableExits()
    }
    
    /// Check if there are any pending exits
    func hasPendingExits() async throws -> Bool {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.hasPendingExits()
    }
    
    /// Get total amount in satoshis of all pending exits
    func pendingExitsTotalSats() async throws -> UInt64 {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.pendingExitsTotalSats()
    }
    
    /// Get detailed status for a specific exit
    func getExitStatus(vtxoId: String, includeHistory: Bool, includeTransactions: Bool) async throws -> ExitTransactionStatus? {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.getExitStatus(vtxoId: vtxoId, includeHistory: includeHistory, includeTransactions: includeTransactions)
    }
    
    /// Get the block height at which all exits will be claimable
    func allExitsClaimableAtHeight() async throws -> UInt32? {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.allExitsClaimableAtHeight()
    }
    
    func getVTXOs() async throws -> [VTXOModel] {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getVTXOs()
    }
    
    func allVtxos() async throws -> [Vtxo] {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.allVtxos()
    }
    
    func getUTXOs() async throws -> [UTXOModel] {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getUTXOs()
    }
    
    func getConfig() async throws -> ArkConfigModel {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getConfig()
    }
    
    func getArkInfo() async throws -> ArkInfoModel {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getArkInfo()
    }
    
    // MARK: - Fee Estimation
    
    /// Estimate the fee for boarding funds to Ark
    /// - Parameter amountSats: Amount in satoshis to board
    /// - Returns: Estimated fee in satoshis
    func estimateBoardFee(amountSats: UInt64) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateBoardFee(amountSats: amountSats)
    }
    
    /// Estimate the fee for receiving Lightning payments
    /// - Parameter amountSats: Amount in satoshis to receive
    /// - Returns: Estimated fee in satoshis
    func estimateLightningReceiveFee(amountSats: UInt64) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateLightningReceiveFee(amountSats: amountSats)
    }
    
    /// Estimate the fee for sending Lightning payments
    /// - Parameter amountSats: Amount in satoshis to send
    /// - Returns: Estimated fee in satoshis
    func estimateLightningSendFee(amountSats: UInt64) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateLightningSendFee(amountSats: amountSats)
    }
    
    /// Estimate the fee for offboarding funds from Ark
    /// - Parameters:
    ///   - address: Destination Bitcoin address
    ///   - vtxoIds: Array of VTXO IDs to offboard
    /// - Returns: Estimated fee in satoshis
    func estimateOffboardFee(address: String, vtxoIds: [String]) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateOffboardFee(address: address, vtxoIds: vtxoIds)
    }
    
    /// Estimate the fee for refreshing VTXOs
    /// - Parameter vtxoIds: Array of VTXO IDs to refresh
    /// - Returns: Estimated fee in satoshis
    func estimateRefreshFee(vtxoIds: [String]) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateRefreshFee(vtxoIds: vtxoIds)
    }
    
    /// Estimate the fee for sending an onchain transaction
    /// - Parameters:
    ///   - address: The destination Bitcoin address
    ///   - amountSats: Amount in satoshis to send
    /// - Returns: Estimated fee in satoshis
    func estimateSendOnchainFee(address: String, amountSats: UInt64) async throws -> FeeEstimate {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.estimateSendOnchainFee(address: address, amountSats: amountSats)
    }
    
    /// Refresh VTXOs by calling the wallet's refresh command
    func refreshVTXOs(vtxo_ids: [String]) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.refreshVTXOs(vtxo_ids: vtxo_ids)
    }
    
    /// Schedule maintenance refresh if needed
    /// - Returns: The block height when the next refresh is needed, or nil if no refresh is needed
    func maybeScheduleMaintenanceRefresh() async throws -> UInt32? {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.maybeScheduleMaintenanceRefresh()
    }
    
    /// Perform maintenance refresh (delegated/non-interactive)
    func maintenanceDelegated() async throws {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        try await wallet.maintenanceDelegated()
    }
    
    /// Perform maintenance refresh with onchain wallet (delegated/non-interactive)
    func maintenanceWithOnchainDelegated() async throws {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        try await wallet.maintenanceWithOnchainDelegated()
    }
    
    /// Refresh specific VTXOs (delegated/non-interactive)
    /// - Parameter vtxoIds: Array of VTXO IDs to refresh
    /// - Returns: The round state if a refresh round was created, nil otherwise
    func refreshVtxosDelegated(vtxoIds: [String]) async throws -> RoundState? {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        return try await wallet.refreshVtxosDelegated(vtxoIds: vtxoIds)
    }
    
    func refreshVTXO(vtxo_id: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.refreshVTXO(vtxo_id: vtxo_id)
    }
    
    /// Import a serialized VTXO into the wallet
    /// - Parameter vtxoBase64: Base64-encoded serialized VTXO
    func importVtxo(vtxoBase64: String) async throws {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        try await wallet.importVtxo(vtxoBase64: vtxoBase64)
    }
    
    /// Get the wallet's mnemonic phrase
    func getMnemonic() async throws -> String {
        // Biometric authentication disabled for now
        // TODO: Re-enable biometric authentication when ready
        // let authenticated = try await securityService.authenticateUser(
        //     reason: "Access your wallet recovery phrase"
        // )
        // 
        // guard authenticated else {
        //     throw BarkErrorArke.commandFailed("Authentication failed")
        // }
        
        // Load from secure keychain through SecurityService
        guard let mnemonic = try securityService.loadMnemonic() else {
            throw BarkErrorArke.commandFailed("Mnemonic not found in keychain")
        }
        
        return mnemonic
    }
    
    /// Import an existing wallet using a mnemonic phrase
    func importWallet(mnemonic: String) async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        
        let trimmedMnemonic = mnemonic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMnemonic.isEmpty else {
            throw BarkErrorArke.commandFailed("Mnemonic phrase cannot be empty")
        }
        
        // Validate the mnemonic using SecurityService
        let validation = await securityService.validateMnemonic(trimmedMnemonic)
        
        switch validation {
        case .valid:
            // Mnemonic matches hash in SwiftData - this is a recovery
            print("✅ Mnemonic is valid and matches existing wallet hash - recovering wallet")
            
        case .validNoReference:
            // Valid BIP39 but no reference hash exists - this is a first import
            print("✅ Mnemonic is valid, proceeding with first-time import")
            
        case .invalid:
            throw BarkErrorArke.commandFailed("Invalid mnemonic phrase - doesn't match your wallet")
            
        case .invalidFormat:
            throw BarkErrorArke.commandFailed("Invalid mnemonic format - must be 12, 15, 18, 21, or 24 words")
        }
        
        // Import the wallet
        let result = try await wallet.importWallet(
            network: wallet.networkConfig.networkType,
            asp: wallet.networkConfig.aspBaseURL,
            mnemonic: trimmedMnemonic
        )
        
        // Save mnemonic to keychain and update device registration
        // Note: This also saves hash to NSUbiquitousKeyValueStore for cross-device detection
        do {
            try await securityService.handleSeedImport(trimmedMnemonic)
            print("✅ Mnemonic saved to keychain and device updated")
        } catch {
            print("⚠️ Failed to save mnemonic to keychain: \(error)")
            throw BarkErrorArke.commandFailed("Failed to secure mnemonic: \(error.localizedDescription)")
        }
        
        isInitialized = true
        
        // Start background progression services for imported wallet
        exitProgressionService?.start()
        roundProgressionService?.start()
        lightningClaimService?.start()
        
        // Start wallet notification service
        if let transactionService = transactionService {
            walletNotificationService?.setTransactionService(transactionService)
            walletNotificationService?.start()
        }
        
        return result
    }
    
    /// Create a new wallet
    func createWallet() async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        
        // Execute creation through task manager for deduplication
        return try await taskManager.execute(key: "createWallet") {
            let mnemonic = try await wallet.createWallet(
                network: wallet.networkConfig.networkType,
                asp: wallet.networkConfig.aspBaseURL
            )
            
            print("✅ New wallet created successfully on \(self.currentNetworkName)")
            
            // Save mnemonic to keychain (this also saves hash to NSUbiquitousKeyValueStore)
            do {
                try await self.securityService.saveMnemonic(mnemonic, requireBiometric: false)
                print("✅ Mnemonic saved to keychain and hash synced via iCloud KVS")
            } catch {
                print("⚠️ Failed to save mnemonic to keychain: \(error)")
                throw BarkErrorArke.commandFailed("Failed to secure mnemonic: \(error.localizedDescription)")
            }
            
            self.isInitialized = true
            
            // Start background progression services for new wallet
            self.exitProgressionService?.start()
            self.roundProgressionService?.start()
            self.lightningClaimService?.start()
            
            // Start wallet notification service
            if let transactionService = self.transactionService {
                self.walletNotificationService?.setTransactionService(transactionService)
                self.walletNotificationService?.start()
            }
            
            return mnemonic
        }
    }
    
    /// Delete the current wallet and reset manager state
    /// Note: SecurityService.deleteMnemonic() should be called separately with the appropriate strategy
    func deleteWallet() async throws -> String {
        guard let wallet = wallet else {
            throw BarkErrorArke.commandFailed("Wallet not initialized")
        }
        
        // Execute deletion through task manager for deduplication
        return try await taskManager.execute(key: "deleteWallet") {
            print("🗑️ [WalletManager] Starting wallet deletion...")
            
            // ✅ NEW: Reset manager state FIRST to prevent any operations during deletion
            print("   Step 1: Resetting manager state...")
            await self.resetManagerState()
            
            // ✅ Unregister from push notifications before deletion
            #if os(iOS)
            print("   Step 2: Unregistering from push notifications...")
            await self.unregisterFromPushNotifications()
            #endif
            
            // ✅ NEW: Give services time to release any resources
            print("   Step 3: Waiting for services to settle...")
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // Now delete the wallet (this handles FFI cleanup internally)
            print("   Step 4: Deleting wallet files...")
            let result = try await wallet.deleteWallet()
            
            // Note: Mnemonic deletion is now handled by the caller (DeleteWalletSettingView)
            // This allows for intelligent deletion strategies based on device registry
            
            print("✅ Wallet deleted and manager state reset")
            return result
        }
    }
    
    /// Reset all manager and service state after wallet deletion
    private func resetManagerState() async {
        // Stop all background services
        exitProgressionService?.stop()
        roundProgressionService?.stop()
        vtxoRefreshService?.stop()
        lightningClaimService?.stop()
        walletNotificationService?.stop()
        
        // Reset coordinator state
        isInitialized = false
        error = nil
        isRefreshing = false
        hasLoadedOnce = false
        
        // Reset balance service state
        balanceService?.arkBalance = nil
        balanceService?.onchainBalance = nil
        balanceService?.totalBalance = nil
        balanceService?.error = nil
        
        // Reset transaction service state (clear transactions)
        await transactionService?.clearTransactionModels()
        transactionService?.error = nil
        transactionService?.hasLoadedTransactions = false
        
        // Reset address service state
        addressService?.arkAddress = ""
        addressService?.onchainAddress = ""
        addressService?.error = nil
        
        // Clear persisted balance data
        balanceService?.resetBalances()
        
        print("🔄 All manager and service state reset")
    }
    
    func getLatestBlockHeight() async throws -> Int {
        return try await getBlockHeightWithDeduplication()
    }
    
    private func getBlockHeightWithDeduplication() async throws -> Int {
        // Check cache first
        if let cached = cacheManager.blockHeight.value {
            print("📦 Using cached block height: \(cached)")
            return cached
        }
        
        return try await taskManager.execute(key: "blockHeight") {
            guard let wallet = self.wallet else {
                throw BarkErrorArke.commandFailed("Wallet not initialized")
            }
            let result = try await wallet.getLatestBlockHeight()
            
            // Update cache
            self.cacheManager.blockHeight.setValue(result)
            print("🔗 Fetched latest block height: \(result)")
            
            return result
        }
    }


    func getTransactions() async throws -> String {
        return try await transactionService?.getTransactions() ?? ""
    }
    
    /// Get the current Ark balance response - delegates to balance service
    func getArkBalance() async throws -> ArkBalanceResponse {
        guard let balanceService = balanceService else {
            throw BarkErrorArke.commandFailed("Balance service not initialized")
        }
        
        return try await balanceService.getArkBalance()
    }
    
    /// Get the current onchain balance response - delegates to balance service
    func getOnchainBalance() async throws -> OnchainBalanceResponse {
        guard let balanceService = balanceService else {
            throw BarkErrorArke.commandFailed("Balance service not initialized")
        }
        return try await balanceService.getOnchainBalance()
    }
    
    /// Get onchain transactions from the BDK wallet - delegates to onchain transaction service
    func getOnchainTransactions() async throws -> [OnchainTransactionModel] {
        guard let service = onchainTransactionService else {
            throw BarkErrorArke.commandFailed("Onchain transaction service not initialized")
        }
        return try await service.getTransactions()
    }
    
    /// Refresh onchain transactions
    func refreshOnchainTransactions() async {
        await onchainTransactionService?.refreshTransactions()
    }
    
    // MARK: - Custom Command Execution
    
    /// Execute a custom bark CLI command
    /// - Parameter commandString: The command to execute (e.g., "balance", "vtxos --limit 5")
    /// - Returns: Raw command output
    /// - Note: For development and debugging purposes
    func executeCustomCommand(_ commandString: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.executeCustomCommand(commandString)
    }
    
    // MARK: - Lightning Operations
    
    /// Generate a Lightning invoice for the specified amount
    func getLightningInvoice(amount: Int) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getLightningInvoice(amount: amount)
    }
    
    /// Pay a Lightning invoice
    func payLightningInvoice(invoice: String, amount: Int) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.payLightningInvoice(invoice: invoice, amount: amount)
    }
    
    /// Pay a Lightning invoice with optional amount (for invoices that may already include an amount)
    func payLightningInvoice(invoice: String, amount: Int?) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.payLightningInvoice(invoice: invoice, amount: amount)
    }
    
    /// Get the status of a Lightning invoice
    func getLightningInvoiceStatus(invoice: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getLightningInvoiceStatus(invoice: invoice)
    }
    
    /// List all Lightning invoices
    func listLightningInvoices() async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.listLightningInvoices()
    }
    
    // MARK: - Process State Management
    
    /// Confirm that wallet has been backed up
    func confirmBackup() throws {
        guard let processStateService = processStateService else {
            throw BarkErrorArke.commandFailed("Process state service not initialized")
        }
        try processStateService.confirmBackup()
    }
    
    /// Snooze the backup reminder
    func snoozeBackupReminder() throws {
        guard let processStateService = processStateService else {
            throw BarkErrorArke.commandFailed("Process state service not initialized")
        }
        try processStateService.snoozeBackupReminder()
    }
    
    /// Dismiss the backup reminder
    func dismissBackupReminder() throws {
        guard let processStateService = processStateService else {
            throw BarkErrorArke.commandFailed("Process state service not initialized")
        }
        try processStateService.dismissBackupReminder()
    }
    
    
    /// Claim a Lightning invoice
    func claimLightningInvoice(invoice: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.claimLightningInvoice(invoice: invoice)
    }
    
    // MARK: - Convenience Methods for Individual Refreshes (delegates to BalanceService)
    
    /// Refresh server connection - delegates to wallet
    func refreshServer() async {
        guard let wallet = wallet else {
            print("⚠️ Cannot refresh server: wallet not initialized")
            return
        }
        
        do {
            try await wallet.refreshServer()
        } catch {
            print("⚠️ Failed to refresh server: \(error)")
            self.error = "Failed to refresh server connection: \(error.localizedDescription)"
        }
    }
    
    /// Refresh just Ark balance - delegates to balance service
    func refreshArkBalance() async {
        await balanceService?.refreshArkBalance()
        // Update local error state if balance service encountered an error
        if let balanceError = balanceService?.error {
            self.error = balanceError
        }
    }
    
    /// Refresh just onchain balance - delegates to balance service
    func refreshOnchainBalance() async {
        await balanceService?.refreshOnchainBalance()
        // Update local error state if balance service encountered an error
        if let balanceError = balanceService?.error {
            self.error = balanceError
        }
    }
    
    /// Load wallet addresses
    func loadAddresses() async {
        await addressService?.loadAddresses()
        // Update local error state if address service encountered an error
        if let addressError = addressService?.error {
            self.error = addressError
        }
    }
    
    /// Generate a new address
    func generateNewAddress(type: AddressType, strategy: AddressGenerationStrategy = .userRequested) async throws -> PersistentAddress {
        guard let addressService = addressService else {
            throw BarkErrorArke.commandFailed("Address service not available")
        }
        return try await addressService.generateNewAddress(type: type, strategy: strategy)
    }
    
    /// Get estimated block height, fetching cached data if needed
    func getEstimatedBlockHeight() async -> Int? {
        // Ensure we have both cached block height and ark info
        if cacheManager.blockHeight.value == nil {
            do {
                _ = try await getLatestBlockHeight()
            } catch {
                print("⚠️ Failed to fetch block height for estimation: \(error)")
            }
        }
        
        // Cache ArkInfo if needed using balance service
        if cacheManager.arkInfo.value == nil {
            await balanceService?.cacheArkInfoIfNeeded()
        }
        
        return cacheManager.getEstimatedBlockHeight()
    }
    
    // MARK: - Data Export
    
    /// Export all wallet data as JSON
    func exportWalletData() async throws -> Data {
        return try await taskManager.execute(key: "exportData") {
            try await self.performDataExport()
        }
    }
    
    private func performDataExport() async throws -> Data {
        // Gather async data first
        let vtxos = try await getVTXOs()
        let utxos = try await getUTXOs()
        let configuration = try await getConfig()
        
        // Get arkInfo with fallback
        let currentArkInfo: ArkInfoModel
        if let cached = arkInfo {
            currentArkInfo = cached
        } else {
            currentArkInfo = try await getArkInfo()
        }
        
        // Get block height with fallback
        let currentBlockHeight: Int
        if let cached = estimatedBlockHeight {
            currentBlockHeight = cached
        } else {
            currentBlockHeight = try await getLatestBlockHeight()
        }
        
        // Create export data
        let exportData = WalletExportData(
            addresses: WalletExportData.AddressData(
                arkAddress: arkAddress,
                onchainAddress: onchainAddress
            ),
            balances: WalletExportData.BalanceData(
                arkBalance: arkBalance.map { model in
                    ArkBalanceResponse(
                        spendableSat: model.spendableSat,
                        pendingLightningSendSat: model.pendingLightningSendSat,
                        pendingInRoundSat: model.pendingInRoundSat,
                        pendingExitSat: model.pendingExitSat,
                        pendingBoardSat: model.pendingBoardSat
                    )
                },
                onchainBalance: onchainBalance.map { model in
                    OnchainBalanceResponse(
                        totalSat: model.totalSat,
                        confirmedSat: model.confirmedSat,
                        pendingSat: model.pendingSat
                    )
                }
            ),
            transactions: transactions.map { WalletExportData.ExportTransactionData(from: $0) },
            vtxos: vtxos,
            utxos: utxos,
            configuration: configuration,
            arkInfo: currentArkInfo,
            blockHeight: currentBlockHeight,
            exportTimestamp: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try encoder.encode(exportData)
    }
    
    // MARK: - Push Notification Registration
    
    #if os(iOS)
    /// Registers device for push notifications with the relay
    /// Call this when APNs token is received or when authorization needs refresh
    func registerForPushNotifications() async {
        guard let wallet = wallet,
              let relayService = relayRegistrationService else {
            print("⚠️ [WalletManager] Cannot register for push - wallet or relay service not available")
            return
        }
        
        // Ensure wallet is initialized before attempting registration
        guard isInitialized else {
            print("⚠️ [WalletManager] Cannot register for push - wallet not yet initialized")
            print("   This is normal during app startup. Registration will be retried after initialization.")
            return
        }
        
        // Check if user has enabled notifications in settings
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
        guard notificationsEnabled else {
            print("⚠️ [WalletManager] Notifications disabled in settings")
            return
        }
        
        // Get APNs token from UserDefaults (set by AppDelegate)
        guard let deviceToken = UserDefaults.standard.string(forKey: "apns_device_token"),
              !deviceToken.isEmpty else {
            print("⚠️ [WalletManager] No APNs device token available")
            return
        }
        
        do {
            // Get mailbox credentials from wallet
            let mailboxId = try await wallet.mailboxIdentifier()
            let authorizationHex = try await wallet.mailboxAuthorization()
            
            // Get Ark server URL from config
            let config = try await wallet.getConfig()
            let arkAddr = config.ark
            guard !arkAddr.isEmpty else {
                print("❌ [WalletManager] No Ark server URL in config")
                return
            }
            
            // Get bundle identifier for APNs topic
            let apnsTopic = Bundle.main.bundleIdentifier ?? "com.arke.wallet"
            
            // Debug: Log registration parameters (redact sensitive auth)
            print("📋 [WalletManager] Registration params:")
            print("  - mailboxId: \(mailboxId.prefix(8))... (len: \(mailboxId.count))")
            print("  - authorizationHex: \(authorizationHex.prefix(8))... (len: \(authorizationHex.count))")
            print("  - arkAddr: \(arkAddr)")
            print("  - deviceToken: \(deviceToken.prefix(8))... (len: \(deviceToken.count))")
            print("  - apnsTopic: \(apnsTopic)")
            
            // Register with relay
            try await relayService.registerDevice(
                mailboxId: mailboxId,
                authorizationHex: authorizationHex,
                arkAddr: arkAddr,
                deviceToken: deviceToken,
                apnsTopic: apnsTopic
            )
            
            print("✅ [WalletManager] Successfully registered for push notifications")
        } catch {
            print("❌ [WalletManager] Failed to register for push: \(error.localizedDescription)")
        }
    }
    
    /// Unregisters device from push notifications
    /// Call this when user logs out or deletes wallet
    func unregisterFromPushNotifications() async {
        guard let wallet = wallet,
              let relayService = relayRegistrationService else {
            return
        }
        
        guard let deviceToken = UserDefaults.standard.string(forKey: "apns_device_token"),
              !deviceToken.isEmpty else {
            return
        }
        
        do {
            let mailboxId = try await wallet.mailboxIdentifier()
            
            try await relayService.unregisterDevice(
                mailboxId: mailboxId,
                deviceToken: deviceToken
            )
            
            print("✅ [WalletManager] Successfully unregistered from push notifications")
        } catch {
            print("❌ [WalletManager] Failed to unregister from push: \(error.localizedDescription)")
        }
    }
    #endif

}

enum BarkErrorArke: Error, LocalizedError {
    case binaryNotFound
    case commandFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "bark binary not found in app bundle"
        case .commandFailed(let message):
            return message
        }
    }
}

