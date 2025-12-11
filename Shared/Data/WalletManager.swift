//
//  WalletManager.swift
//  Ark wallet prototype
//
//  Created by Christoph on 10/16/25.
//

import Foundation
import SwiftUI
import SwiftData

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
        transactionService?.transactions ?? []
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
        let onchainSpendable = onchainBalance?.trustedSpendableSat ?? 0
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
        
        #if DEBUG
        if skipWalletOpen && !useMock {
            print("🎭 [DEBUG] Auto-enabled mock wallet for fast debugging")
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
            // iOS and other platforms: Always use FFI implementation
            wallet = BarkWalletFFI(networkConfig: networkConfig, securityService: securityService)
            if wallet == nil {
                print("❌ Failed to initialize BarkWalletFFI with network config: \(networkConfig.name)")
            } else {
                print("✅ Using BarkWalletFFI implementation")
            }
            #endif
        }
    }
    
    private func initializeServices() {
        guard let wallet = wallet else { return }
        
        // Initialize all services with shared task manager and cache manager
        transactionService = TransactionService(wallet: wallet, taskManager: taskManager)
        balanceService = BalanceService(wallet: wallet, taskManager: taskManager, cacheManager: cacheManager)
        addressService = AddressService(wallet: wallet, taskManager: taskManager)
        walletOperationsService = WalletOperationsService(wallet: wallet, taskManager: taskManager)
        // TagService and ContactService are initialized in init(), not here
        
        // Configure post-transaction callback
        walletOperationsService?.setTransactionCompletedCallback { [weak self] in
            await self?.balanceService?.refreshAfterTransaction()
        }
    }
    
    func setModelContext(_ context: ModelContext, caller: String = #function, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print("🔧 [WalletManager] 📞 setModelContext() CALLED")
        print("   ├─ From: \(fileName):\(line)")
        print("   └─ Function: \(caller)")
        
        self.modelContext = context
        transactionService?.setModelContext(context)
        balanceService?.setModelContext(context)
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
        
        await taskManager.execute(key: "refresh") {
            await self.performRefresh()
        }
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
        
        isRefreshing = true
        defer { 
            isRefreshing = false
            hasLoadedOnce = true
        }
        
        guard wallet != nil else { 
            error = "Wallet not initialized"
            return 
        }
        
        // Coordinate service refreshes in parallel where possible
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
            
            // Transaction refresh
            group.addTask { 
                await self.transactionService?.refreshTransactions() 
            }
        }
        
        // Check for errors from services
        if let addressError = addressService?.error {
            self.error = addressError
            return
        }
        
        if let transactionError = transactionService?.error {
            self.error = transactionError
            return
        }
        
        if let balanceError = balanceService?.error {
            self.error = balanceError
            return
        }
        
        error = nil
        print("✅ All wallet data refreshed successfully on \(currentNetworkName)")
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
    func exitVTXO(vtxoId: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.exitVTXO(vtxoId: vtxoId)
    }
    
    func getVTXOs() async throws -> [VTXOModel] {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.getVTXOs()
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
    
    /// Refresh VTXOs by calling the wallet's refresh command
    func refreshVTXOs() async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.refreshVTXOs()
    }
    
    func refreshVTXO(vtxo_id: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.refreshVTXO(vtxo_id: vtxo_id)
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
            let result = try await wallet.deleteWallet()
            
            // Note: Mnemonic deletion is now handled by the caller (DeleteWalletSettingView)
            // This allows for intelligent deletion strategies based on device registry
            
            // Reset all manager state after successful deletion
            await self.resetManagerState()
            
            print("✅ Wallet deleted and manager state reset")
            return result
        }
    }
    
    /// Reset all manager and service state after wallet deletion
    private func resetManagerState() async {
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
    
    /// Claim a Lightning invoice
    func claimLightningInvoice(invoice: String) async throws -> String {
        guard let walletOperationsService = walletOperationsService else {
            throw BarkErrorArke.commandFailed("Wallet operations service not initialized")
        }
        return try await walletOperationsService.claimLightningInvoice(invoice: invoice)
    }
    
    // MARK: - Convenience Methods for Individual Refreshes (delegates to BalanceService)
    
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
                        trustedSpendableSat: model.trustedSpendableSat,
                        immatureSat: model.immatureSat,
                        trustedPendingSat: model.trustedPendingSat,
                        untrustedPendingSat: model.untrustedPendingSat,
                        confirmedSat: model.confirmedSat
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

