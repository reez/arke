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
import OSLog

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
    /// Logger for WalletManager operations
    nonisolated static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.arke", category: "WalletManager")
    
    // MARK: - Coordinator State
    var isInitialized: Bool = false
    var error: String?
    var isRefreshing: Bool = false
    var hasLoadedOnce: Bool = false
    
    /// Whether this device is in read-only mode (not the primary device)
    /// When true, wallet operations like send/receive are unavailable
    var isReadOnlyMode: Bool = false
    
    /// Counter for active refresh calls (used to track concurrent refresh attempts)
    private var activeRefreshCount: Int = 0
    
    /// Increments whenever persistent relationships change (contacts, tags, etc.)
    /// Views can observe this to refresh when relationship data changes
    var dataVersion: Int = 0
    
    /// Increments whenever transactions are updated
    /// Views can observe this to react to transaction list changes (e.g., refresh status indicators)
    var transactionVersion: Int = 0
    
    // MARK: - Services
    // WARNING: These properties are internal (not private) only to allow access from extension files.
    // DO NOT access these directly from outside WalletManager and its extensions.
    // Always use the public API methods instead.
    var wallet: BarkWalletProtocol?
    let taskManager = TaskDeduplicationManager()
    let cacheManager = WalletCacheManager()
    var modelContext: ModelContext?
    
    var transactionService: TransactionService?
    var balanceService: BalanceService?
    var readOnlyBalanceService: ReadOnlyBalanceService?
    var addressService: AddressService?
    var readOnlyAddressService: ReadOnlyAddressService?
    var walletOperationsService: WalletOperationsService?
    var processStateService: ProcessStateService?
    var exitProgressionService: ExitProgressionService?
    var roundProgressionService: RoundProgressionService?
    var vtxoRefreshService: VTXORefreshService?
    var lightningClaimService: LightningClaimService?
    var onchainTransactionService: OnchainTransactionService?
    var unifiedTransactionService: UnifiedTransactionService?  // Unified ark + onchain transactions
    var transactionLinkingService: TransactionLinkingService?  // Movement-onchain linking
    var relayRegistrationService: RelayRegistrationService?
    var walletNotificationService: WalletNotificationService?
    
    // Services from ServiceContainer (internal for extension access)
    var securityService: SecurityService { ServiceContainer.shared.securityService }
    var tagService: TagService { ServiceContainer.shared.tagService }
    var contactService: ContactService { ServiceContainer.shared.contactService }
    var contactAddressService: ContactAddressService { ServiceContainer.shared.contactAddressService }
    
    /// Cached exit VTXOs
    var cachedExitVtxos: [ExitVtxo] = []
    var exitVtxosCacheTime: Date?
    let exitCacheTimeout: TimeInterval = 30 // 30 seconds
    
    /// Cached exit statuses for linking
    var cachedExitStatuses: [String: ExitTransactionStatus] = [:]  // vtxoId -> status
    var exitStatusesCacheTime: Date?
    
    // MARK: - Network Info Properties
    var currentNetworkName: String {
        wallet?.currentNetworkName ?? "Unknown"
    }
    
    var isMainnet: Bool {
        wallet?.isMainnet ?? false
    }
    
    var networkConfig: NetworkConfig? {
        wallet?.networkConfig
    }
    
    // MARK: - Address & Balance Properties
    // Convenience properties that delegate to respective services
    
    var arkAddress: String {
        if isReadOnlyMode {
            return readOnlyAddressService?.arkAddress ?? ""
        } else {
            return addressService?.arkAddress ?? ""
        }
    }
    
    var onchainAddress: String {
        if isReadOnlyMode {
            return readOnlyAddressService?.onchainAddress ?? ""
        } else {
            return addressService?.onchainAddress ?? ""
        }
    }
    
    var arkBalance: ArkBalanceModel? {
        isReadOnlyMode ? readOnlyBalanceService?.arkBalance : balanceService?.arkBalance
    }
    
    var onchainBalance: OnchainBalanceModel? {
        isReadOnlyMode ? readOnlyBalanceService?.onchainBalance : balanceService?.onchainBalance
    }
    
    var totalBalance: TotalBalanceModel? {
        isReadOnlyMode ? readOnlyBalanceService?.totalBalance : balanceService?.totalBalance
    }
    

    
    // Note: Tag properties moved to WalletManager+Tags.swift
    // Note: Contact properties moved to WalletManager+Contacts.swift
    
    // MARK: - Formatted Balance Properties
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
    
    // MARK: - State Check Properties
    var hasPendingBalance: Bool {
        isReadOnlyMode ? (readOnlyBalanceService?.hasPendingBalance ?? false) : (balanceService?.hasPendingBalance ?? false)
    }
    
    var hasSpendableBalance: Bool {
        isReadOnlyMode ? (readOnlyBalanceService?.hasSpendableBalance ?? false) : (balanceService?.hasSpendableBalance ?? false)
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
        
        // Load network config with priority:
        // 1. Explicit parameter (for testing/overrides)
        // 2. Saved config from previous wallet creation/import
        // 3. Default to signet
        let config: NetworkConfig
        if let explicitConfig = networkConfig {
            config = explicitConfig
            Self.logger.info("Using explicit network config: \(config.name)")
        } else if let savedConfig = NetworkConfigPersistence.load() {
            config = savedConfig
            Self.logger.info("Loaded saved network config: \(config.name)")
        } else {
            config = NetworkConfig.signet
            Self.logger.info("No saved config found, using default: \(config.name)")
        }
        
        setupWallet(useMock: shouldUseMock, networkConfig: config)
        initializeServices()
        
        // Set up notification observer for mailbox updates (iOS only)
        #if os(iOS)
        setupMailboxNotificationObserver()
        #endif
        
        #if DEBUG
        if skipWalletOpen && !useMock {
            Self.logger.debug("🎭 [DEBUG] Auto-enabled mock wallet for fast debugging")
        }
        #endif
    }
    
    /// Convenience initializer for different networks
    static func forNetwork(_ networkConfig: NetworkConfig, useMock: Bool = false) -> WalletManager {
        return WalletManager(useMock: useMock, networkConfig: networkConfig)
    }
    
    private func setupWallet(useMock: Bool, networkConfig: NetworkConfig) {
        if useMock {
            wallet = MockBarkWallet()
        } else {
            wallet = BarkWalletFFI(networkConfig: networkConfig, securityService: securityService)
            if wallet == nil {
                Self.logger.error("❌ Failed to initialize BarkWalletFFI with network config: \(networkConfig.name)")
            } else {
                Self.logger.info("✅ Using BarkWalletFFI implementation")
            }
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
        
        // Initialize transaction linking service (for movement-onchain linking)
        transactionLinkingService = TransactionLinkingService(walletManager: self)
        
        // Set linking service on transaction service
        transactionService?.setLinkingService(transactionLinkingService)
        
        // Initialize unified transaction service (merges ark + onchain)
        if let transactionService = transactionService,
           let onchainService = onchainTransactionService {
            unifiedTransactionService = UnifiedTransactionService(
                arkService: transactionService,
                onchainService: onchainService,
                walletManager: self
            )
            Self.logger.info("🔗 [WalletManager] UnifiedTransactionService initialized")
        }
        
        // Initialize relay registration service for APNs notifications
        #if os(iOS)
        let relayAPIToken = Bundle.main.object(forInfoDictionaryKey: "RelayAPIToken") as? String
        relayRegistrationService = RelayRegistrationService(relayAPIToken: relayAPIToken)
        Self.logger.info("📮 [WalletManager] RelayRegistrationService initialized\(relayAPIToken != nil ? " with API token" : " without API token")")
        #endif
        
        // Initialize wallet notification service for real-time movement updates
        walletNotificationService = WalletNotificationService(wallet: wallet)
        walletNotificationService?.setWalletManager(self)
        Self.logger.info("🔔 [WalletManager] WalletNotificationService initialized")
        
        // TagService and ContactService are initialized in init(), not here
        
        // Configure post-transaction callback
        walletOperationsService?.setTransactionCompletedCallback { [weak self] in
            await self?.balanceService?.refreshAfterTransaction()
            await self?.transactionService?.refreshTransactions()
            // Increment backup transaction count after each transaction
            self?.processStateService?.incrementBackupTransactionCount()
            // Increment dataVersion to notify UI that transaction data has changed
            self?.dataVersion += 1
            Self.logger.info("📊 DataVersion incremented to \(self?.dataVersion ?? 0) after transaction")
        }
    }
    
    func setModelContext(_ context: ModelContext, caller: String = #function, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        Self.logger.info("🔧 [WalletManager] 📞 setModelContext() CALLED")
        Self.logger.info("   ├─ From: \(fileName):\(line)")
        Self.logger.info("   └─ Function: \(caller)")
        
        self.modelContext = context
        
        // Initialize AddressService now that we have a ModelContext
        if isReadOnlyMode {
            // Read-only mode: Use ReadOnlyAddressService (no wallet required)
            if readOnlyAddressService == nil {
                readOnlyAddressService = ReadOnlyAddressService(modelContext: context)
                Self.logger.info("📍 [WalletManager] Initialized ReadOnlyAddressService for read-only mode")
            }
            // Initialize ReadOnlyBalanceService
            if readOnlyBalanceService == nil {
                readOnlyBalanceService = ReadOnlyBalanceService()
                Self.logger.info("💰 [WalletManager] Initialized ReadOnlyBalanceService for read-only mode")
            }
            readOnlyBalanceService?.setModelContext(context)
        } else if let wallet = wallet, addressService == nil {
            // Primary mode: Use full AddressService
            addressService = AddressService(wallet: wallet, taskManager: taskManager, modelContext: context)
            Self.logger.info("📍 [WalletManager] Initialized AddressService for primary mode")
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
        Self.logger.info("🔧 [WalletManager] 📞 initialize() CALLED")
        Self.logger.info("   ├─ Time: \(Date())")
        Self.logger.info("   ├─ From: \(fileName):\(line)")
        Self.logger.info("   └─ Function: \(caller)")
        
        await taskManager.execute(key: "initialize") {
            Self.logger.info("🔧 [WalletManager] initialize execute at \(Date())")
            await self.performInitialization()
            Self.logger.info("🔧 [WalletManager] initialize execute done at \(Date())")
        }
    }
    
    /// Checks if this device is in read-only mode (not the primary device)
    private func checkReadOnlyMode() async {
        let deviceService = ServiceContainer.shared.deviceRegistrationService
        
        do {
            if let currentDevice = try await deviceService.getCurrentDevice() {
                isReadOnlyMode = !currentDevice.isPrimaryDevice
                
                if isReadOnlyMode {
                    Self.logger.info("🔒 [WalletManager] Device is in read-only mode (not primary device)")
                } else {
                    Self.logger.info("✅ [WalletManager] Device is primary - full wallet mode")
                }
            } else {
                // No device registration yet - assume primary (first device)
                isReadOnlyMode = false
                Self.logger.info("ℹ️ [WalletManager] No device registration found, assuming primary device")
            }
        } catch {
            // On error, assume primary to avoid blocking access
            isReadOnlyMode = false
            Self.logger.warning("⚠️ [WalletManager] Failed to check device status: \(error). Assuming primary device")
        }
    }
    
    private func performInitialization() async {
        Self.logger.info("🔧 [WalletManager] Starting initialization...")
        
        // Step 0: Check if this device is the primary device
        await checkReadOnlyMode()
        
        // Step 1: Branch based on read-only mode
        if isReadOnlyMode {
            await initializeReadOnlyMode()
        } else {
            await initializePrimaryMode()
        }
    }
    
    /// Initialize wallet in full mode (primary device with ASP connection)
    private func initializePrimaryMode() async {
        guard let wallet = wallet else {
            error = "Wallet not available"
            return
        }
        
        Self.logger.info("🔧 [WalletManager] Initializing in PRIMARY mode (full wallet access)")
        
        // Step 1: Explicitly open the wallet if it exists (FFI only)
        if let ffiWallet = wallet as? BarkWalletFFI {
            let opened = await ffiWallet.openWalletIfNeeded()
            if !opened {
                Self.logger.info("ℹ️ No existing wallet to open - user needs to create or import")
                isInitialized = false
                return
            }
            Self.logger.info("✅ Wallet opened successfully")
        }
        
        // Step 2: Check wallet existence using SecurityService (Keychain)
        let walletExists = securityService.hasMnemonic()
        
        if walletExists {
            Self.logger.info("✅ Wallet mnemonic found in Keychain - wallet exists on \(self.currentNetworkName)")
            isInitialized = true
            
            #if DEBUG
            Self.logger.debug("📍 [ADDRESS TRACE] performInitialization() about to call refresh()")
            Self.logger.debug("   This will trigger address generation")
            #endif
            
            // Load all wallet data for existing wallet
            await refresh()
            
            // Create default tags if needed (after data is loaded)
            await createDefaultTagsIfNeeded()
            
            if !isMainnet {
                // Create default contacts if needed (after data is loaded)
                await createDefaultContactsIfNeeded()
            }
            
            // Ensure arkInfo is loaded before starting services that depend on it
            if arkInfo == nil {
                Self.logger.info("ℹ️ [WalletManager] arkInfo not yet loaded, caching now...")
                await balanceService?.cacheArkInfoIfNeeded()
                if arkInfo != nil {
                    Self.logger.info("✅ [WalletManager] arkInfo cached successfully")
                } else {
                    Self.logger.warning("⚠️ [WalletManager] Failed to cache arkInfo")
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
            Self.logger.warning("⚠️ No mnemonic found in Keychain - wallet needs to be created or imported on \(self.currentNetworkName)")
            isInitialized = false
        }
    }
    
    /// Initialize wallet in read-only mode (secondary device with CloudKit sync only)
    private func initializeReadOnlyMode() async {
        Self.logger.info("🔒 [WalletManager] Initializing in READ-ONLY mode (CloudKit sync only)")
        
        // Initialize ReadOnlyAddressService if not already done
        // (It might not exist if setModelContext was called before isReadOnlyMode was set)
        if readOnlyAddressService == nil, let context = modelContext {
            readOnlyAddressService = ReadOnlyAddressService(modelContext: context)
            Self.logger.info("📍 [WalletManager] Initialized ReadOnlyAddressService in initializeReadOnlyMode")
        }
        
        // Initialize ReadOnlyBalanceService if not already done
        if readOnlyBalanceService == nil {
            readOnlyBalanceService = ReadOnlyBalanceService()
            if let context = modelContext {
                readOnlyBalanceService?.setModelContext(context)
            }
            Self.logger.info("💰 [WalletManager] Initialized ReadOnlyBalanceService in initializeReadOnlyMode")
        }
        
        // Check if wallet data exists via CloudKit sync
        // We don't check for local wallet file or mnemonic since this is a secondary device
        let deviceService = ServiceContainer.shared.deviceRegistrationService
        
        do {
            // Verify we have a valid device registration with wallet info
            if let currentDevice = try await deviceService.getCurrentDevice(),
               !currentDevice.walletHash.isEmpty {
                Self.logger.info("✅ [WalletManager] Device registered with wallet hash - enabling read-only access")
                isInitialized = true
                
                // Create default tags if needed (uses CloudKit)
                await createDefaultTagsIfNeeded()
                
                if !isMainnet {
                    // Create default contacts if needed (uses CloudKit)
                    await createDefaultContactsIfNeeded()
                }
                
                // Load addresses from database (CloudKit-synced)
                await readOnlyAddressService?.loadAddresses()
                Self.logger.info("📍 [WalletManager] Loaded addresses from database in read-only mode")
                
                Self.logger.info("✅ [WalletManager] Read-only mode initialized successfully")
            } else {
                Self.logger.info("ℹ️ [WalletManager] No wallet data available yet - user needs to set up wallet on primary device")
                isInitialized = false
            }
        } catch {
            Self.logger.error("❌ [WalletManager] Failed to initialize read-only mode: \(error)")
            isInitialized = false
            self.error = "Failed to initialize read-only mode: \(error.localizedDescription)"
        }
    }
    
    /// Centralized refresh - orchestrates all services
    func refresh(caller: String = #function, file: String = #file, line: Int = #line) async {
        let fileName = (file as NSString).lastPathComponent
        Self.logger.info("🔄 [WalletManager] 📞 refresh() CALLED")
        Self.logger.info("   ├─ From: \(fileName):\(line)")
        Self.logger.info("   └─ Function: \(caller)")
        
        // Increment counter and set isRefreshing if this is the first active call
        activeRefreshCount += 1
        let refreshNumber = activeRefreshCount
        Self.logger.info("🔄 [REFRESH STATE] Active refresh count: \(self.activeRefreshCount), refresh #\(refreshNumber)")
        
        if activeRefreshCount == 1 {
            Self.logger.info("🔄 [REFRESH STATE] Setting isRefreshing = true (first active refresh)")
            isRefreshing = true
        } else {
            Self.logger.info("🔄 [REFRESH STATE] Additional concurrent refresh call (not changing isRefreshing)")
        }
        
        defer {
            // Decrement counter and clear isRefreshing only when all calls complete
            activeRefreshCount -= 1
            Self.logger.info("🔄 [REFRESH STATE] Refresh #\(refreshNumber) completed. Active count now: \(self.activeRefreshCount)")
            
            if activeRefreshCount == 0 {
                Self.logger.info("🔄 [REFRESH STATE] Setting isRefreshing = false (all refreshes complete)")
                isRefreshing = false
            }
        }
        
        await taskManager.execute(key: "refresh") {
            await self.performRefresh()
        }
        
        Self.logger.info("🔄 [REFRESH STATE] refresh() #\(refreshNumber) returning")
    }
    
    private func performRefresh() async {
        Self.logger.info("WalletManager.performRefresh")
        
        #if DEBUG
        Self.logger.debug("📍 [ADDRESS TRACE] WalletManager.performRefresh() starting address load")
        Self.logger.debug("   📞 Called from:")
        Thread.callStackSymbols.prefix(6).enumerated().forEach { index, symbol in
            Self.logger.debug("      \(index): \(symbol)")
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
        Self.logger.info("🔄 [Refresh] Step 1: Refreshing server connection...")
        await refreshServer()
        // Note: refreshServer() doesn't throw, it sets self.error on failure
        if error != nil {
            Self.logger.warning("⚠️ [Refresh] Server refresh failed, but continuing with data refresh")
            // We don't return here - we'll try to continue with the refresh
        } else {
            anyServerCallSucceeded = true
            Self.logger.info("✅ [Refresh] Server connection successful")
        }
        
        // Step 2: Sync wallet state with ASP server
        Self.logger.info("🔄 [Refresh] Step 2: Syncing wallet state with server...")
        do {
            try await sync()
            anyServerCallSucceeded = true
            Self.logger.info("✅ [Refresh] Wallet state synced successfully")
        } catch {
            Self.logger.warning("⚠️ [Refresh] Wallet sync failed: \(error)")
            // We'll continue with the refresh even if sync fails
            // The user's local cache might still be usable
        }
        
        // Step 3: Coordinate service refreshes in parallel where possible
        Self.logger.info("🔄 [Refresh] Step 3: Refreshing wallet data (balances, addresses, transactions, block height)...")
        await withTaskGroup(of: Void.self) { group in
            // Balance service handles its own coordination
            group.addTask { 
                await self.balanceService?.refreshAllBalances() 
            }
            
            // Address loading
            group.addTask {
                #if DEBUG
                Self.logger.debug("📍 [ADDRESS TRACE] Task group calling addressService.loadAddresses()")
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
            
            // Block height fetch (needed for VTXO expiry calculations)
            group.addTask {
                do {
                    _ = try await self.getLatestBlockHeight()
                } catch {
                    Self.logger.warning("⚠️ [Refresh] Failed to fetch block height: \(error)")
                }
            }
        }
        
        // Merge transactions from both sources after refresh
        Self.logger.info("🔄 [Refresh] Step 3.1: Merging ark + onchain transactions...")
        await unifiedTransactionService?.mergeTransactions()
        
        // Check for errors from services and log them for debugging
        if let addressError = addressService?.error {
            Self.logger.warning("⚠️ [Refresh] AddressService error: \(addressError)")
            self.error = addressError
        }
        else if let transactionError = transactionService?.error {
            Self.logger.warning("⚠️ [Refresh] TransactionService error: \(transactionError)")
            self.error = transactionError
        }
        else if let balanceError = balanceService?.error {
            Self.logger.warning("⚠️ [Refresh] BalanceService error: \(balanceError)")
            self.error = balanceError
        }
        else if let onchainTxError = onchainTransactionService?.error {
            Self.logger.warning("⚠️ [Refresh] OnchainTransactionService error: \(onchainTxError)")
            self.error = onchainTxError
        } else {
            error = nil
        }
        
        // Step 4: After successful refresh, update process state service and exit cache
        Self.logger.info("🔄 [Refresh] Step 4: Updating process states and exit cache...")
        await refreshProcessStates(isConnected: anyServerCallSucceeded)
        await refreshExitCache()
        
        if error == nil {
            Self.logger.info("✅ All wallet data refreshed successfully on \(self.currentNetworkName)")
        } else {
            Self.logger.warning("⚠️ Wallet refresh completed with errors on \(self.currentNetworkName)")
        }
        
        // CRITICAL: Always increment dataVersion to trigger UI updates, even if there were errors
        // This ensures the UI shows whatever data we did manage to fetch
        dataVersion += 1
        Self.logger.info("📊 DataVersion incremented to \(self.dataVersion) after refresh (triggers UI update)")
    }
    
    /// Refresh process states after wallet data is loaded
    private func refreshProcessStates(isConnected: Bool) async {
        guard let processStateService = processStateService else { return }
        
        // Get VTXOs from wallet operations
        let vtxos: [VTXOModel]
        do {
            vtxos = try await getVTXOs()
        } catch {
            Self.logger.warning("⚠️ Could not fetch VTXOs for process state update: \(error)")
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
    
    // MARK: - Extension References
    // See WalletManager+Tags.swift for tag operations
    // See WalletManager+Contacts.swift for contact operations
    // See WalletManager+ContactAddresses.swift for contact address operations
    // See WalletManager+Transactions.swift for transaction operations
    
    // MARK: - Preview Support (Remove when no longer needed)
    /// Set model context for preview environments
    func setPreviewContext(_ context: ModelContext) {
        ServiceContainer.shared.configureServices(with: context)
    }
    
    // See WalletManager+Operations.swift for wallet operations
    // See WalletManager+Fees.swift for fee estimation
    // See WalletManager+Wallet.swift for wallet lifecycle
    // See WalletManager+Lightning.swift for Lightning operations
    // See WalletManager+Exits.swift for exit operations
    // See WalletManager+Refresh.swift for refresh helpers
    // See WalletManager+Export.swift for data export
    // See WalletManager+Data.swift for data retrieval
    // See WalletManager+ProcessState.swift for process state
    // See WalletManager+CustomCommands.swift for custom commands
    // See WalletManager+Notifications.swift for push notifications (iOS)
    // See WalletManager+PaymentDestination.swift for payment context helpers
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

