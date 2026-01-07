//
//  BarkWalletFFI.swift
//  Ark wallet prototype
//
//  FFI-based implementation of BarkWalletProtocol using Rust library
//
//  IMPLEMENTATION STATUS:
//  ✅ Implemented: Most core wallet operations are fully functional
//  ✅ NEW: Unilateral exit system fully implemented (10+ methods)
//  ✅ NEW: Advanced VTXO operations (allVtxos, spendableVtxos, getExpiringVtxos, etc.)
//  ✅ NEW: Maintenance operations (maintenanceRefresh, maybeScheduleMaintenanceRefresh)
//  ✅ NEW: Server connection refresh (refreshServer)
//  ✅ NEW: Round management (cancel, progress, pending states)
//  ✅ NEW: Enhanced Lightning operations (BOLT12 offers, payment status checks)
//  ✅ NEW: Board syncing (syncPendingBoards)
//
//  ⚠️ Requires OnchainWallet instance (not in protocol):
//     - getOnchainBalance() - Requires separate OnchainWallet
//     - board(amount:) - Use boardAll() or boardAmount() with OnchainWallet
//     - boardAll() - Use wallet.boardAll(onchainWallet:)
//
//  ⚠️ Cannot implement (not in FFI):
//     - getUTXOs() - UTXOs managed internally by wallet
//     - sendOnchain(to:amount:) - Use sendToOnchain (offboarding) instead
//
//  🆕 Methods now available in FFI and fully implemented:
//     Exit System:
//     - startExit() / startExitForVTXOs() - Start unilateral exits
//     - progressExits() - Advance exit state machine
//     - syncExits() - Sync exit state
//     - drainExits() - Claim exited funds
//     - listClaimableExits() - Get claimable exits
//     - getExitVtxos() - Get VTXOs in exit process
//     - hasPendingExits() - Check for pending exits
//     - pendingExitsTotalSats() - Get pending exit amounts
//     - getExitStatus() - Detailed exit status
//     - allExitsClaimableAtHeight() - Get claimable height
//
//     VTXO Operations:
//     - allVtxos() - Get all VTXOs including spent
//     - spendableVtxos() - Get only spendable VTXOs
//     - getExpiringVtxos(thresholdBlocks:) - Get VTXOs expiring soon
//     - getVtxosToRefresh() - Get VTXOs needing refresh
//     - getVtxoById(vtxoId:) - Get specific VTXO by ID
//     - getFirstExpiringVtxoBlockheight() - Get first expiry height
//     - getNextRequiredRefreshBlockheight() - Get next refresh height
//
//     Maintenance:
//     - maintenanceRefresh() - Perform maintenance refresh (returns round ID)
//     - maybeScheduleMaintenanceRefresh() - Schedule if needed
//     - maintenanceWithOnchain() - Full maintenance with onchain sync
//
//     Server & Rounds:
//     - refreshServer() - Refresh server connection
//     - cancelAllPendingRounds() - Cancel all pending rounds
//     - cancelPendingRound(roundId:) - Cancel specific round
//     - pendingRoundStates() - Get pending round states
//     - progressPendingRounds() - Progress pending rounds
//     - syncPendingBoards() - Sync pending board transactions
//
//     Lightning:
//     - payLightningOffer(offer:amountSats:) - Pay BOLT12 offer
//     - checkLightningPayment(paymentHash:wait:) - Check payment status
//     - lightningReceiveStatus(paymentHash:) - Get receive status
//     - tryClaimLightningReceive(paymentHash:wait:) - Claim specific receive
//     - claimableLightningReceiveBalanceSats() - Get claimable balance
//
//     Other:
//     - exitVTXO(vtxo_id:to:) - Exit specific VTXO to address
//     - newAddressWithIndex() - Generate address with derivation index
//     - peakAddress(index:) - Peek at address at specific index
//     - payLightningAddress(lightningAddress:amountSats:comment:) - Pay to Lightning address
//

import Foundation
import BIP39
import Network
import Bark

/// FFI-based implementation of BarkWalletProtocol using the Rust bark library
/// This provides better performance and type safety compared to the CLI-based approach
class BarkWalletFFI: BarkWalletProtocol {
    
    // MARK: - Properties
    
    /// The underlying FFI wallet object (nil until wallet is created/opened)
    private var wallet: Wallet?
    
    /// The onchain wallet (managed internally, created alongside main wallet)
    private var onchainWallet: OnchainWallet?
    
    /// FFI configuration object
    private let config: Config
    
    /// Network configuration (our app's model)
    let networkConfig: NetworkConfig
    
    /// Wallet directory URL
    let walletDir: URL
    
    /// Data directory path string (for FFI calls)
    private let datadir: String
    
    /// Cached mnemonic (stored securely in production)
    private var cachedMnemonic: String?
    
    /// Whether this is a preview/mock instance
    private let isPreview: Bool
    
    /// Security service for secure mnemonic storage and biometric authentication
    private let securityService: SecurityService?
    
    // MARK: - Initialization
    
    init?(networkConfig: NetworkConfig = .signet, securityService: SecurityService? = nil) {
        self.networkConfig = networkConfig
        self.isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        self.securityService = securityService
        
        // Set up wallet directory
        self.walletDir = Self.getWalletDirectory()
        self.datadir = walletDir.path
        
        // Convert NetworkConfig to FFI Config
        guard let ffiNetwork = Self.convertToFFINetwork(networkConfig.networkType) else {
            print("❌ Invalid network type: \(networkConfig.networkType)")
            return nil
        }
        
        self.config = Config(
            serverAddress: networkConfig.aspBaseURL,
            esploraAddress: networkConfig.esploraBaseURL,
            bitcoindAddress: nil,  // Optional - not needed for basic wallet operations
            bitcoindCookiefile: nil,
            bitcoindUser: nil,
            bitcoindPass: nil,
            network: ffiNetwork,
            vtxoRefreshExpiryThreshold: nil,  // Use defaults
            vtxoExitMargin: nil,
            htlcRecvClaimDelta: nil,
            fallbackFeeRate: nil,  // Use default fee rate
            roundTxRequiredConfirmations: nil  // Use default confirmations
        )
        
        print("✅ BarkWalletFFI initialized")
        print("   Network: \(networkConfig.name)")
        print("   Wallet dir: \(walletDir.path)")
        
        // Note: Wallet opening is now explicit via openWalletIfNeeded()
        // This prevents uncoordinated background opening during init
    }
    
    // MARK: - Explicit Wallet Opening
    
    /// Attempts to establish connection to the Ark server
    /// This should be called after wallet is opened and before operations requiring server access
    /// - Returns: `true` if connection established, `false` otherwise
    @discardableResult
    func ensureServerConnection() async -> Bool {
        guard let wallet = wallet else {
            print("⚠️ [ensureServerConnection] No wallet - cannot connect")
            return false
        }
        
        print("🔌 [ensureServerConnection] Attempting to establish server connection...")
        print("   Target server: \(config.serverAddress)")
        
        // Strategy 1: Try to fetch ArkInfo (this requires server connection)
        // Note: arkInfo() returns ArkInfo? (optional), doesn't throw
        if let arkInfo = wallet.arkInfo() {
            print("✅ [ensureServerConnection] Server connection verified!")
            print("   Round interval: \(arkInfo.roundIntervalSecs)s")
            return true
        } else {
            print("❌ [ensureServerConnection] Cannot fetch ArkInfo (returns nil)")
            print("🔍 [ensureServerConnection] Investigating if wallet needs explicit connection...")
            
            // TODO: Check Rust FFI documentation for:
            // - wallet.connect()
            // - wallet.sync()
            // - wallet.refreshServerInfo()
            // Or any method that establishes connection
            
            return false
        }
    }
    
    /// Polls for server connection at regular intervals until connected or timeout
    /// - Parameters:
    ///   - intervalSeconds: How often to check (default: 1 second)
    ///   - timeoutSeconds: Maximum time to wait (default: 20 seconds)
    /// - Returns: `true` if connection established, `false` if timeout reached
    @discardableResult
    func waitForServerConnection(intervalSeconds: TimeInterval = 1.0, timeoutSeconds: TimeInterval = 20.0) async -> Bool {
        guard let wallet = wallet else {
            print("⚠️ [waitForServerConnection] No wallet - cannot connect")
            return false
        }
        
        let startTime = Date()
        var attemptCount = 0
        
        print("⏳ [waitForServerConnection] Starting connection polling...")
        print("   Check interval: \(intervalSeconds)s")
        print("   Timeout: \(timeoutSeconds)s")
        print("   Target server: \(config.serverAddress)")
        
        while Date().timeIntervalSince(startTime) < timeoutSeconds {
            attemptCount += 1
            let elapsed = Date().timeIntervalSince(startTime)
            
            print("🔍 [waitForServerConnection] Attempt #\(attemptCount) (elapsed: \(String(format: "%.1f", elapsed))s)")
            
            // Try to fetch ArkInfo to check connection
            if let arkInfo = wallet.arkInfo() {
                let totalTime = Date().timeIntervalSince(startTime)
                print("✅ [waitForServerConnection] Connection established!")
                print("   Total time: \(String(format: "%.2f", totalTime))s")
                print("   Attempts: \(attemptCount)")
                print("   Round interval: \(arkInfo.roundIntervalSecs)s")
                print("   VTXO expiry: \(arkInfo.vtxoExpiryDelta) blocks")
                return true
            }
            
            // Wait before next attempt
            print("   ⏸️ No connection yet, waiting \(intervalSeconds)s before retry...")
            try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
        }
        
        // Timeout reached
        let totalTime = Date().timeIntervalSince(startTime)
        print("❌ [waitForServerConnection] Timeout reached after \(String(format: "%.2f", totalTime))s")
        print("   Total attempts: \(attemptCount)")
        print("   Server may be unreachable or wallet needs explicit connection step")
        
        return false
    }
    
    /// Explicitly opens the wallet if one exists and hasn't been opened yet
    /// This should be called after initialization when you're ready to use the wallet
    /// - Returns: `true` if wallet was opened or already open, `false` if no wallet exists
    @discardableResult
    func openWalletIfNeeded() async -> Bool {
        // If wallet is already open, nothing to do
        if wallet != nil {
            print("ℹ️ Wallet already open")
            return true
        }
        
        // Try to open existing wallet
        await tryOpenExistingWallet()
        
        // Return whether we successfully have an open wallet
        return wallet != nil
    }
    
    /// Attempt to open an existing wallet if one exists
    private func tryOpenExistingWallet() async {
        guard !isPreview else { return }
        
        #if DEBUG
        // Skip wallet opening in debug builds if environment variable OR launch argument is set
        let skipWalletOpen = ProcessInfo.processInfo.environment["SKIP_WALLET_OPEN"] == "1" ||
                             CommandLine.arguments.contains("-skipWalletOpen")
        
        if skipWalletOpen {
            print("🚀 [DEBUG] Skipping wallet open for fast debugging")
            print("   To enable wallet opening:")
            print("   - Remove 'SKIP_WALLET_OPEN' environment variable, OR")
            print("   - Remove '-skipWalletOpen' launch argument")
            return
        }
        #endif
        
        // Check if wallet data exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: walletDir.path) else {
            print("ℹ️ No existing wallet found")
            return
        }
        
        // Try to load mnemonic
        guard let mnemonic = try? loadMnemonic() else {
            print("⚠️ Wallet directory exists but no mnemonic found")
            return
        }
        
        // DEBUG: Print mnemonic
        print("🔍 [DEBUG] Loaded mnemonic: \(mnemonic)")
        print("🔍 [DEBUG] Mnemonic word count: \(mnemonic.split(separator: " ").count)")
        
        // DIAGNOSTIC: Check if datadir exists and list contents
        // print("🔍 [DIAGNOSTIC] Checking datadir existence...")
        // print("   Path: \(datadir)")
        // 
        // var isDirectory: ObjCBool = false
        // let datadirExists = fileManager.fileExists(atPath: datadir, isDirectory: &isDirectory)
        // print("   Exists: \(datadirExists)")
        // print("   Is Directory: \(isDirectory.boolValue)")
        // 
        // if datadirExists {
        //     do {
        //         let contents = try fileManager.contentsOfDirectory(atPath: datadir)
        //         print("   Contents (\(contents.count) items):")
        //         for item in contents {
        //             let itemPath = (datadir as NSString).appendingPathComponent(item)
        //             var itemIsDir: ObjCBool = false
        //             fileManager.fileExists(atPath: itemPath, isDirectory: &itemIsDir)
        //             let itemType = itemIsDir.boolValue ? "DIR" : "FILE"
        //             
        //             // Get file size if it's a file
        //             if !itemIsDir.boolValue {
        //                 if let attrs = try? fileManager.attributesOfItem(atPath: itemPath),
        //                    let size = attrs[.size] as? Int64 {
        //                     print("     [\(itemType)] \(item) (\(size) bytes)")
        //                 } else {
        //                     print("     [\(itemType)] \(item)")
        //                 }
        //             } else {
        //                 print("     [\(itemType)] \(item)/")
        //             }
        //         }
        //     } catch {
        //         print("   ⚠️ Could not list directory contents: \(error)")
        //     }
        // } else {
        //     print("   ⚠️ Datadir does not exist!")
        // }
        
        print("🔧 Opening existing wallet...")
        print("   Config:")
        print("     Server Address: \(config.serverAddress)")
        print("     Esplora Address: \(config.esploraAddress ?? "not set")")
        print("     Network: \(config.network)")
        print("     VTXO Refresh Expiry Threshold: \(config.vtxoRefreshExpiryThreshold.map { String(describing: $0) } ?? "nil")")
        print("     VTXO Exit Margin: \(config.vtxoExitMargin.map { String(describing: $0) } ?? "nil")")
        print("     HTLC Recv Claim Delta: \(config.htlcRecvClaimDelta.map { String(describing: $0) } ?? "nil")")
        print("   Data Directory: \(datadir)")
        
        printFullConfig()
        
        setenv("RUST_LOG", "trace", 1)
        setenv("RUST_BACKTRACE", "1", 1)
        
        // DIAGNOSTIC: Check network availability
        // print("🔍 [DIAGNOSTIC] Checking network status...")
        // await checkNetworkStatus()
        
        // DIAGNOSTIC: Try a simple network request
        // print("🔍 [DIAGNOSTIC] Testing network connectivity to server...")
        // await testServerConnectivity()
        
        // iOS-specific: Add delay to allow network stack to initialize
        // #if os(iOS)
        // print("📱 iOS detected: Waiting for network initialization...")
        // let delayStart = Date()
        // try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        // let delayEnd = Date()
        // print("🔍 [DIAGNOSTIC] Delay completed after \(delayEnd.timeIntervalSince(delayStart)) seconds")
        // #endif
        
        // DIAGNOSTIC: Log before opening wallet
        // let beforeOpen = Date()
        // print("🔍 [DIAGNOSTIC] About to call Wallet.open() at \(beforeOpen)")
        // print("🔍 [DIAGNOSTIC] Time elapsed since start: \(beforeOpen.timeIntervalSince(startTime)) seconds")
        
        do {
            // Open onchain wallet first
            print("🔧 Opening onchain wallet...")
            let openedOnchainWallet = try OnchainWallet.default(
                mnemonic: mnemonic,
                config: config,
                datadir: datadir
            )
            print("✅ Onchain wallet opened")
            
            // Open Bark wallet with onchain capabilities
            let openedWallet = try Wallet.openWithOnchain(
                mnemonic: mnemonic,
                config: config,
                datadir: datadir,
                onchainWallet: openedOnchainWallet
            )
            
            self.wallet = openedWallet
            self.onchainWallet = openedOnchainWallet
            self.cachedMnemonic = mnemonic
            
            // let afterOpen = Date()
            print("✅ Existing wallet opened successfully")
            // print("🔍 [DIAGNOSTIC] Wallet.open() took \(afterOpen.timeIntervalSince(beforeOpen)) seconds")
            // print("🔍 [DIAGNOSTIC] Total time: \(afterOpen.timeIntervalSince(startTime)) seconds")
            
            // DIAGNOSTIC: Print wallet state immediately after opening
            printWalletState(openedWallet, context: "After Wallet.open()")
            
            // DIAGNOSTIC: Check server connection immediately after opening
            print("🔍 [DIAGNOSTIC] Checking server connection after wallet open...")
            let connected = await waitForServerConnection(intervalSeconds: 1.0, timeoutSeconds: 20.0)
            if connected {
                print("✅ [DIAGNOSTIC] Server connection available after open")
            } else {
                print("⚠️ [DIAGNOSTIC] No server connection after wallet open")
                print("💡 [HINT] May need explicit connection step or network delay")
            }
            
        } catch let error as BarkError {
            // let failTime = Date()
            print("⚠️ Could not open existing wallet: \(error)")
            // print("🔍 [DIAGNOSTIC] Failed after \(failTime.timeIntervalSince(beforeOpen)) seconds in Wallet.open()")
            // print("🔍 [DIAGNOSTIC] Total time: \(failTime.timeIntervalSince(startTime)) seconds")
            // print("🔍 [DIAGNOSTIC] Error details: \(error.localizedDescription)")
            // Don't fail init - user can create a new wallet
        } catch {
            // let failTime = Date()
            print("⚠️ Could not open existing wallet: \(error)")
            // print("🔍 [DIAGNOSTIC] Failed after \(failTime.timeIntervalSince(beforeOpen)) seconds in Wallet.open()")
            // print("🔍 [DIAGNOSTIC] Total time: \(failTime.timeIntervalSince(startTime)) seconds")
            // print("🔍 [DIAGNOSTIC] Error type: \(type(of: error))")
        }
    }
    
    // DIAGNOSTIC: Check network availability using Network framework
    private func checkNetworkStatus() async {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        return await withCheckedContinuation { continuation in
            // Use a class wrapper to make the resumed flag thread-safe and Sendable
            final class ResumeState: @unchecked Sendable {
                private let lock = NSLock()
                private var _resumed = false
                
                var resumed: Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    return _resumed
                }
                
                func markResumed() -> Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    if _resumed {
                        return false
                    }
                    _resumed = true
                    return true
                }
            }
            
            let state = ResumeState()
            
            monitor.pathUpdateHandler = { path in
                print("🔍 [DIAGNOSTIC] Network Status:")
                print("   - Status: \(path.status)")
                print("   - Is Expensive: \(path.isExpensive)")
                print("   - Is Constrained: \(path.isConstrained)")
                print("   - Available Interfaces: \(path.availableInterfaces.map { $0.type })")
                
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        print("   - Connection Type: WiFi")
                    } else if path.usesInterfaceType(.cellular) {
                        print("   - Connection Type: Cellular")
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        print("   - Connection Type: Wired")
                    } else {
                        print("   - Connection Type: Other")
                    }
                } else {
                    print("   - No network connection available")
                }
                
                if state.markResumed() {
                    monitor.cancel()
                    continuation.resume()
                }
            }
            
            monitor.start(queue: queue)
            
            // Timeout after 2 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if state.markResumed() {
                    monitor.cancel()
                    print("🔍 [DIAGNOSTIC] Network status check timed out")
                    continuation.resume()
                }
            }
        }
    }
    
    // DIAGNOSTIC: Test basic connectivity to the server
    private func testServerConnectivity() async {
        guard let url = URL(string: config.serverAddress) else {
            print("🔍 [DIAGNOSTIC] Invalid server URL")
            return
        }
        
        print("🔍 [DIAGNOSTIC] Testing connection to: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url, timeoutInterval: 5.0)
            request.httpMethod = "HEAD"
            
            let startTime = Date()
            let (_, response) = try await URLSession.shared.data(for: request)
            let endTime = Date()
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 [DIAGNOSTIC] Server response:")
                print("   - Status Code: \(httpResponse.statusCode)")
                print("   - Response Time: \(endTime.timeIntervalSince(startTime)) seconds")
                print("   - Headers: \(httpResponse.allHeaderFields)")
            }
        } catch {
            print("🔍 [DIAGNOSTIC] Server connectivity test failed: \(error)")
            print("   - Error type: \(type(of: error))")
            print("   - Error description: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Wallet Lifecycle
    
    func createWallet(network: String? = nil, asp: String? = nil) async throws -> String {
        // Preview mode handling
        if isPreview {
            print("⚠️ Preview mode - using mock wallet creation")
            return "Mock: Wallet created (preview mode)"
        }
        
        // Generate a new mnemonic (24 words)
        let mnemonic = try generateMnemonic()
        
        // DEBUG: Print mnemonic
        print("🔍 [DEBUG] Generated mnemonic: \(mnemonic)")
        print("🔍 [DEBUG] Mnemonic word count: \(mnemonic.split(separator: " ").count)")
        
        // Use the provided config or override with custom params
        let finalConfig: Config
        if let network = network, let asp = asp {
            guard let ffiNetwork = Self.convertToFFINetwork(network) else {
                throw BarkWalletFFIError.configurationError("Invalid network type: \(network)")
            }
            
            finalConfig = Config(
                serverAddress: asp,
                esploraAddress: networkConfig.esploraBaseURL,
                bitcoindAddress: nil,  // Optional - not needed for basic wallet operations
                bitcoindCookiefile: nil,
                bitcoindUser: nil,
                bitcoindPass: nil,
                network: ffiNetwork,
                vtxoRefreshExpiryThreshold: nil,
                vtxoExitMargin: nil,
                htlcRecvClaimDelta: nil,
                fallbackFeeRate: nil,  // Use default fee rate
                roundTxRequiredConfirmations: nil  // Use default confirmations
            )
        } else {
            finalConfig = config
        }
        
        print("🔧 Creating wallet with FFI...")
        print("   Network: \(finalConfig.network)")
        print("   ASP: \(finalConfig.serverAddress)")
        print("   Data dir: \(datadir)")
        
        // Ensure the data directory exists and is writable before attempting wallet creation
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: datadir) {
            print("⚠️ Data directory doesn't exist, creating it now...")
            do {
                #if os(macOS)
                let attributes: [FileAttributeKey: Any] = [
                    .posixPermissions: NSNumber(value: 0o755)
                ]
                try fileManager.createDirectory(
                    atPath: datadir,
                    withIntermediateDirectories: true,
                    attributes: attributes
                )
                #else
                try fileManager.createDirectory(
                    atPath: datadir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                #endif
                print("✅ Data directory created successfully")
            } catch {
                let errorMsg = "Failed to create data directory: \(error.localizedDescription)"
                print("❌ \(errorMsg)")
                throw BarkWalletFFIError.configurationError(errorMsg)
            }
        }
        
        // Verify directory is writable
        let testFile = walletDir.appendingPathComponent(".write-test-\(UUID().uuidString)")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
            print("✅ Data directory is confirmed writable")
        } catch {
            let errorMsg = "Data directory is not writable: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            throw BarkWalletFFIError.configurationError(errorMsg)
        }
        
        // Create wallet using FFI
        do {
            print("🔍 [DIAGNOSTIC] About to call Wallet.createWithOnchain()...")
            print("   forceRescan: true")
            
            // Create onchain wallet first
            print("🔧 Creating onchain wallet...")
            let newOnchainWallet = try OnchainWallet.default(
                mnemonic: mnemonic,
                config: finalConfig,
                datadir: datadir
            )
            print("✅ Onchain wallet created")
            
            // Create Bark wallet with onchain capabilities
            let newWallet = try Wallet.createWithOnchain(
                mnemonic: mnemonic,
                config: finalConfig,
                datadir: datadir,
                onchainWallet: newOnchainWallet,
                forceRescan: true
            )
            
            self.wallet = newWallet
            self.onchainWallet = newOnchainWallet
            self.cachedMnemonic = mnemonic
            
            print("✅ Wallet created successfully")
            
            // DIAGNOSTIC: Compare wallet state immediately after creation vs opening
            printWalletState(newWallet, context: "After Wallet.create()")
            
            // Try immediate arkInfo() call before waiting
            print("🔍 [DIAGNOSTIC] Immediate arkInfo() check after creation...")
            if let immediateArkInfo = newWallet.arkInfo() {
                print("✅ [SURPRISE] Server connected IMMEDIATELY after creation!")
                print("   Round interval: \(immediateArkInfo.roundIntervalSecs)s")
            } else {
                print("⚠️ [DIAGNOSTIC] No immediate server connection after creation")
            }
            
            // Try calling sync() to see if that establishes connection
            print("🔍 [DIAGNOSTIC] Attempting wallet.sync() to establish connection...")
            do {
                try newWallet.sync()
                print("✅ [DIAGNOSTIC] sync() completed successfully")
                
                // Check connection again after sync
                if let postSyncArkInfo = newWallet.arkInfo() {
                    print("✅ [DIAGNOSTIC] Server connected after sync()!")
                    print("   Round interval: \(postSyncArkInfo.roundIntervalSecs)s")
                } else {
                    print("⚠️ [DIAGNOSTIC] Still no connection even after sync()")
                }
            } catch {
                print("❌ [DIAGNOSTIC] sync() failed: \(error)")
            }
            
            // DIAGNOSTIC: Check if wallet has server connection immediately after creation
            print("🔍 [DIAGNOSTIC] Now starting connection polling...")
            let connected = await waitForServerConnection(intervalSeconds: 1.0, timeoutSeconds: 60.0)
            if connected {
                print("✅ [DIAGNOSTIC] Wallet has server connection after creation")
            } else {
                print("⚠️ [DIAGNOSTIC] Wallet created but NO server connection after 20s")
                print("💡 [HINT] Server connection may need to be established separately")
                print("   Possible reasons:")
                print("   1. Connection happens lazily on first server operation")
                print("   2. Network not ready at wallet creation time")
                print("   3. forceRescan parameter doesn't trigger connection")
                print("   4. Server connection requires explicit initialization")
                print("   5. New wallet needs additional initialization step")
                
                // Try one more thing: call maintenance to see if that helps
                print("🔍 [DIAGNOSTIC] Attempting wallet.maintenance() as last resort...")
                do {
                    try newWallet.maintenance()
                    print("✅ [DIAGNOSTIC] maintenance() completed")
                    
                    if let postMaintenanceArkInfo = newWallet.arkInfo() {
                        print("✅ [DIAGNOSTIC] Server connected after maintenance()!")
                        print("   Round interval: \(postMaintenanceArkInfo.roundIntervalSecs)s")
                    } else {
                        print("⚠️ [DIAGNOSTIC] Still no connection after maintenance()")
                    }
                } catch {
                    print("❌ [DIAGNOSTIC] maintenance() failed: \(error)")
                }
            }
            
            // NOTE: Mnemonic storage is handled by WalletManager.createWallet() to avoid duplication
            // Only importWallet() flow should call storeMnemonic() directly
            print("✅ [BarkWalletFFI] Wallet created - returning mnemonic to WalletManager for storage")
            print("   ⏭️  Skipping storeMnemonic() to prevent duplication")
            
            return mnemonic
            
        } catch let error as BarkError {
            print("❌ FFI Error creating wallet: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to create wallet: \(error.localizedDescription)")
        } catch {
            print("❌ Error creating wallet: \(error)")
            throw error
        }
    }
    
    func importWallet(network: String? = nil, asp: String? = nil, mnemonic: String) async throws -> String {
        // Preview mode handling
        if isPreview {
            print("⚠️ Preview mode - using mock wallet import")
            return "Mock: Wallet imported (preview mode)"
        }
        
        // Validate mnemonic (basic check - should be 12 or 24 words)
        let words = mnemonic.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        guard words.count == 12 || words.count == 24 else {
            throw BarkWalletFFIError.invalidMnemonic
        }
        
        // DEBUG: Print mnemonic
        print("🔍 [DEBUG] Importing with mnemonic: \(mnemonic)")
        print("🔍 [DEBUG] Mnemonic word count: \(words.count)")
        
        // Use the provided config or override with custom params
        let finalConfig: Config
        if let network = network, let asp = asp {
            guard let ffiNetwork = Self.convertToFFINetwork(network) else {
                throw BarkWalletFFIError.configurationError("Invalid network type: \(network)")
            }
            
            finalConfig = Config(
                serverAddress: asp,
                esploraAddress: networkConfig.esploraBaseURL,
                bitcoindAddress: nil,  // Optional - not needed for basic wallet operations
                bitcoindCookiefile: nil,
                bitcoindUser: nil,
                bitcoindPass: nil,
                network: ffiNetwork,
                vtxoRefreshExpiryThreshold: nil,
                vtxoExitMargin: nil,
                htlcRecvClaimDelta: nil,
                fallbackFeeRate: nil,  // Use default fee rate
                roundTxRequiredConfirmations: nil  // Use default confirmations
            )
        } else {
            finalConfig = config
        }
        
        print("🔧 Importing wallet with FFI...")
        print("   Network: \(finalConfig.network)")
        print("   ASP: \(finalConfig.serverAddress)")
        print("   Data dir: \(datadir)")
        
        // Ensure the data directory exists and is writable before attempting wallet import
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: datadir) {
            print("⚠️ Data directory doesn't exist, creating it now...")
            do {
                #if os(macOS)
                let attributes: [FileAttributeKey: Any] = [
                    .posixPermissions: NSNumber(value: 0o755)
                ]
                try fileManager.createDirectory(
                    atPath: datadir,
                    withIntermediateDirectories: true,
                    attributes: attributes
                )
                #else
                try fileManager.createDirectory(
                    atPath: datadir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                #endif
                print("✅ Data directory created successfully")
            } catch {
                let errorMsg = "Failed to create data directory: \(error.localizedDescription)"
                print("❌ \(errorMsg)")
                throw BarkWalletFFIError.configurationError(errorMsg)
            }
        }
        
        // Verify directory is writable
        let testFile = walletDir.appendingPathComponent(".write-test-\(UUID().uuidString)")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
            print("✅ Data directory is confirmed writable")
        } catch {
            let errorMsg = "Data directory is not writable: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            throw BarkWalletFFIError.configurationError(errorMsg)
        }
        
        // Create/restore wallet using FFI with provided mnemonic
        do {
            // Create onchain wallet first
            print("🔧 Creating onchain wallet for import...")
            let newOnchainWallet = try OnchainWallet.default(
                mnemonic: mnemonic,
                config: finalConfig,
                datadir: datadir
            )
            print("✅ Onchain wallet created")
            
            // Create Bark wallet with onchain capabilities
            let restoredWallet = try Wallet.createWithOnchain(
                mnemonic: mnemonic,
                config: finalConfig,
                datadir: datadir,
                onchainWallet: newOnchainWallet,
                forceRescan: true
            )
            
            self.wallet = restoredWallet
            self.onchainWallet = newOnchainWallet
            self.cachedMnemonic = mnemonic
            
            // Store mnemonic securely
            try await storeMnemonic(mnemonic)
            
            print("✅ Wallet imported successfully")
            return "Wallet imported successfully. Syncing with network..."
            
        } catch let error as BarkError {
            print("❌ FFI Error importing wallet: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to import wallet: \(error.localizedDescription)")
        } catch {
            print("❌ Error importing wallet: \(error)")
            throw error
        }
    }
    
    func deleteWallet() async throws -> String {
        // Preview mode handling
        if isPreview {
            print("⚠️ Preview mode - wallet deletion skipped")
            return "Mock: Wallet deleted (preview mode)"
        }
        
        let fileManager = FileManager.default
        
        // Safety check: verify the wallet directory path looks correct
        guard walletDir.path.contains("bark-data-ffi") else {
            throw BarkWalletFFIError.configurationError("Invalid wallet directory path: \(walletDir.path)")
        }
        
        // Clear the wallet reference first
        wallet = nil
        cachedMnemonic = nil
        
        // Delete from SecurityService (Keychain only - local deletion)
        if let securityService = securityService {
            print("🗑️ Deleting mnemonic from Keychain via SecurityService")
            do {
                try await securityService.deleteWalletData(includeCloudData: false)
                print("✅ Mnemonic deleted from Keychain")
            } catch {
                print("⚠️ Failed to delete from Keychain: \(error)")
                // Continue to delete file system data anyway
            }
        }
        
        // Check if wallet directory exists
        guard fileManager.fileExists(atPath: walletDir.path) else {
            print("⚠️ Wallet directory does not exist at: \(walletDir.path)")
            return "Wallet directory does not exist (already deleted)"
        }
        
        print("🗑️ Deleting wallet directory: \(walletDir.path)")
        
        do {
            // Remove the entire wallet directory and its contents
            try fileManager.removeItem(at: walletDir)
            print("✅ Successfully deleted wallet directory")
            return "Successfully deleted wallet directory at \(walletDir.path)"
        } catch {
            print("❌ Failed to delete wallet directory: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to delete wallet directory: \(error.localizedDescription)")
        }
    }
    
    func getMnemonic() async throws -> String {
        // Preview mode handling
        if isPreview {
            return "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        }
        
        // Return cached mnemonic if available
        if let cached = cachedMnemonic {
            return cached
        }
        
        // Try to load from storage
        do {
            let mnemonic = try loadMnemonic()
            cachedMnemonic = mnemonic
            return mnemonic
        } catch {
            print("❌ Failed to load mnemonic: \(error)")
            throw BarkWalletFFIError.walletNotInitialized
        }
    }
    
    // MARK: - Balance & Address Operations
    
    func getArkBalance() async throws -> ArkBalanceResponse {
        // Preview mode handling
        if isPreview {
            return ArkBalanceResponse(
                spendableSat: 50000,
                pendingLightningSendSat: 0,
                pendingInRoundSat: 0,
                pendingExitSat: 0,
                pendingBoardSat: 0
            )
        }
        
        // Log wallet initialization status
        print("🔍 Wallet initialized: \(wallet != nil) at \(Date())")
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Fetching balance via FFI...")
        
        do {
            // Call FFI balance method
            let ffiBalance = try wallet.balance()
            
            print("✅ Balance retrieved:")
            print("   Full FFI Balance: \(ffiBalance)")
            print("   Spendable: \(ffiBalance.spendableSats) sats")
            print("   Pending Lightning Send: \(ffiBalance.pendingLightningSendSats) sats")
            print("   Pending in round: \(ffiBalance.pendingInRoundSats) sats")
            print("   Pending exit: \(ffiBalance.pendingExitSats) sats")
            print("   Pending board: \(ffiBalance.pendingBoardSats) sats")
            
            // Convert FFI Balance to ArkBalanceResponse
            let response = ArkBalanceResponse(
                spendableSat: Int(ffiBalance.spendableSats),
                pendingLightningSendSat: Int(ffiBalance.pendingLightningSendSats),
                pendingInRoundSat: Int(ffiBalance.pendingInRoundSats),
                pendingExitSat: Int(ffiBalance.pendingExitSats),
                pendingBoardSat: Int(ffiBalance.pendingBoardSats)
            )
            
            return response
            
        } catch let error as BarkError {
            print("❌ FFI Error fetching balance: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get balance: \(error.localizedDescription)")
        } catch {
            print("❌ Error fetching balance: \(error)")
            throw error
        }
    }
    
    func getArkAddress() async throws -> String {
        // Log call stack to trace where this is being called from
        #if DEBUG
        print("🔧 [ADDRESS TRACE] getArkAddress() CALLED")
        // Note: Ark addresses can be safely reused without privacy concerns.
        // The Rust wallet manages address derivation and tracks all previously
        // generated addresses for incoming payment detection.
        print("   📞 Call stack:")
        Thread.callStackSymbols.prefix(6).enumerated().forEach { index, symbol in
            print("      \(index): \(symbol)")
        }
        #endif
        
        // Preview mode handling
        if isPreview {
            return "ark1preview0000000000000000000000000000000000000000000000000000000"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Generating new address via FFI...")
        print("🔍 [DEBUG] Current wallet state:")
        print("   - Wallet object exists: \(self.wallet != nil)")
        print("   - Config server: \(config.serverAddress)")
        print("   - Config esplora: \(config.esploraAddress ?? "nil")")
        
        // Try to get server info first to diagnose connection
        print("🔍 [DEBUG] Attempting to fetch server info before address generation...")
        if let arkInfo = wallet.arkInfo() {
            print("✅ [DEBUG] Server connected! ArkInfo available:")
            print("   - Round interval: \(arkInfo.roundIntervalSecs)s")
            print("   - VTXO expiry: \(arkInfo.vtxoExpiryDelta) blocks")
        } else {
            print("⚠️ [DEBUG] Cannot fetch ArkInfo (returns nil - server may not be connected)")
            print("🔍 [DEBUG] This explains why address generation will fail")
        }
        
        do {
            // Call FFI newAddressWithIndex method to get address with index
            let addressWithIndex = try wallet.newAddressWithIndex()
            
            print("✅ New address generated with index:")
            print("   Address: \(addressWithIndex.address)")
            print("   Index: \(addressWithIndex.index)")
            
            return addressWithIndex.address
            
        } catch let error as BarkError {
            print("❌ FFI Error generating address: \(error)")
            print("🔍 [DEBUG] BarkError details:")
            print("   - Error type: \(type(of: error))")
            print("   - Description: \(error.localizedDescription)")
            
            // Check if this is specifically a connection error
            if case .ServerConnection(let message) = error {
                print("🔍 [DEBUG] Confirmed: This is a ServerConnection error")
                print("   - Message: \(message)")
                print("💡 [HINT] The Rust wallet needs an explicit connection step")
                print("   Possible solutions:")
                print("   1. Call wallet.connect() or similar before address generation")
                print("   2. Check if forceRescan parameter establishes connection")
                print("   3. Investigate if there's a network initialization delay")
            }
            
            throw BarkWalletFFIError.configurationError("Failed to generate address: \(error.localizedDescription)")
        } catch {
            print("❌ Error generating address: \(error)")
            throw error
        }
    }
    
    func getOnchainAddress() async throws -> String {
        // Get a Bitcoin onchain address from the onchain wallet
        
        if isPreview {
            return "tb1preview00000000000000000000000000000000000000000000"
        }
        
        // Ensure onchain wallet is initialized
        guard let onchainWallet = onchainWallet else {
            throw BarkWalletFFIError.configurationError("Onchain wallet not initialized")
        }
        
        print("🔧 Generating onchain address via FFI...")
        
        do {
            // Call FFI newAddress method
            let address = try onchainWallet.newAddress()
            
            print("✅ Onchain address generated")
            print("   Address: \(address)")
            
            return address
            
        } catch let error as BarkError {
            print("❌ FFI Error generating onchain address: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to generate onchain address: \(error.localizedDescription)")
        } catch {
            print("❌ Error generating onchain address: \(error)")
            throw error
        }
    }
    
    func getOnchainBalance() async throws -> OnchainBalanceResponse {
        // Get onchain Bitcoin balance from the onchain wallet
        
        if isPreview {
            return OnchainBalanceResponse(
                totalSat: 0,
                confirmedSat: 0,
                pendingSat: 0
            )
        }
        
        // Ensure onchain wallet is initialized
        guard let onchainWallet = onchainWallet else {
            throw BarkWalletFFIError.configurationError("Onchain wallet not initialized")
        }
        
        print("🔧 Fetching onchain balance via FFI...")
        
        do {
            // Call FFI balance method on onchain wallet
            let ffiBalance = try onchainWallet.balance()
            
            print("✅ Onchain balance retrieved:")
            print("   Total: \(ffiBalance.totalSats) sats")
            print("   Confirmed: \(ffiBalance.confirmedSats) sats")
            print("   Pending: \(ffiBalance.pendingSats) sats")
            
            // Convert FFI OnchainBalance to OnchainBalanceResponse (direct 1:1 mapping)
            let response = OnchainBalanceResponse(
                totalSat: Int(ffiBalance.totalSats),
                confirmedSat: Int(ffiBalance.confirmedSats),
                pendingSat: Int(ffiBalance.pendingSats)
            )
            
            return response
            
        } catch let error as BarkError {
            print("❌ FFI Error fetching onchain balance: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get onchain balance: \(error.localizedDescription)")
        } catch {
            print("❌ Error fetching onchain balance: \(error)")
            throw error
        }
    }
    
    // MARK: - VTXO & UTXO Operations
    
    func getVTXOs() async throws -> [VTXOModel] {
        // Preview mode handling
        if isPreview {
            return VTXOModel.mockVTXOs()
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Fetching VTXOs via FFI...")
        
        do {
            // Call FFI vtxos method
            let ffiVtxos = try wallet.vtxos()
            
            print("✅ Retrieved \(ffiVtxos.count) VTXOs")
            
            // Convert FFI Vtxo array to VTXOModel array
            let vtxoModels = ffiVtxos.map { ffiVtxo -> VTXOModel in
                // Map FFI state string to our VTXOState enum
                let state = mapFFIStateToVTXOState(ffiVtxo.state)
                
                // Map FFI kind to our PolicyType (this is a best guess mapping)
                let policyType = mapFFIKindToPolicyType(ffiVtxo.kind)
                
                // FFI Vtxo doesn't have all the fields that VTXOModel has
                // We'll use what's available and provide sensible defaults
                return VTXOModel(
                    id: ffiVtxo.id,
                    amountSat: Int(ffiVtxo.amountSats),
                    policyType: policyType,
                    userPubkey: "", // Not available in FFI Vtxo
                    serverPubkey: "", // Not available in FFI Vtxo
                    expiryHeight: Int(ffiVtxo.expiryHeight),
                    exitDelta: 0, // Not available in FFI Vtxo
                    chainAnchor: "", // Not available in FFI Vtxo
                    exitDepth: 0, // Not available in FFI Vtxo
                    arkoorDepth: 0, // Not available in FFI Vtxo
                    state: state
                )
            }
            
            // Log summary
            for (index, vtxo) in vtxoModels.enumerated() {
                print("   VTXO \(index): \(vtxo.shortId), \(vtxo.amountSat) sats, \(vtxo.state.rawValue)")
            }
            
            return vtxoModels
            
        } catch let error as BarkError {
            print("❌ FFI Error fetching VTXOs: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get VTXOs: \(error.localizedDescription)")
        } catch {
            print("❌ Error fetching VTXOs: \(error)")
            throw error
        }
    }
    
    func getUTXOs() async throws -> [UTXOModel] {
        // Note: FFI layer doesn't expose UTXOs separately
        // This functionality may not be available in the Rust wallet API
        
        if isPreview {
            return []
        }
        
        print("⚠️ getUTXOs: Not available in FFI layer")
        print("   FFI wallet manages UTXOs internally")
        
        // Return empty array
        return []
    }
    
    func refreshVTXOs() async throws -> String {
        // Refresh all VTXOs using maintenance
        
        if isPreview {
            return "Mock: Refreshed all VTXOs (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Running maintenance to refresh VTXOs via FFI...")
        
        do {
            // Call FFI maintenance method
            // This handles VTXO refresh and other maintenance tasks
            try wallet.maintenance()
            
            print("✅ Maintenance completed successfully")
            print("   VTXOs have been refreshed")
            
            return "Successfully refreshed VTXOs via maintenance"
            
        } catch let error as BarkError {
            print("❌ FFI Error during maintenance: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to refresh VTXOs: \(error.localizedDescription)")
        } catch {
            print("❌ Error during maintenance: \(error)")
            throw error
        }
    }
    
    func refreshVTXO(vtxo_id: String) async throws -> String {
        // Refresh a specific VTXO
        
        if isPreview {
            return "Mock: Refreshed VTXO \(vtxo_id) (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Refreshing specific VTXO via FFI...")
        print("   VTXO ID: \(vtxo_id)")
        
        do {
            // Call FFI refreshVtxos with single VTXO ID
            let roundId = try wallet.refreshVtxos(vtxoIds: [vtxo_id])
            
            if let roundId = roundId {
                print("✅ VTXO refresh initiated")
                print("   Round ID: \(roundId)")
                return "VTXO refresh initiated. Round ID: \(roundId)"
            } else {
                print("✅ VTXO does not need refresh")
                return "VTXO does not need refresh at this time"
            }
            
        } catch let error as BarkError {
            print("❌ FFI Error refreshing VTXO: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to refresh VTXO: \(error.localizedDescription)")
        } catch {
            print("❌ Error refreshing VTXO: \(error)")
            throw error
        }
    }
    
    func exitVTXO(vtxo_id: String, to address: String) async throws -> String {
        // Exit (offboard) a specific VTXO to a Bitcoin address
        
        if isPreview {
            return "Mock: Exited VTXO \(vtxo_id) to \(address) (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Offboarding specific VTXO via FFI...")
        print("   VTXO ID: \(vtxo_id)")
        print("   Destination: \(address)")
        
        do {
            // Call FFI offboardVtxos with single VTXO ID
            let roundId = try wallet.offboardVtxos(vtxoIds: [vtxo_id], bitcoinAddress: address)
            
            print("✅ VTXO offboard initiated")
            print("   Round ID: \(roundId)")
            
            return "VTXO offboard initiated. Round ID: \(roundId)"
            
        } catch let error as BarkError {
            print("❌ FFI Error offboarding VTXO: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to offboard VTXO: \(error.localizedDescription)")
        } catch {
            print("❌ Error offboarding VTXO: \(error)")
            throw error
        }
    }
    
    // Legacy version without address parameter (for compatibility)
    func exitVTXO(vtxo_id: String) async throws -> String {
        print("⚠️ exitVTXO: Requires Bitcoin address for offboarding")
        print("   Use exitVTXO(vtxo_id:to:) with a destination address")
        
        throw BarkWalletFFIError.notSupported("exitVTXO requires a Bitcoin address. Use exitVTXO(vtxo_id:to:address) instead.")
    }
    
    func startExit() async throws -> String {
        // Start unilateral exit process for entire wallet
        
        if isPreview {
            return "Mock: Started exit process (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Starting unilateral exit for entire wallet via FFI...")
        
        do {
            // Call FFI startExitForEntireWallet method
            try wallet.startExitForEntireWallet()
            
            print("✅ Unilateral exit started for entire wallet")
            print("   ⚠️  NOTE: Call progressExits() periodically to advance the exit process")
            print("   Exit requires an OnchainWallet to broadcast transactions")
            
            return "Unilateral exit started for entire wallet. Call progressExits() to advance the process."
            
        } catch let error as BarkError {
            print("❌ FFI Error starting exit: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to start exit: \(error.localizedDescription)")
        } catch {
            print("❌ Error starting exit: \(error)")
            throw error
        }
    }
    
    // Additional method to start exit for specific VTXOs
    func startExitForVTXOs(vtxo_ids: [String]) async throws -> String {
        // Start unilateral exit for specific VTXOs
        
        if isPreview {
            return "Mock: Started exit for \(vtxo_ids.count) VTXOs (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Starting unilateral exit for specific VTXOs via FFI...")
        print("   VTXO count: \(vtxo_ids.count)")
        
        do {
            // Call FFI startExitForVtxos method
            try wallet.startExitForVtxos(vtxoIds: vtxo_ids)
            
            print("✅ Unilateral exit started for \(vtxo_ids.count) VTXOs")
            print("   ⚠️  NOTE: Call progressExits() periodically to advance the exit process")
            
            return "Unilateral exit started for \(vtxo_ids.count) VTXOs. Call progressExits() to advance."
            
        } catch let error as BarkError {
            print("❌ FFI Error starting exit: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to start exit: \(error.localizedDescription)")
        } catch {
            print("❌ Error starting exit: \(error)")
            throw error
        }
    }
    
    func sync() async throws {
        // Synchronize wallet state with the ASP server
        
        if isPreview {
            print("ℹ️ Mock: Synced wallet (preview mode)")
            return
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔄 Syncing wallet with ASP server...")
        
        do {
            // Call FFI sync method
            try wallet.sync()
            
            print("✅ Wallet synced successfully")
            
        } catch let error as BarkError {
            print("❌ FFI Error syncing wallet: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to sync wallet: \(error.localizedDescription)")
        } catch {
            print("❌ Error syncing wallet: \(error)")
            throw error
        }
    }
    
    // MARK: - Advanced Exit Operations (New in FFI)
    
    func progressExits(feeRateSatPerVb: UInt64?) async throws -> [ExitProgressStatus] {
        // Progress unilateral exits (broadcast, fee bump, advance state machine)
        
        if isPreview {
            return []
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        guard let onchainWallet = onchainWallet else {
            throw BarkWalletFFIError.configurationError("Onchain wallet not initialized")
        }
        
        print("🔧 Progressing exits via FFI...")
        
        do {
            let statuses = try wallet.progressExits(onchainWallet: onchainWallet, feeRateSatPerVb: feeRateSatPerVb)
            
            print("✅ Progressed \(statuses.count) exits")
            for status in statuses {
                print("   VTXO \(status.vtxoId): \(status.state)")
                if let error = status.error {
                    print("     Error: \(error)")
                }
            }
            
            return statuses
            
        } catch let error as BarkError {
            print("❌ FFI Error progressing exits: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to progress exits: \(error.localizedDescription)")
        } catch {
            print("❌ Error progressing exits: \(error)")
            throw error
        }
    }
    
    func syncExits() async throws {
        // Sync exit state (checks status but doesn't progress)
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        guard let onchainWallet = onchainWallet else {
            throw BarkWalletFFIError.configurationError("Onchain wallet not initialized")
        }
        
        print("🔧 Syncing exits via FFI...")
        
        do {
            try wallet.syncExits(onchainWallet: onchainWallet)
            print("✅ Exits synced")
        } catch let error as BarkError {
            print("❌ FFI Error syncing exits: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to sync exits: \(error.localizedDescription)")
        } catch {
            print("❌ Error syncing exits: \(error)")
            throw error
        }
    }
    
    func drainExits(vtxoIds: [String], address: String, feeRateSatPerVb: UInt64?) async throws -> ExitClaimTransaction {
        // Drain claimable exits to an address
        
        if isPreview {
            return ExitClaimTransaction(psbtBase64: "mock_psbt", feeSats: 1000)
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Draining exits via FFI...")
        print("   VTXO count: \(vtxoIds.isEmpty ? "all" : "\(vtxoIds.count)")")
        print("   Destination: \(address)")
        
        do {
            let claimTx = try wallet.drainExits(vtxoIds: vtxoIds, address: address, feeRateSatPerVb: feeRateSatPerVb)
            
            print("✅ Exit claim transaction created")
            print("   Fee: \(claimTx.feeSats) sats")
            
            return claimTx
            
        } catch let error as BarkError {
            print("❌ FFI Error draining exits: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to drain exits: \(error.localizedDescription)")
        } catch {
            print("❌ Error draining exits: \(error)")
            throw error
        }
    }
    
    func listClaimableExits() async throws -> [ExitVtxo] {
        // List all exits that are claimable
        
        if isPreview {
            return []
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            let exits = try wallet.listClaimableExits()
            print("✅ Retrieved \(exits.count) claimable exits")
            return exits
        } catch let error as BarkError {
            print("❌ FFI Error listing claimable exits: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to list claimable exits: \(error.localizedDescription)")
        } catch {
            print("❌ Error listing claimable exits: \(error)")
            throw error
        }
    }
    
    func getExitVtxos() async throws -> [ExitVtxo] {
        // Get all VTXOs currently in exit process
        
        if isPreview {
            return []
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            let exits = try wallet.getExitVtxos()
            print("✅ Retrieved \(exits.count) VTXOs in exit process")
            return exits
        } catch let error as BarkError {
            print("❌ FFI Error getting exit VTXOs: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get exit VTXOs: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting exit VTXOs: \(error)")
            throw error
        }
    }
    
    func hasPendingExits() async throws -> Bool {
        // Check if any exits are pending
        
        if isPreview {
            return false
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.hasPendingExits()
        } catch let error as BarkError {
            print("❌ FFI Error checking pending exits: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to check pending exits: \(error.localizedDescription)")
        } catch {
            print("❌ Error checking pending exits: \(error)")
            throw error
        }
    }
    
    func pendingExitsTotalSats() async throws -> UInt64 {
        // Get total amount in pending exits (sats)
        
        if isPreview {
            return 0
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.pendingExitsTotalSats()
        } catch let error as BarkError {
            print("❌ FFI Error getting pending exits total: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get pending exits total: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting pending exits total: \(error)")
            throw error
        }
    }
    
    func getExitStatus(vtxoId: String, includeHistory: Bool, includeTransactions: Bool) async throws -> ExitTransactionStatus? {
        // Get detailed exit status for a specific VTXO
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.getExitStatus(vtxoId: vtxoId, includeHistory: includeHistory, includeTransactions: includeTransactions)
        } catch let error as BarkError {
            print("❌ FFI Error getting exit status: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get exit status: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting exit status: \(error)")
            throw error
        }
    }
    
    func allExitsClaimableAtHeight() async throws -> UInt32? {
        // Get earliest block height when all exits will be claimable
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.allExitsClaimableAtHeight()
        } catch let error as BarkError {
            print("❌ FFI Error getting claimable height: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get claimable height: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting claimable height: \(error)")
            throw error
        }
    }
    
    // MARK: - Advanced VTXO Operations (New in FFI)
    
    func allVtxos() async throws -> [Vtxo] {
        // Get all VTXOs (including spent)
        
        if isPreview {
            return []
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            let vtxos = try wallet.allVtxos()
            print("✅ Retrieved \(vtxos.count) VTXOs (all)")
            return vtxos
        } catch let error as BarkError {
            print("❌ FFI Error getting all VTXOs: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get all VTXOs: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting all VTXOs: \(error)")
            throw error
        }
    }
    
    func spendableVtxos() async throws -> [Vtxo] {
        // Get only spendable VTXOs
        
        if isPreview {
            return []
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            let vtxos = try wallet.spendableVtxos()
            print("✅ Retrieved \(vtxos.count) spendable VTXOs")
            return vtxos
        } catch let error as BarkError {
            print("❌ FFI Error getting spendable VTXOs: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get spendable VTXOs: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting spendable VTXOs: \(error)")
            throw error
        }
    }
    
    func getExpiringVtxos(thresholdBlocks: UInt32) async throws -> [Vtxo] {
        // Get VTXOs expiring within threshold blocks
        
        if isPreview {
            return []
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            let vtxos = try wallet.getExpiringVtxos(thresholdBlocks: thresholdBlocks)
            print("✅ Retrieved \(vtxos.count) expiring VTXOs (within \(thresholdBlocks) blocks)")
            return vtxos
        } catch let error as BarkError {
            print("❌ FFI Error getting expiring VTXOs: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get expiring VTXOs: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting expiring VTXOs: \(error)")
            throw error
        }
    }
    
    func getVtxosToRefresh() async throws -> [Vtxo] {
        // Get VTXOs that should be refreshed
        
        if isPreview {
            return []
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            let vtxos = try wallet.getVtxosToRefresh()
            print("✅ Retrieved \(vtxos.count) VTXOs needing refresh")
            return vtxos
        } catch let error as BarkError {
            print("❌ FFI Error getting VTXOs to refresh: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get VTXOs to refresh: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting VTXOs to refresh: \(error)")
            throw error
        }
    }
    
    func getVtxoById(vtxoId: String) async throws -> Vtxo {
        // Get a specific VTXO by ID
        
        if isPreview {
            return Vtxo(id: vtxoId, amountSats: 10000, expiryHeight: 0, kind: "mock", state: "spendable")
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.getVtxoById(vtxoId: vtxoId)
        } catch let error as BarkError {
            print("❌ FFI Error getting VTXO by ID: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get VTXO by ID: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting VTXO by ID: \(error)")
            throw error
        }
    }
    
    func getFirstExpiringVtxoBlockheight() async throws -> UInt32? {
        // Get the block height of the first expiring VTXO
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.getFirstExpiringVtxoBlockheight()
        } catch let error as BarkError {
            print("❌ FFI Error getting first expiring VTXO height: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get first expiring VTXO height: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting first expiring VTXO height: \(error)")
            throw error
        }
    }
    
    func getNextRequiredRefreshBlockheight() async throws -> UInt32? {
        // Get the next block height when a refresh should be performed
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.getNextRequiredRefreshBlockheight()
        } catch let error as BarkError {
            print("❌ FFI Error getting next refresh height: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get next refresh height: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting next refresh height: \(error)")
            throw error
        }
    }
    
    // MARK: - Maintenance Operations (New in FFI)
    
    func maintenanceRefresh() async throws -> String? {
        // Perform maintenance refresh
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Performing maintenance refresh via FFI...")
        
        do {
            let roundId = try wallet.maintenanceRefresh()
            
            if let roundId = roundId {
                print("✅ Maintenance refresh initiated. Round ID: \(roundId)")
            } else {
                print("✅ Maintenance refresh completed (no refresh needed)")
            }
            
            return roundId
        } catch let error as BarkError {
            print("❌ FFI Error during maintenance refresh: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to perform maintenance refresh: \(error.localizedDescription)")
        } catch {
            print("❌ Error during maintenance refresh: \(error)")
            throw error
        }
    }
    
    func maybeScheduleMaintenanceRefresh() async throws -> UInt32? {
        // Schedule a maintenance refresh if VTXOs need refreshing
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.maybeScheduleMaintenanceRefresh()
        } catch let error as BarkError {
            print("❌ FFI Error scheduling maintenance refresh: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to schedule maintenance refresh: \(error.localizedDescription)")
        } catch {
            print("❌ Error scheduling maintenance refresh: \(error)")
            throw error
        }
    }
    
    func maintenanceWithOnchain() async throws {
        // Full maintenance including onchain wallet sync
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        guard let onchainWallet = onchainWallet else {
            throw BarkWalletFFIError.configurationError("Onchain wallet not initialized")
        }
        
        print("🔧 Performing full maintenance with onchain sync via FFI...")
        
        do {
            try wallet.maintenanceWithOnchain(onchainWallet: onchainWallet)
            print("✅ Full maintenance completed")
        } catch let error as BarkError {
            print("❌ FFI Error during full maintenance: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to perform full maintenance: \(error.localizedDescription)")
        } catch {
            print("❌ Error during full maintenance: \(error)")
            throw error
        }
    }
    
    // MARK: - Server Connection (New in FFI)
    
    func refreshServer() async throws {
        // Refresh the Ark server connection
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Refreshing server connection via FFI...")
        
        do {
            try wallet.refreshServer()
            print("✅ Server connection refreshed")
        } catch let error as BarkError {
            print("❌ FFI Error refreshing server: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to refresh server: \(error.localizedDescription)")
        } catch {
            print("❌ Error refreshing server: \(error)")
            throw error
        }
    }
    
    // MARK: - Round Management (New in FFI)
    
    func cancelAllPendingRounds() async throws {
        // Cancel all pending rounds
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Canceling all pending rounds via FFI...")
        
        do {
            try wallet.cancelAllPendingRounds()
            print("✅ All pending rounds canceled")
        } catch let error as BarkError {
            print("❌ FFI Error canceling pending rounds: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to cancel pending rounds: \(error.localizedDescription)")
        } catch {
            print("❌ Error canceling pending rounds: \(error)")
            throw error
        }
    }
    
    func cancelPendingRound(roundId: UInt32) async throws {
        // Cancel a specific pending round
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Canceling pending round \(roundId) via FFI...")
        
        do {
            try wallet.cancelPendingRound(roundId: roundId)
            print("✅ Round \(roundId) canceled")
        } catch let error as BarkError {
            print("❌ FFI Error canceling round: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to cancel round: \(error.localizedDescription)")
        } catch {
            print("❌ Error canceling round: \(error)")
            throw error
        }
    }
    
    func pendingRoundStates() async throws -> [RoundState] {
        // Get all pending round states
        
        if isPreview {
            return []
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            let states = try wallet.pendingRoundStates()
            print("✅ Retrieved \(states.count) pending round states")
            return states
        } catch let error as BarkError {
            print("❌ FFI Error getting pending round states: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get pending round states: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting pending round states: \(error)")
            throw error
        }
    }
    
    func progressPendingRounds() async throws {
        // Progress pending rounds
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Progressing pending rounds via FFI...")
        
        do {
            try wallet.progressPendingRounds()
            print("✅ Pending rounds progressed")
        } catch let error as BarkError {
            print("❌ FFI Error progressing pending rounds: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to progress pending rounds: \(error.localizedDescription)")
        } catch {
            print("❌ Error progressing pending rounds: \(error)")
            throw error
        }
    }
    
    func syncPendingBoards() async throws {
        // Sync pending board transactions
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Syncing pending boards via FFI...")
        
        do {
            try wallet.syncPendingBoards()
            print("✅ Pending boards synced")
        } catch let error as BarkError {
            print("❌ FFI Error syncing pending boards: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to sync pending boards: \(error.localizedDescription)")
        } catch {
            print("❌ Error syncing pending boards: \(error)")
            throw error
        }
    }
    
    // MARK: - Enhanced Lightning Operations (New in FFI)
    
    func payLightningOffer(offer: String, amountSats: UInt64?) async throws -> LightningSend {
        // Pay a BOLT12 lightning offer
        
        if isPreview {
            return LightningSend(invoice: "lnbc...", amountSats: amountSats ?? 0, htlcVtxoCount: 1, preimage: nil)
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        guard amountSats ?? 0 > 0 else {
            throw BarkWalletFFIError.configurationError("Amount must be greater than 0 for BOLT12 offers")
        }
        
        print("🔧 Paying Lightning BOLT12 offer via FFI...")
        print("   Offer: \(String(offer.prefix(30)))...")
        if let amt = amountSats {
            print("   Amount: \(amt) sats")
        }
        
        do {
            let result = try wallet.payLightningOffer(offer: offer, amountSats: amountSats)
            
            print("✅ Lightning BOLT12 payment initiated")
            print("   Invoice: \(String(result.invoice.prefix(30)))...")
            print("   Amount: \(result.amountSats) sats")
            print("   HTLC VTXOs: \(result.htlcVtxoCount)")
            
            return result
            
        } catch let error as BarkError {
            print("❌ FFI Error paying Lightning offer: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to pay Lightning offer: \(error.localizedDescription)")
        } catch {
            print("❌ Error paying Lightning offer: \(error)")
            throw error
        }
    }
    
    func checkLightningPayment(paymentHash: String, wait: Bool) async throws -> String? {
        // Check lightning payment status by payment hash
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.checkLightningPayment(paymentHash: paymentHash, wait: wait)
        } catch let error as BarkError {
            print("❌ FFI Error checking lightning payment: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to check lightning payment: \(error.localizedDescription)")
        } catch {
            print("❌ Error checking lightning payment: \(error)")
            throw error
        }
    }
    
    func lightningReceiveStatus(paymentHash: String) async throws -> LightningReceive? {
        // Get lightning receive status by payment hash
        
        if isPreview {
            return nil
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.lightningReceiveStatus(paymentHash: paymentHash)
        } catch let error as BarkError {
            print("❌ FFI Error getting lightning receive status: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get lightning receive status: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting lightning receive status: \(error)")
            throw error
        }
    }
    
    func tryClaimLightningReceive(paymentHash: String, wait: Bool) async throws {
        // Try to claim a specific lightning receive by payment hash
        
        if isPreview {
            return
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Claiming specific Lightning receive via FFI...")
        print("   Payment hash: \(String(paymentHash.prefix(16)))...")
        
        do {
            try wallet.tryClaimLightningReceive(paymentHash: paymentHash, wait: wait)
            print("✅ Lightning receive claimed")
        } catch let error as BarkError {
            print("❌ FFI Error claiming lightning receive: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to claim lightning receive: \(error.localizedDescription)")
        } catch {
            print("❌ Error claiming lightning receive: \(error)")
            throw error
        }
    }
    
    func claimableLightningReceiveBalanceSats() async throws -> UInt64 {
        // Get claimable lightning receive balance
        
        if isPreview {
            return 0
        }
        
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        do {
            return try wallet.claimableLightningReceiveBalanceSats()
        } catch let error as BarkError {
            print("❌ FFI Error getting claimable lightning receive balance: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get claimable lightning receive balance: \(error.localizedDescription)")
        } catch {
            print("❌ Error getting claimable lightning receive balance: \(error)")
            throw error
        }
    }
    
    // MARK: - Send Operations
    
    func send(to address: String, amount: Int) async throws -> String {
        // Preview mode handling
        if isPreview {
            return "Mock: Sent \(amount) sats to \(address) (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        // Validate amount
        guard amount > 0 else {
            throw BarkWalletFFIError.configurationError("Amount must be greater than 0")
        }
        
        // Convert Int to UInt64 for FFI
        let amountSats = UInt64(amount)
        
        print("🔧 Sending \(amount) sats to \(address) via FFI...")
        print("   Network: \(networkConfig.name)")
        
        do {
            // Call FFI sendArkoorPayment method
            let roundId = try wallet.sendArkoorPayment(arkAddress: address, amountSats: amountSats)
            
            print("✅ Payment sent successfully")
            print("   Round ID: \(roundId)")
            print("   Amount: \(amount) sats")
            print("   To: \(address)")
            
            // Return success message with round ID
            return "Successfully sent \(amount) sats to \(address). Round ID: \(roundId)"
            
        } catch let error as BarkError {
            print("❌ FFI Error sending payment: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to send payment: \(error.localizedDescription)")
        } catch {
            print("❌ Error sending payment: \(error)")
            throw error
        }
    }
    
    func sendToOnchain(to address: String, amount: Int) async throws -> String {
        // This is an "offboard" operation in Ark terminology
        // It sends Ark funds to a Bitcoin onchain address
        
        if isPreview {
            return "Mock: Sent \(amount) sats to onchain address \(address) (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        // Validate amount
        guard amount > 0 else {
            throw BarkWalletFFIError.configurationError("Amount must be greater than 0")
        }
        
        print("🔧 Offboarding \(amount) sats to onchain address via FFI...")
        print("   Network: \(networkConfig.name)")
        print("   Destination: \(address)")
        print("   Amount: \(amount) sats")
        
        // Convert Int to UInt64 for FFI
        let amountSats = UInt64(amount)
        
        do {
            // Call FFI sendRoundOnchainPayment method
            // This sends a specific amount during a round (better than offboarding all)
            let roundId = try wallet.sendRoundOnchainPayment(address: address, amountSats: amountSats)
            
            print("✅ Onchain payment initiated")
            print("   Round ID: \(roundId)")
            print("   Destination: \(address)")
            print("   Amount: \(amount) sats")
            
            // Return result with round ID
            return "Onchain payment initiated. Round ID: \(roundId)"
            
        } catch let error as BarkError {
            print("❌ FFI Error sending onchain payment: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to send onchain payment: \(error.localizedDescription)")
        } catch {
            print("❌ Error sending onchain payment: \(error)")
            throw error
        }
    }
    
    func sendOnchain(to address: String, amount: Int) async throws -> String {
        // This is a direct onchain transaction (not offboarding Ark funds)
        // The FFI layer doesn't have a separate method for this
        // It would require onchain Bitcoin to send
        
        if isPreview {
            return "Mock: Sent \(amount) sats onchain to \(address) (preview mode)"
        }
        
        print("⚠️ sendOnchain: Not directly available in FFI layer")
        print("   Use sendToOnchain() to offboard Ark funds to onchain address")
        print("   Or use separate Bitcoin wallet for direct onchain sends")
        
        throw BarkWalletFFIError.notSupported("Direct onchain sends not available. Use sendToOnchain() to offboard Ark funds.")
    }
    
    func board(amount: Int) async throws {
        // "Board" means bringing onchain Bitcoin into Ark
        // The FFI layer doesn't have a direct board method
        // This would typically involve sending Bitcoin to a deposit address
        
        if isPreview {
            print("Mock: Boarding \(amount) sats (preview mode)")
            return
        }
        
        print("⚠️ board: Not directly available in FFI layer")
        print("   Boarding typically involves:")
        print("   1. Get deposit address (if available)")
        print("   2. Send Bitcoin onchain to that address")
        print("   3. Wait for confirmations")
        
        throw BarkWalletFFIError.notSupported("Board operation not available in FFI. May need to send to deposit address manually.")
    }
    
    func boardAll() async throws -> String {
        // Board all available onchain funds into Ark
        
        if isPreview {
            return "Mock: Boarding all funds (preview mode)"
        }
        
        print("⚠️ boardAll: Not directly available in FFI layer")
        
        throw BarkWalletFFIError.notSupported("BoardAll operation not available in FFI. May need manual boarding process.")
    }
    
    // MARK: - Lightning Operations
    
    func payLightningInvoice(invoice: String, amount: Int) async throws -> String {
        // Pay a Lightning invoice with explicit amount
        // This is for invoices that don't have an amount encoded (amountless invoices)
        
        if isPreview {
            return "Mock: Paid invoice \(invoice) with \(amount) sats (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        // Validate amount
        guard amount > 0 else {
            throw BarkWalletFFIError.configurationError("Amount must be greater than 0")
        }
        
        // Convert Int to UInt64 for FFI
        let amountSats = UInt64(amount)
        
        print("🔧 Paying Lightning invoice via FFI...")
        print("   Invoice: \(String(invoice.prefix(30)))...")
        print("   Amount: \(amount) sats")
        
        do {
            // Call FFI payLightningInvoice with explicit amount
            let result = try wallet.payLightningInvoice(
                invoice: invoice,
                amountSats: amountSats
            )
            
            print("✅ Lightning payment successful")
            print("   Paid invoice: \(result.invoice)")
            if let preimage = result.preimage {
                print("   Preimage: \(String(preimage.prefix(16)))...")
            } else {
                print("   Preimage: not available")
            }
            
            // Return result string (amount not in result, use input amount)
            return "Successfully paid \(amount) sats to Lightning invoice"
            
        } catch let error as BarkError {
            print("❌ FFI Error paying Lightning invoice: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to pay Lightning invoice: \(error.localizedDescription)")
        } catch {
            print("❌ Error paying Lightning invoice: \(error)")
            throw error
        }
    }
    
    func payLightningInvoice(invoice: String, amount: Int?) async throws -> String {
        // Pay a Lightning invoice with optional amount
        // If amount is provided, use it; otherwise invoice should have amount encoded
        
        if isPreview {
            if let amount = amount {
                return "Mock: Paid invoice with \(amount) sats (preview mode)"
            } else {
                return "Mock: Paid invoice with encoded amount (preview mode)"
            }
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        // Validate amount if provided
        if let amount = amount {
            guard amount > 0 else {
                throw BarkWalletFFIError.configurationError("Amount must be greater than 0")
            }
        }
        
        // Convert optional Int to optional UInt64 for FFI
        let amountSats: UInt64? = amount.map { UInt64($0) }
        
        print("🔧 Paying Lightning invoice via FFI...")
        print("   Invoice: \(String(invoice.prefix(30)))...")
        if let amount = amount {
            print("   Amount: \(amount) sats (explicit)")
        } else {
            print("   Amount: from invoice")
        }
        
        do {
            // Call FFI payLightningInvoice with optional amount
            let result = try wallet.payLightningInvoice(
                invoice: invoice,
                amountSats: amountSats
            )
            
            print("✅ Lightning payment successful")
            print("   Paid invoice: \(result.invoice)")
            if let preimage = result.preimage {
                print("   Preimage: \(String(preimage.prefix(16)))...")
            } else {
                print("   Preimage: not available")
            }
            
            // Return result string
            if let amt = amount {
                return "Successfully paid \(amt) sats to Lightning invoice"
            } else {
                return "Successfully paid Lightning invoice"
            }
            
        } catch let error as BarkError {
            print("❌ FFI Error paying Lightning invoice: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to pay Lightning invoice: \(error.localizedDescription)")
        } catch {
            print("❌ Error paying Lightning invoice: \(error)")
            throw error
        }
    }
    
    func getLightningInvoice(amount: Int) async throws -> String {
        // Generate a Lightning invoice for receiving payment
        
        if isPreview {
            return "lnbc\(amount)0n1preview..."
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        // Validate amount
        guard amount > 0 else {
            throw BarkWalletFFIError.configurationError("Amount must be greater than 0")
        }
        
        // Convert Int to UInt64 for FFI
        let amountSats = UInt64(amount)
        
        print("🔧 Generating Lightning invoice via FFI...")
        print("   Amount: \(amount) sats")
        
        do {
            // Call FFI bolt11Invoice method
            let result = try wallet.bolt11Invoice(amountSats: amountSats)
            
            print("✅ Lightning invoice generated")
            print("   Amount: \(result.amountSats) sats")
            print("   Invoice: \(String(result.invoice.prefix(30)))...")
            
            // Return the invoice string
            return result.invoice
            
        } catch let error as BarkError {
            print("❌ FFI Error generating Lightning invoice: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to generate Lightning invoice: \(error.localizedDescription)")
        } catch {
            print("❌ Error generating Lightning invoice: \(error)")
            throw error
        }
    }
    
    func getLightningInvoiceStatus(invoice: String) async throws -> String {
        // Check the status of a Lightning invoice
        
        if isPreview {
            return "Mock: Invoice status - pending (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Checking Lightning invoice status via FFI...")
        print("   Invoice: \(String(invoice.prefix(30)))...")
        
        do {
            // Call FFI pendingLightningReceives method
            let pendingReceives = try wallet.pendingLightningReceives()
            
            // Find the invoice in pending receives
            if let receiveStatus = pendingReceives.first(where: { $0.invoice == invoice }) {
                print("✅ Found invoice in pending receives")
                
                // Build status string
                var status = "Invoice Status:\n"
                status += "  Payment Hash: \(receiveStatus.paymentHash)\n"
                status += "  Amount: \(receiveStatus.amountSats) sats\n"
                status += "  Has HTLC VTXOs: \(receiveStatus.hasHtlcVtxos ? "Yes" : "No")\n"
                status += "  Preimage Revealed: \(receiveStatus.preimageRevealed ? "Yes" : "No")\n"
                
                if receiveStatus.hasHtlcVtxos && !receiveStatus.preimageRevealed {
                    status += "  Status: Pending (ready to claim)"
                } else if receiveStatus.preimageRevealed {
                    status += "  Status: Claimed"
                } else {
                    status += "  Status: Waiting for payment"
                }
                
                return status
            } else {
                // Invoice not found in pending receives
                // It might be already claimed or never created
                print("⚠️ Invoice not found in pending receives")
                return "Invoice not found in pending receives. It may be already claimed or not yet paid."
            }
            
        } catch let error as BarkError {
            print("❌ FFI Error checking invoice status: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to check invoice status: \(error.localizedDescription)")
        } catch {
            print("❌ Error checking invoice status: \(error)")
            throw error
        }
    }
    
    func listLightningInvoices() async throws -> String {
        // List all Lightning invoices
        
        if isPreview {
            return "[]"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Listing Lightning invoices via FFI...")
        
        do {
            // Call FFI pendingLightningReceives method
            let pendingReceives = try wallet.pendingLightningReceives()
            
            print("✅ Retrieved \(pendingReceives.count) pending Lightning receives")
            
            // Convert to JSON array
            let invoiceList: [[String: Any]] = pendingReceives.map { receive in
                return [
                    "payment_hash": receive.paymentHash,
                    "invoice": receive.invoice,
                    "amount_sats": receive.amountSats,
                    "has_htlc_vtxos": receive.hasHtlcVtxos,
                    "preimage_revealed": receive.preimageRevealed,
                    "status": receive.hasHtlcVtxos && !receive.preimageRevealed ? "ready_to_claim" : 
                             (receive.preimageRevealed ? "claimed" : "waiting")
                ]
            }
            
            // Convert to JSON string
            let jsonData = try JSONSerialization.data(withJSONObject: invoiceList, options: [.prettyPrinted, .sortedKeys])
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw BarkWalletFFIError.configurationError("Failed to encode invoice list as JSON string")
            }
            
            return jsonString
            
        } catch let error as BarkError {
            print("❌ FFI Error listing invoices: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to list invoices: \(error.localizedDescription)")
        } catch {
            print("❌ Error listing invoices: \(error)")
            throw error
        }
    }
    
    func claimLightningInvoice(invoice: String) async throws -> String {
        // Claim a specific paid Lightning invoice
        // FFI uses tryClaimAllLightningReceives() which claims all pending
        
        if isPreview {
            return "Mock: Claimed invoice (preview mode)"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Claiming Lightning receives via FFI...")
        print("   Note: FFI claims ALL pending receives, not individual invoices")
        
        do {
            // Call FFI tryClaimAllLightningReceives
            // This claims all pending Lightning receives
            try wallet.tryClaimAllLightningReceives(wait: true)
            
            print("✅ Lightning receives claimed successfully")
            print("   All pending receives have been processed")
            
            return "Successfully claimed all pending Lightning receives"
            
        } catch let error as BarkError {
            print("❌ FFI Error claiming Lightning receives: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to claim Lightning receives: \(error.localizedDescription)")
        } catch {
            print("❌ Error claiming Lightning receives: \(error)")
            throw error
        }
    }
    
    // MARK: - Configuration & Info
    
    func getConfig() async throws -> ArkConfigModel {
        // Get wallet configuration
        
        if isPreview {
            // Return mock config
            return ArkConfigModel(
                ark: "https://preview.asp.com",
                bitcoind: nil,
                bitcoindCookie: nil,
                bitcoindUser: nil,
                bitcoindPass: nil,
                esplora: "https://preview.esplora.com",
                vtxoRefreshExpiryThreshold: 144,
                fallbackFeeRateKvb: 1000
            )
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Fetching wallet config via FFI...")
        
        // Call FFI config method (doesn't throw)
        let ffiConfig = wallet.config()
        
        print("✅ Config retrieved")
        
        // Convert FFI Config to ArkConfigModel
        let configModel = ArkConfigModel(
            ark: ffiConfig.serverAddress,
            bitcoind: ffiConfig.bitcoindAddress,
            bitcoindCookie: ffiConfig.bitcoindCookiefile,
            bitcoindUser: ffiConfig.bitcoindUser,
            bitcoindPass: ffiConfig.bitcoindPass,
            esplora: ffiConfig.esploraAddress,
            vtxoRefreshExpiryThreshold: Int(ffiConfig.vtxoRefreshExpiryThreshold ?? 144),
            fallbackFeeRateKvb: Int(ffiConfig.fallbackFeeRate ?? 1000)
        )
        
        return configModel
    }
    
    // MARK: - Debug Helpers
    
    /// Print detailed wallet state for diagnostics
    private func printWalletState(_ wallet: Wallet, context: String) {
        print("🔍 [WALLET STATE] \(context)")
        print("   Config server: \(wallet.config().serverAddress)")
        print("   Config esplora: \(wallet.config().esploraAddress ?? "nil")")
        print("   Config network: \(wallet.config().network)")
        
        // Try to get properties if available
        do {
            let props = try wallet.properties()
            print("   Wallet network: \(props.network)")
            print("   Wallet fingerprint: \(props.fingerprint)")
        } catch {
            print("   ⚠️ Could not get wallet properties: \(error)")
        }
        
        // Check if arkInfo is available
        if let arkInfo = wallet.arkInfo() {
            print("   ✅ Has server connection (arkInfo available)")
            print("      Round interval: \(arkInfo.roundIntervalSecs)s")
            print("      Server pubkey: \(String(arkInfo.serverPubkey.prefix(20)))...")
        } else {
            print("   ❌ No server connection (arkInfo returns nil)")
        }
        
        // Try to get balance (requires server connection)
        do {
            let balance = try wallet.balance()
            print("   ✅ Can fetch balance (server accessible)")
            print("      Spendable: \(balance.spendableSats) sats")
        } catch {
            print("   ❌ Cannot fetch balance: \(error)")
        }
    }
    
    /// Print the entire config object for debugging
    func printFullConfig() {
        print("📋 Full Config Object:")
        print("   Server Address: \(config.serverAddress)")
        print("   Esplora Address: \(config.esploraAddress ?? "nil")")
        print("   Bitcoind Address: \(config.bitcoindAddress ?? "nil")")
        print("   Bitcoind Cookie File: \(config.bitcoindCookiefile ?? "nil")")
        print("   Bitcoind User: \(config.bitcoindUser ?? "nil")")
        print("   Bitcoind Pass: \(config.bitcoindPass != nil ? "[REDACTED]" : "nil")")
        print("   Network: \(config.network)")
        print("   VTXO Refresh Expiry Threshold: \(config.vtxoRefreshExpiryThreshold.map { String($0) } ?? "nil")")
        print("   VTXO Exit Margin: \(config.vtxoExitMargin.map { String($0) } ?? "nil")")
        print("   HTLC Recv Claim Delta: \(config.htlcRecvClaimDelta.map { String($0) } ?? "nil")")
        print("   Fallback Fee Rate: \(config.fallbackFeeRate.map { String($0) } ?? "nil")")
        print("   Round Tx Required Confirmations: \(config.roundTxRequiredConfirmations.map { String($0) } ?? "nil")")
    }
    
    func getArkInfo() async throws -> ArkInfoModel {
        // Get ASP/Ark server information
        
        if isPreview {
            return ArkInfoModel(
                network: "signet",
                serverPubkey: "02preview0000000000000000000000000000000000000000000000000000000000",
                roundInterval: "30s",
                nbRoundNonces: 256,
                vtxoExitDelta: 512,
                vtxoExpiryDelta: 1024,
                htlcSendExpiryDelta: 72,
                htlcExpiryDelta: 144,
                maxVtxoAmount: 100000000,
                maxArkoorDepth: 4,
                requiredBoardConfirmations: 6,
                maxUserInvoiceCltvDelta: 288,
                minBoardAmount: 10000
            )
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Fetching Ark server info via FFI...")
        
        // Call FFI arkInfo method
        guard let ffiArkInfo = wallet.arkInfo() else {
            print("⚠️ Ark server info not available (not connected)")
            throw BarkWalletFFIError.configurationError("Ark server info not available. Wallet may not be connected to ASP.")
        }
        
        print("✅ Ark server info retrieved")
        
        // Convert FFI ArkInfo to ArkInfoModel
        let networkString = Self.convertFFINetworkToString(ffiArkInfo.network)
        
        // Convert round interval from seconds to string format like "30s"
        let roundIntervalString = "\(ffiArkInfo.roundIntervalSecs)s"
        
        let arkInfoModel = ArkInfoModel(
            network: networkString,
            serverPubkey: ffiArkInfo.serverPubkey,
            roundInterval: roundIntervalString,
            nbRoundNonces: Int(ffiArkInfo.nbRoundNonces),
            vtxoExitDelta: Int(ffiArkInfo.vtxoExitDelta),
            vtxoExpiryDelta: Int(ffiArkInfo.vtxoExpiryDelta),
            htlcSendExpiryDelta: Int(ffiArkInfo.htlcSendExpiryDelta),
            htlcExpiryDelta: Int(ffiArkInfo.htlcExpiryDelta),
            maxVtxoAmount: Int(ffiArkInfo.maxVtxoAmountSats ?? 0),
            maxArkoorDepth: 4, // Not provided by FFI, use default
            requiredBoardConfirmations: Int(ffiArkInfo.requiredBoardConfirmations),
            maxUserInvoiceCltvDelta: Int(ffiArkInfo.maxUserInvoiceCltvDelta),
            minBoardAmount: Int(ffiArkInfo.minBoardAmountSats)
        )
        
        return arkInfoModel
    }
    
    func getMovements() async throws -> String {
        // Get transaction history/movements
        
        if isPreview {
            return "[]"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Fetching wallet movements via FFI...")
        
        do {
            // Call FFI movements method
            let movements = try wallet.history()
            
            print("✅ Retrieved \(movements.count) movements")
            
            // Convert Movement array to JSON string
            let jsonEncoder = JSONEncoder()
            jsonEncoder.dateEncodingStrategy = .iso8601
            jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            // Convert FFI Movement to a JSON-serializable structure
            let movementDicts: [[String: Any]] = movements.map { movement in
                var dict: [String: Any] = [
                    "id": movement.id,
                    "status": movement.status,
                    "subsystem_name": movement.subsystemName,
                    "subsystem_kind": movement.subsystemKind,
                    "metadata_json": movement.metadataJson,
                    "intended_balance_sats": movement.intendedBalanceSats,
                    "effective_balance_sats": movement.effectiveBalanceSats,
                    "offchain_fee_sats": movement.offchainFeeSats,
                    "sent_to_addresses": movement.sentToAddresses,
                    "received_on_addresses": movement.receivedOnAddresses,
                    "input_vtxo_ids": movement.inputVtxoIds,
                    "output_vtxo_ids": movement.outputVtxoIds,
                    "created_at": movement.createdAt,
                    "updated_at": movement.updatedAt
                ]
                
                // Only include completed_at if it's not nil
                if let completedAt = movement.completedAt {
                    dict["completed_at"] = completedAt
                }
                
                return dict
            }
            
            // Convert to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: movementDicts, options: [.prettyPrinted, .sortedKeys])
            
            // Convert to string
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw BarkWalletFFIError.configurationError("Failed to encode movements as JSON string")
            }
            
            print("✅ Movements converted to JSON")
            
            return jsonString
            
        } catch let error as BarkError {
            print("❌ FFI Error fetching movements: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to get movements: \(error.localizedDescription)")
        } catch {
            print("❌ Error fetching movements: \(error)")
            throw error
        }
    }
    
    func getLatestBlockHeight() async throws -> Int {
        // Query latest block height from network
        // This is a network API call, not FFI-specific
        
        if isPreview {
            return 300000
        }
        
        let urlString = "\(networkConfig.esploraBaseURL)/blocks/tip/height"
        guard let url = URL(string: urlString) else {
            throw BarkWalletFFIError.configurationError("Invalid esplora URL: \(urlString)")
        }
        
        print("🔧 Fetching latest block height from esplora...")
        print("   URL: \(urlString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check if the response is successful
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    throw BarkWalletFFIError.configurationError("HTTP error: \(httpResponse.statusCode)")
                }
            }
            
            // Convert data to string and then to integer
            guard let heightString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let height = Int(heightString) else {
                throw BarkWalletFFIError.configurationError("Invalid block height response")
            }
            
            print("✅ Latest block height: \(height)")
            return height
            
        } catch {
            print("❌ Error fetching block height: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to fetch block height: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Network Safety Methods
    
    var currentNetworkName: String {
        networkConfig.name
    }
    
    var isMainnet: Bool {
        networkConfig.isMainnet
    }
    
    func requiresMainnetWarning() -> Bool {
        networkConfig.isMainnet
    }
    
    func validateMainnetOperation() throws {
        if networkConfig.isMainnet {
            print("⚠️ MAINNET OPERATION - Real Bitcoin will be used!")
        }
    }
    
    func sendWithSafetyCheck(to address: String, amount: Int) async throws -> String {
        try validateMainnetOperation()
        
        if networkConfig.isMainnet {
            print("🔴 MAINNET SEND: Sending \(amount) sats to \(address)")
        } else {
            print("🔵 \(networkConfig.networkType.uppercased()) SEND: Sending \(amount) sats to \(address)")
        }
        
        return try await send(to: address, amount: amount)
    }
    
    func sendOnchainWithSafetyCheck(to address: String, amount: Int) async throws -> String {
        try validateMainnetOperation()
        
        if networkConfig.isMainnet {
            print("🔴 MAINNET ONCHAIN SEND: Sending \(amount) sats to \(address)")
        } else {
            print("🔵 \(networkConfig.networkType.uppercased()) ONCHAIN SEND: Sending \(amount) sats to \(address)")
        }
        
        return try await sendOnchain(to: address, amount: amount)
    }
    
    // MARK: - Development
    
    func executeCustomCommand(_ commandString: String) async throws -> String {
        throw BarkWalletFFIError.notSupported("executeCustomCommand - FFI does not support arbitrary commands")
    }
    
    // MARK: - Internal Command Execution (placeholder for actual FFI calls)
    
    func executeCommand(_ args: [String]) async throws -> String {
        throw BarkWalletFFIError.notSupported("executeCommand - use specific FFI methods instead")
    }
    
    // MARK: - Private Helpers
    
    private static func getWalletDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        let walletDir = appSupport
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.yourapp.arkwallet")
            .appendingPathComponent("bark-data-ffi")
        
        // Create directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: walletDir.path) {
            do {
                // Create directory with explicit permissions that allow file creation
                #if os(macOS)
                let attributes: [FileAttributeKey: Any] = [
                    .posixPermissions: NSNumber(value: 0o755)
                ]
                try fileManager.createDirectory(
                    at: walletDir,
                    withIntermediateDirectories: true,
                    attributes: attributes
                )
                #else
                try fileManager.createDirectory(
                    at: walletDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                #endif
                
                print("📁 Created wallet directory: \(walletDir.path)")
                
                // Verify directory is writable by attempting to create a test file
                let testFile = walletDir.appendingPathComponent(".test")
                do {
                    try "test".write(to: testFile, atomically: true, encoding: .utf8)
                    try fileManager.removeItem(at: testFile)
                    print("✅ Wallet directory is writable")
                } catch {
                    print("⚠️ Warning: Wallet directory may not be writable: \(error)")
                }
                
            } catch {
                print("❌ Failed to create wallet directory: \(error)")
            }
        } else {
            print("📁 FFI Wallet directory exists: \(walletDir.path)")
            
            // Verify existing directory is writable
            let testFile = walletDir.appendingPathComponent(".test")
            do {
                try "test".write(to: testFile, atomically: true, encoding: .utf8)
                try fileManager.removeItem(at: testFile)
                print("✅ Wallet directory is writable")
            } catch {
                print("⚠️ Warning: Existing wallet directory may not be writable: \(error)")
            }
        }
        
        return walletDir
    }
    
    /// Convert our NetworkConfig networkType string to FFI Network enum
    private static func convertToFFINetwork(_ networkType: String) -> Network? {
        switch networkType.lowercased() {
        case "mainnet", "bitcoin":
            return .bitcoin
        case "testnet":
            return .testnet
        case "signet":
            return .signet
        case "regtest":
            return .regtest
        default:
            return nil
        }
    }
    
    /// Convert FFI Network enum back to string
    private static func convertFFINetworkToString(_ network: Network) -> String {
        switch network {
        case .bitcoin:
            return "bitcoin"
        case .testnet:
            return "testnet"
        case .signet:
            return "signet"
        case .regtest:
            return "regtest"
        }
    }
    
    // MARK: - Mnemonic Helpers
    
    /// Generate a new BIP39 mnemonic (12 words)
    private func generateMnemonic() throws -> String {
        // Use BIP39 library components
        // let entropyGenerator = EntropyGenerator()
        let wordListProvider = EnglishWordListProvider()
        let mnemonicConstructor = MnemonicConstructor()
        
        // Generate 16 bytes (128 bits) of cryptographically secure random entropy
        let entropyByteCount = 16  // 128 bits = 12 words
        var randomBytes = [UInt8](repeating: 0, count: entropyByteCount)
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        
        guard result == errSecSuccess else {
            throw BarkWalletFFIError.configurationError("Failed to generate cryptographically secure random entropy")
        }
        
        // Convert bytes to Data
        let entropy = Data(randomBytes)
        
        // Generate mnemonic from entropy
        let phrase = mnemonicConstructor.mnemonic(entropy: entropy, wordList: wordListProvider.wordList)
        
        print("✅ Generated secure 12-word BIP39 mnemonic")
        print("   Entropy: \(randomBytes.count * 8) bits")
        print("   Words: \(phrase.split(separator: " ").count)")
        
        return phrase
    }
    
    /// Validate a BIP39 mnemonic phrase
    private func validateMnemonic(_ phrase: String) -> Bool {
        // Check if all words are in the wordlist
        let words = phrase.split(separator: " ").map(String.init)
        let wordListProvider = EnglishWordListProvider()
        let wordList = wordListProvider.wordList
        
        // Verify all words exist in wordlist
        for word in words {
            if !wordList.contains(word) {
                print("⚠️ Invalid mnemonic: word '\(word)' not in BIP39 wordlist")
                return false
            }
        }
        
        // Verify word count (must be 12, 15, 18, 21, or 24)
        let validCounts = [12, 15, 18, 21, 24]
        guard validCounts.contains(words.count) else {
            print("⚠️ Invalid mnemonic: word count \(words.count) is not valid (must be 12, 15, 18, 21, or 24)")
            return false
        }
        
        // TODO: Add checksum validation if the library provides it
        return true
    }
    
    /// Store mnemonic securely using SecurityService (Keychain only - no legacy fallback)
    /// NOTE: This is called from BarkWalletFFI.createWallet() ONLY for import flows.
    /// For new wallet creation, WalletManager handles the storage to avoid duplication.
    private func storeMnemonic(_ mnemonic: String) async throws {
        // SecurityService is required - no fallback to file system
        guard let securityService = securityService else {
            throw BarkWalletFFIError.configurationError("SecurityService is required but not available")
        }
        
        print("✅ Storing mnemonic securely via SecurityService (Keychain)")
        do {
            // Store with biometric protection if available
            let useBiometric = securityService.biometricsAvailable()
            try await securityService.saveMnemonic(mnemonic, requireBiometric: useBiometric)
            
            print("✅ Mnemonic stored securely in Keychain")
            if useBiometric {
                print("🔐 Biometric protection enabled")
            }
        } catch {
            print("❌ SecurityService storage failed: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to store mnemonic securely: \(error.localizedDescription)")
        }
    }
    
    /// Load mnemonic securely using SecurityService (Keychain only - no legacy fallback)
    private func loadMnemonic() throws -> String {
        // SecurityService is required - no fallback to file system
        guard let securityService = securityService else {
            throw BarkWalletFFIError.configurationError("SecurityService is required but not available")
        }
        
        print("✅ Loading mnemonic securely via SecurityService (Keychain)")
        do {
            if let mnemonic = try securityService.loadMnemonic() {
                print("✅ Mnemonic loaded from Keychain")
                return mnemonic
            } else {
                print("⚠️ No mnemonic found in Keychain")
                throw BarkWalletFFIError.walletNotInitialized
            }
        } catch {
            print("❌ SecurityService load failed: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to load mnemonic: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Type Mapping Helpers
    
    /// Map FFI VTXO state string to our VTXOState enum
    private func mapFFIStateToVTXOState(_ stateString: String) -> VTXOState {
        // FFI states: "spendable", "spent", "locked", etc.
        // Our states: unregisteredBoard, registeredBoard, spent, pending, spendable, locked
        
        switch stateString.lowercased() {
        case "spendable":
            return .spendable
        case "spent":
            return .spent
        case "locked":
            return .locked
        case "pending":
            return .pending
        default:
            // If we can't map it, default to pending
            print("⚠️ Unknown VTXO state: '\(stateString)', defaulting to pending")
            return .pending
        }
    }
    
    /// Map FFI VTXO kind string to our PolicyType enum
    private func mapFFIKindToPolicyType(_ kindString: String) -> PolicyType {
        // FFI kinds: "board", "round", "arkoor", etc.
        // Our types: pubkey, multisig, serverHTLCSend
        
        // This is a best-guess mapping as the FFI doesn't expose policy type directly
        // Most VTXOs will be pubkey type
        switch kindString.lowercased() {
        case "board", "round", "arkoor":
            return .pubkey
        default:
            print("⚠️ Unknown VTXO kind: '\(kindString)', defaulting to pubkey")
            return .pubkey
        }
    }
}

// MARK: - Error Types

enum BarkWalletFFIError: Error, LocalizedError {
    case notImplemented(String)
    case notSupported(String)
    case walletNotInitialized
    case invalidMnemonic
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .notImplemented(let method):
            return "Method not yet implemented: \(method)"
        case .notSupported(let method):
            return "Method not supported in FFI implementation: \(method)"
        case .walletNotInitialized:
            return "Wallet has not been created or opened"
        case .invalidMnemonic:
            return "Invalid mnemonic phrase"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}
