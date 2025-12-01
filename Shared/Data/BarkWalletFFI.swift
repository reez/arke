//
//  BarkWalletFFI.swift
//  Ark wallet prototype
//
//  FFI-based implementation of BarkWalletProtocol using Rust library
//

import Foundation
import BIP39
import Network

/// FFI-based implementation of BarkWalletProtocol using the Rust bark library
/// This provides better performance and type safety compared to the CLI-based approach
class BarkWalletFFI: BarkWalletProtocol {
    
    // MARK: - Properties
    
    /// The underlying FFI wallet object (nil until wallet is created/opened)
    private var wallet: Wallet?
    
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
            network: ffiNetwork,
            vtxoRefreshExpiryThreshold: nil,  // Use defaults
            vtxoExitMargin: nil,
            htlcRecvClaimDelta: nil
        )
        
        print("✅ BarkWalletFFI initialized")
        print("   Network: \(networkConfig.name)")
        print("   Wallet dir: \(walletDir.path)")
        
        // Note: Wallet opening is now explicit via openWalletIfNeeded()
        // This prevents uncoordinated background opening during init
    }
    
    // MARK: - Explicit Wallet Opening
    
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
            let openedWallet = try Wallet.open(
                mnemonic: mnemonic,
                config: config,
                datadir: datadir
            )
            
            self.wallet = openedWallet
            self.cachedMnemonic = mnemonic
            
            // let afterOpen = Date()
            print("✅ Existing wallet opened successfully")
            // print("🔍 [DIAGNOSTIC] Wallet.open() took \(afterOpen.timeIntervalSince(beforeOpen)) seconds")
            // print("🔍 [DIAGNOSTIC] Total time: \(afterOpen.timeIntervalSince(startTime)) seconds")
            
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
            var resumed = false
            let lock = NSLock()
            
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
                
                lock.lock()
                if !resumed {
                    resumed = true
                    monitor.cancel()
                    continuation.resume()
                }
                lock.unlock()
            }
            
            monitor.start(queue: queue)
            
            // Timeout after 2 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                lock.lock()
                if !resumed {
                    resumed = true
                    monitor.cancel()
                    print("🔍 [DIAGNOSTIC] Network status check timed out")
                    continuation.resume()
                }
                lock.unlock()
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
                network: ffiNetwork,
                vtxoRefreshExpiryThreshold: nil,
                vtxoExitMargin: nil,
                htlcRecvClaimDelta: nil
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
            let newWallet = try Wallet.create(
                mnemonic: mnemonic,
                config: finalConfig,
                datadir: datadir,
                forceRescan: true
            )
            
            self.wallet = newWallet
            self.cachedMnemonic = mnemonic
            
            // Store mnemonic securely
            try storeMnemonic(mnemonic)
            
            print("✅ Wallet created successfully")
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
                network: ffiNetwork,
                vtxoRefreshExpiryThreshold: nil,
                vtxoExitMargin: nil,
                htlcRecvClaimDelta: nil
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
            let restoredWallet = try Wallet.create(
                mnemonic: mnemonic,
                config: finalConfig,
                datadir: datadir,
                forceRescan: true
            )
            
            self.wallet = restoredWallet
            self.cachedMnemonic = mnemonic
            
            // Store mnemonic securely
            try storeMnemonic(mnemonic)
            
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
        
        // Delete from SecurityService (Keychain) if available
        if let securityService = securityService {
            print("🗑️ Deleting mnemonic from Keychain via SecurityService")
            do {
                try securityService.deleteMnemonic()
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
        // Preview mode handling
        if isPreview {
            return "ark1preview0000000000000000000000000000000000000000000000000000000"
        }
        
        // Ensure wallet is initialized
        guard let wallet = wallet else {
            throw BarkWalletFFIError.walletNotInitialized
        }
        
        print("🔧 Generating new address via FFI...")
        
        do {
            // Call FFI newAddress method
            let address = try wallet.newAddress()
            
            print("✅ New address generated: \(address)")
            
            return address
            
        } catch let error as BarkError {
            print("❌ FFI Error generating address: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to generate address: \(error.localizedDescription)")
        } catch {
            print("❌ Error generating address: \(error)")
            throw error
        }
    }
    
    func getOnchainAddress() async throws -> String {
        // Note: FFI doesn't separate onchain vs ark addresses
        // For now, use the same newAddress() method
        // This may need to be revisited based on Rust implementation
        
        if isPreview {
            return "tb1preview00000000000000000000000000000000000000000000"
        }
        
        // Use same method as Ark address
        // The underlying wallet should provide the appropriate address type
        return try await getArkAddress()
    }
    
    func getOnchainBalance() async throws -> OnchainBalanceResponse {
        // Note: FFI Balance struct doesn't separate onchain balance explicitly
        // This may not be directly available in the FFI layer
        // For now, return zeros as onchain operations may be handled differently
        
        if isPreview {
            return OnchainBalanceResponse(
                totalSat: 0,
                trustedSpendableSat: 0,
                immatureSat: 0,
                trustedPendingSat: 0,
                untrustedPendingSat: 0,
                confirmedSat: 0
            )
        }
        
        print("⚠️ getOnchainBalance: FFI layer may not separate onchain balance")
        print("   Returning zeros - may need Rust implementation update")
        
        // Return empty balance for now
        return OnchainBalanceResponse(
            totalSat: 0,
            trustedSpendableSat: 0,
            immatureSat: 0,
            trustedPendingSat: 0,
            untrustedPendingSat: 0,
            confirmedSat: 0
        )
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
        // FFI doesn't have selective refresh, so run full maintenance
        
        if isPreview {
            return "Mock: Refreshed VTXO \(vtxo_id) (preview mode)"
        }
        
        print("⚠️ refreshVTXO: FFI maintenance() refreshes all VTXOs, not selective")
        print("   Running full maintenance for VTXO: \(vtxo_id)")
        
        // Use the same maintenance method
        return try await refreshVTXOs()
    }
    
    func exitVTXO(vtxo_id: String) async throws -> String {
        // Unilateral exit of a specific VTXO
        // This is different from offboardAll (which is cooperative)
        
        if isPreview {
            return "Mock: Exited VTXO \(vtxo_id) (preview mode)"
        }
        
        print("⚠️ exitVTXO: Selective VTXO exit not available in FFI")
        print("   Use offboardAll() for cooperative exit of all VTXOs")
        
        throw BarkWalletFFIError.notSupported("Selective VTXO exit not available. Use sendToOnchain() to offboard all funds.")
    }
    
    func startExit() async throws -> String {
        // Start unilateral exit process
        
        if isPreview {
            return "Mock: Started exit process (preview mode)"
        }
        
        print("⚠️ startExit: Unilateral exit process not directly available in FFI")
        print("   Use offboardAll() for cooperative exit")
        
        throw BarkWalletFFIError.notSupported("Unilateral exit not available. Use sendToOnchain() for cooperative offboarding.")
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
            // Note: This method doesn't return a value in the FFI layer
            try wallet.sendArkoorPayment(arkAddress: address, amountSats: amountSats)
            
            print("✅ Payment sent successfully")
            print("   Amount: \(amount) sats")
            print("   To: \(address)")
            
            // Return success message
            return "Successfully sent \(amount) sats to \(address)"
            
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
        
        do {
            // Call FFI offboardAll method
            // Note: This offboards ALL VTXOs to the specified address
            // The amount parameter is not used in the current FFI API
            let result = try wallet.offboardAll(bitcoinAddress: address)
            
            print("✅ Offboard initiated successfully")
            print("   Round ID: \(result.roundId)")
            print("   Destination: \(address)")
            
            // Return result with round ID
            return "Offboard initiated. Round ID: \(result.roundId)"
            
        } catch let error as BarkError {
            print("❌ FFI Error offboarding: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to offboard: \(error.localizedDescription)")
        } catch {
            print("❌ Error offboarding: \(error)")
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
            print("   Preimage: \(String(result.preimage.prefix(16)))...")
            
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
            print("   Preimage: \(String(result.preimage.prefix(16)))...")
            
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
        // Note: This functionality may not be directly available in FFI
        
        if isPreview {
            return "Mock: Invoice status - pending (preview mode)"
        }
        
        print("⚠️ getLightningInvoiceStatus: Not directly available in FFI layer")
        print("   Invoice status tracking may need separate implementation")
        
        throw BarkWalletFFIError.notSupported("Invoice status checking not available in current FFI. Use tryClaimAllLightningReceives() to claim pending invoices.")
    }
    
    func listLightningInvoices() async throws -> String {
        // List all Lightning invoices
        // Note: This functionality may not be directly available in FFI
        
        if isPreview {
            return "[]"
        }
        
        print("⚠️ listLightningInvoices: Not directly available in FFI layer")
        print("   Invoice listing may need separate implementation")
        
        throw BarkWalletFFIError.notSupported("Invoice listing not available in current FFI.")
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
        // FFI doesn't directly expose this, but we have the config object
        
        if isPreview {
            // Return mock config
            throw BarkWalletFFIError.notImplemented("getConfig")
        }
        
        print("⚠️ getConfig: Not directly available in FFI")
        print("   Config is stored internally but not exposed as model")
        
        throw BarkWalletFFIError.notSupported("Config retrieval not available. Configuration set at wallet creation.")
    }
    
    func getArkInfo() async throws -> ArkInfoModel {
        // Get ASP/Ark server information
        
        if isPreview {
            throw BarkWalletFFIError.notImplemented("getArkInfo")
        }
        
        print("⚠️ getArkInfo: Not directly available in FFI")
        print("   ASP info not exposed through current FFI API")
        
        throw BarkWalletFFIError.notSupported("Ark info not available in current FFI.")
    }
    
    func getMovements() async throws -> String {
        // Get transaction history/movements
        
        if isPreview {
            return "[]"
        }
        
        print("⚠️ getMovements: Not available in FFI")
        print("   Transaction history not exposed")
        print("   Consider tracking transactions in app layer")
        
        throw BarkWalletFFIError.notSupported("Movement history not available. Use VTXO list and balance changes to track activity.")
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
    
    // MARK: - Mnemonic Helpers
    
    /// Generate a new BIP39 mnemonic (24 words)
    private func generateMnemonic() throws -> String {
        // Use BIP39 library components
        let entropyGenerator = EntropyGenerator()
        let wordListProvider = EnglishWordListProvider()
        let mnemonicConstructor = MnemonicConstructor()
        
        // Generate secure 256-bit entropy (24 words)
        let entropy = entropyGenerator.entropy(security: .strongest)
        
        // Generate mnemonic from entropy
        let phrase = mnemonicConstructor.mnemonic(entropy: entropy, wordList: wordListProvider.wordList)
        
        print("✅ Generated secure 24-word BIP39 mnemonic")
        print("   Entropy: \(entropy.count * 8) bits")
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
        
        // TODO: Add checksum validation if needed
        return true
    }
    
    /// Store mnemonic securely using SecurityService (Keychain only - no legacy fallback)
    private func storeMnemonic(_ mnemonic: String) throws {
        // SecurityService is required - no fallback to file system
        guard let securityService = securityService else {
            throw BarkWalletFFIError.configurationError("SecurityService is required but not available")
        }
        
        print("✅ Storing mnemonic securely via SecurityService (Keychain)")
        do {
            // Store with biometric protection if available
            let useBiometric = securityService.biometricsAvailable()
            try securityService.saveMnemonic(mnemonic, requireBiometric: useBiometric)
            
            // Also save hash for cross-device detection
            Task {
                try? await securityService.saveHashToStorage(mnemonic)
            }
            
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
