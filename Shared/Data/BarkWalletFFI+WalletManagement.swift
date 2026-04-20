//
//  BarkWalletFFI+WalletManagement.swift
//  Arke
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension BarkWalletFFI {
    
    func createWallet(network: String? = nil, asp: String? = nil) async throws -> String {
        // Preview mode handling
        if isPreview {
            print("⚠️ Preview mode - using mock wallet creation")
            return "Mock: Wallet created (preview mode)"
        }
        
        // ✅ NEW: Verify clean state before creating
        print("🔍 Step 0: Verifying clean state before wallet creation...")
        
        // Ensure no wallet is currently loaded
        if wallet != nil {
            print("⚠️ Warning: Existing wallet instance found, clearing...")
            await shutdownWallet()
        }
        
        let fileManager = FileManager.default
        
        // ✅ NEW: If directory exists from previous wallet, remove it
        if fileManager.fileExists(atPath: walletDir.path) {
            print("⚠️ Old wallet directory exists, removing before creation...")
            do {
                try fileManager.removeItem(at: walletDir)
                print("✅ Old directory removed")
                
                // Brief pause to ensure filesystem has processed the deletion
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            } catch {
                print("❌ Failed to remove old directory: \(error)")
                throw BarkWalletFFIError.configurationError("Cannot create wallet: old directory exists and cannot be removed")
            }
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
                roundTxRequiredConfirmations: nil,  // Use default confirmations
                daemonFastSyncIntervalSecs: nil,  // Use default fast sync interval
                daemonSlowSyncIntervalSecs: nil   // Use default slow sync interval
            )
        } else {
            finalConfig = config
        }
        
        print("🔧 Creating wallet with FFI...")
        print("   Network: \(finalConfig.network)")
        print("   ASP: \(finalConfig.serverAddress)")
        print("   Data dir: \(datadir)")
        
        // ✅ ENHANCED: Better directory preparation
        print("🔍 Step 1: Preparing data directory...")
        if !fileManager.fileExists(atPath: datadir) {
            print("   Creating data directory...")
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
                print("   ✅ Data directory created successfully")
            } catch {
                let errorMsg = "Failed to create data directory: \(error.localizedDescription)"
                print("   ❌ \(errorMsg)")
                throw BarkWalletFFIError.configurationError(errorMsg)
            }
        } else {
            print("   ✅ Data directory already exists")
        }
        
        // Verify directory is writable
        let testFile = walletDir.appendingPathComponent(".write-test-\(UUID().uuidString)")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
            print("   ✅ Data directory is confirmed writable")
        } catch {
            let errorMsg = "Data directory is not writable: \(error.localizedDescription)"
            print("   ❌ \(errorMsg)")
            throw BarkWalletFFIError.configurationError(errorMsg)
        }
        
        // Create wallet using FFI
        print("🔍 Step 2: Creating wallet with FFI...")
        do {
            print("   About to call Wallet.createWithOnchain()...")
            print("   forceRescan: true")
            
            // Create onchain wallet directory
            print("   Creating onchain wallet...")
            let bdkDataDir = walletDir.appendingPathComponent("bdk", isDirectory: true)
            
            // Clean up legacy BDK files from root directory
            let legacyBDKFile = walletDir.appendingPathComponent("bdk_wallet.db")
            if fileManager.fileExists(atPath: legacyBDKFile.path) {
                print("   ⚠️ Found legacy BDK database at root, cleaning up...")
                try? fileManager.removeItem(at: legacyBDKFile)
                ["bdk_wallet.db-journal", "bdk_wallet.db-wal", "bdk_wallet.db-shm"].forEach { suffix in
                    let file = walletDir.appendingPathComponent(suffix)
                    try? fileManager.removeItem(at: file)
                }
                print("   ✅ Legacy BDK files cleaned up")
            }
            
            // Ensure BDK directory exists
            if !fileManager.fileExists(atPath: bdkDataDir.path) {
                try fileManager.createDirectory(at: bdkDataDir, withIntermediateDirectories: true)
                print("   Created BDK data directory: \(bdkDataDir.path)")
            }
            
            // Use Bark's built-in BDK wallet
            let builtInWallet = try await OnchainWallet.default(
                mnemonic: mnemonic,
                config: finalConfig,
                datadir: bdkDataDir.path
            )
            print("   ✅ Built-in onchain wallet created")
            
            // Create lightweight transaction reader for history
            print("   Creating transaction history reader...")
            let txReader = try BDKTransactionReader(
                mnemonic: mnemonic,
                network: finalConfig.network,
                esploraURL: finalConfig.esploraAddress ?? networkConfig.esploraBaseURL,
                dataDir: bdkDataDir
            )
            print("   ✅ Transaction reader created")
            
            // Create Bark wallet with built-in onchain capabilities
            let newWallet = try await Wallet.createWithOnchain(
                mnemonic: mnemonic,
                config: finalConfig,
                datadir: datadir,
                onchainWallet: builtInWallet,
                forceRescan: true
            )
            
            self.wallet = newWallet
            self.onchainWallet = builtInWallet
            self.transactionReader = txReader
            self.cachedMnemonic = mnemonic
            
            // Perform initial transaction reader sync in background
            Task { [weak self] in
                guard self != nil else { return }
                do {
                    print("🔄 Starting background transaction sync...")
                    try await txReader.sync(fullScan: true)
                    print("✅ Background BDK sync complete - transaction history ready")
                } catch {
                    print("⚠️ Background BDK sync failed (will retry on demand): \(error.localizedDescription)")
                }
            }
            
            print("✅ Wallet created successfully")
            
            // DIAGNOSTIC: Compare wallet state immediately after creation vs opening
            await printWalletState(newWallet, context: "After Wallet.create()")
            
            // Try immediate arkInfo() call before waiting
            print("🔍 [DIAGNOSTIC] Immediate arkInfo() check after creation...")
            if let immediateArkInfo = await newWallet.arkInfo() {
                print("✅ [SURPRISE] Server connected IMMEDIATELY after creation!")
                print("   Round interval: \(immediateArkInfo.roundIntervalSecs)s")
            } else {
                print("⚠️ [DIAGNOSTIC] No immediate server connection after creation")
            }
            
            // Try calling sync() to see if that establishes connection
            print("🔍 [DIAGNOSTIC] Attempting wallet.sync() to establish connection...")
            do {
                try await newWallet.sync()
                print("✅ [DIAGNOSTIC] sync() completed successfully")
                
                // Check connection again after sync
                if let postSyncArkInfo = await newWallet.arkInfo() {
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
                    try await newWallet.maintenance()
                    print("✅ [DIAGNOSTIC] maintenance() completed")
                    
                    if let postMaintenanceArkInfo = await newWallet.arkInfo() {
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
            
            // ✅ NEW: Enhanced error handling with cleanup suggestion
            if error.localizedDescription.contains("bark_properties") ||
               error.localizedDescription.contains("database") ||
               error.localizedDescription.contains("SQL") {
                print("💡 Database error detected - this may be due to stale database files")
                print("   Attempting cleanup and suggesting retry...")
                
                // Try to clean up and suggest retry
                if fileManager.fileExists(atPath: walletDir.path) {
                    try? fileManager.removeItem(at: walletDir)
                }
                
                throw BarkWalletFFIError.configurationError(
                    "Failed to create wallet due to database error. Please try again. If the issue persists, restart the app.\n\nTechnical details: \(error.localizedDescription)"
                )
            }
            
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
                roundTxRequiredConfirmations: nil,  // Use default confirmations
                daemonFastSyncIntervalSecs: nil,  // Use default fast sync interval
                daemonSlowSyncIntervalSecs: nil   // Use default slow sync interval
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
            // Create onchain wallet for import
            print("🔧 Creating onchain wallet for import...")
            let bdkDataDir = walletDir.appendingPathComponent("bdk", isDirectory: true)
            
            // Clean up legacy BDK files
            let legacyBDKFile = walletDir.appendingPathComponent("bdk_wallet.db")
            if fileManager.fileExists(atPath: legacyBDKFile.path) {
                print("   ⚠️ Found legacy BDK database at root, cleaning up...")
                try? fileManager.removeItem(at: legacyBDKFile)
                ["bdk_wallet.db-journal", "bdk_wallet.db-wal", "bdk_wallet.db-shm"].forEach { suffix in
                    let file = walletDir.appendingPathComponent(suffix)
                    try? fileManager.removeItem(at: file)
                }
                print("   ✅ Legacy BDK files cleaned up")
            }
            
            // Ensure BDK directory exists
            if !fileManager.fileExists(atPath: bdkDataDir.path) {
                try fileManager.createDirectory(at: bdkDataDir, withIntermediateDirectories: true)
                print("   Created BDK data directory: \(bdkDataDir.path)")
            }
            
            // Use Bark's built-in BDK wallet
            let builtInWallet = try await OnchainWallet.default(
                mnemonic: mnemonic,
                config: finalConfig,
                datadir: bdkDataDir.path
            )
            print("✅ Built-in onchain wallet created")
            
            // Create lightweight transaction reader for history
            print("🔧 Creating transaction history reader...")
            let txReader = try BDKTransactionReader(
                mnemonic: mnemonic,
                network: finalConfig.network,
                esploraURL: finalConfig.esploraAddress ?? networkConfig.esploraBaseURL,
                dataDir: bdkDataDir
            )
            print("✅ Transaction reader created")
            
            // Create Bark wallet with built-in onchain capabilities
            let restoredWallet = try await Wallet.createWithOnchain(
                mnemonic: mnemonic,
                config: finalConfig,
                datadir: datadir,
                onchainWallet: builtInWallet,
                forceRescan: true
            )
            
            self.wallet = restoredWallet
            self.onchainWallet = builtInWallet
            self.transactionReader = txReader
            self.cachedMnemonic = mnemonic
            
            // Perform initial transaction reader sync in background
            // This is especially important for imported wallets to discover transaction history
            Task { [weak self] in
                guard self != nil else { return }
                do {
                    print("🔄 Starting background transaction sync for imported wallet...")
                    try await txReader.sync(fullScan: true)
                    print("✅ Background transaction sync complete - history ready")
                } catch {
                    print("⚠️ Background transaction sync failed (will retry on demand): \(error.localizedDescription)")
                }
            }
            
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
            // Create BDK onchain wallet first in a dedicated subdirectory
            print("🔧 Creating BDK onchain wallet...")
            let bdkDataDir = walletDir.appendingPathComponent("bdk", isDirectory: true)
            
            // Ensure BDK directory exists
            let fileManager = FileManager.default
            
            // Clean up legacy BDK files from root directory (from before subdirectory migration)
            let legacyBDKFile = walletDir.appendingPathComponent("bdk_wallet.db")
            if fileManager.fileExists(atPath: legacyBDKFile.path) {
                print("⚠️ Found legacy BDK database at root, cleaning up...")
                try? fileManager.removeItem(at: legacyBDKFile)
                // Also remove any associated files (journal, wal, etc.)
                ["bdk_wallet.db-journal", "bdk_wallet.db-wal", "bdk_wallet.db-shm"].forEach { suffix in
                    let file = walletDir.appendingPathComponent(suffix)
                    try? fileManager.removeItem(at: file)
                }
                print("   ✅ Legacy BDK files cleaned up")
            }
            
            // Check if BDK directory exists
            let bdkDirExists = fileManager.fileExists(atPath: bdkDataDir.path)
            print("   BDK directory exists: \(bdkDirExists)")
            
            if !bdkDirExists {
                print("   Creating BDK data directory: \(bdkDataDir.path)")
                try fileManager.createDirectory(at: bdkDataDir, withIntermediateDirectories: true)
                print("   ✅ BDK directory created")
            }
            
            // List BDK directory contents
            if let contents = try? fileManager.contentsOfDirectory(atPath: bdkDataDir.path) {
                print("   BDK directory contents (\(contents.count) items):")
                for item in contents {
                    let itemPath = bdkDataDir.appendingPathComponent(item)
                    if let attrs = try? fileManager.attributesOfItem(atPath: itemPath.path),
                       let size = attrs[.size] as? Int64 {
                        print("      - \(item) (\(size) bytes)")
                    } else {
                        print("      - \(item)")
                    }
                }
            }
            
            print("   Using Bark's built-in BDK wallet...")
            print("      Mnemonic word count: \(mnemonic.split(separator: " ").count)")
            print("      Network: \(config.network)")
            print("      Esplora: \(config.esploraAddress ?? networkConfig.esploraBaseURL)")
            
            // Use Bark's built-in BDK wallet (handles CPFP internally)
            let builtInWallet = try await OnchainWallet.default(
                mnemonic: mnemonic,
                config: config,
                datadir: bdkDataDir.path
            )
            print("✅ Built-in onchain wallet created")
            
            // Create lightweight transaction reader for history
            print("🔧 Creating transaction history reader...")
            let txReader = try BDKTransactionReader(
                mnemonic: mnemonic,
                network: config.network,
                esploraURL: config.esploraAddress ?? networkConfig.esploraBaseURL,
                dataDir: bdkDataDir
            )
            print("✅ Transaction reader created")
            
            // DIAGNOSTIC: Compare wallet configurations
            print("🔍 WALLET CONFIGURATION COMPARISON:")
            do {
                // Get first address from built-in wallet
                let builtInAddress = try await builtInWallet.newAddress()
                print("   Built-in wallet first address: \(builtInAddress)")
                
                // Get first 5 addresses from transaction reader
                let txReaderAddresses = txReader.getFirstNAddresses(count: 25)
                print("   Transaction reader first 25 addresses:")
                for (index, address) in txReaderAddresses.enumerated() {
                    print("      [\(index)]: \(address)")
                }
                
                // Compare built-in address with first TX reader address
                let builtInStr = String(describing: builtInAddress)
                if let firstTxReaderAddress = txReaderAddresses.first {
                    if builtInStr == firstTxReaderAddress {
                        print("   ✅ Addresses MATCH - wallets are using same descriptors")
                    } else {
                        print("   ⚠️ Addresses DIFFER - wallets may have different descriptors!")
                        print("      Built-in:  \(builtInStr)")
                        print("      TX Reader [0]: \(firstTxReaderAddress)")
                        // Check if built-in matches any of the first 5 addresses
                        if let matchIndex = txReaderAddresses.firstIndex(of: builtInStr) {
                            print("      ℹ️ Built-in address matches TX Reader[\(matchIndex)] - possible offset!")
                        }
                    }
                }
            } catch {
                print("   ⚠️ Could not compare wallet addresses: \(error)")
            }
            
            // Test Esplora connection before opening main wallet
            print("🔧 Testing Esplora connection...")
            let esploraURL = config.esploraAddress ?? networkConfig.esploraBaseURL
            print("   Esplora URL: \(esploraURL)")
            
            if let url = URL(string: "\(esploraURL)/blocks/tip/hash") {
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    if let httpResponse = response as? HTTPURLResponse {
                        print("   HTTP Status: \(httpResponse.statusCode)")
                    }
                    if let hashString = String(data: data, encoding: .utf8) {
                        print("   Block hash received: \(hashString.prefix(16))... (length: \(hashString.count))")
                    }
                } catch {
                    print("   ⚠️ Esplora connection test failed: \(error)")
                }
            }
            
            // Open Bark wallet with BDK-backed onchain capabilities
            print("🔧 Opening Bark wallet with onchain capabilities...")
            print("   Mnemonic word count: \(mnemonic.split(separator: " ").count)")
            print("   Config network: \(config.network)")
            print("   Data directory: \(datadir)")
            
            // Check if Bark wallet data exists
            let barkWalletFiles = ["wallet.db", "state.json", "wallet.dat"]
            for file in barkWalletFiles {
                let filePath = (datadir as NSString).appendingPathComponent(file)
                let exists = fileManager.fileExists(atPath: filePath)
                if exists {
                    if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                       let size = attrs[.size] as? Int64 {
                        print("   Found Bark file: \(file) (\(size) bytes)")
                    }
                }
            }
            
            let openedWallet = try await Wallet.openWithOnchain(
                mnemonic: mnemonic,
                config: config,
                datadir: datadir,
                onchainWallet: builtInWallet
            )
            print("✅ Bark Wallet.openWithOnchain() succeeded!")
            
            self.wallet = openedWallet
            self.onchainWallet = builtInWallet
            self.transactionReader = txReader
            self.cachedMnemonic = mnemonic
            
            // Perform initial transaction reader sync in background (non-blocking)
            // This proactively syncs transaction history without blocking wallet opening
            // If sync fails, it will be retried when transaction history is accessed
            Task { [weak self] in
                guard self != nil else { return }
                do {
                    print("🔄 Starting background transaction sync...")
                    try await txReader.sync(fullScan: true)
                    print("✅ Background transaction sync complete - history ready")
                } catch {
                    print("⚠️ Background transaction sync failed (will retry on demand): \(error.localizedDescription)")
                }
            }
            
            // let afterOpen = Date()
            print("✅ Existing wallet opened successfully")
            // print("🔍 [DIAGNOSTIC] Wallet.open() took \(afterOpen.timeIntervalSince(beforeOpen)) seconds")
            // print("🔍 [DIAGNOSTIC] Total time: \(afterOpen.timeIntervalSince(startTime)) seconds")
            
            // DIAGNOSTIC: Print wallet state immediately after opening
            await printWalletState(openedWallet, context: "After Wallet.open()")
            
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
            print("❌ Could not open existing wallet: BarkError")
            print("   Error: \(error)")
            print("   Error description: \(error.localizedDescription)")
            print("   Error type: \(type(of: error))")
            
            // Print error string representation to see if it contains "DataAlreadyExists"
            let errorString = String(describing: error)
            print("   Error string: \(errorString)")
            if errorString.contains("DataAlreadyExists") {
                print("   → This appears to be a DataAlreadyExists error")
                print("   → This should NOT happen - BDK Wallet() should load existing data")
            }
            
            // Don't fail init - user can create a new wallet
        } catch {
            print("❌ Could not open existing wallet: Unknown error")
            print("   Error: \(error)")
            print("   Error description: \(error.localizedDescription)")
            print("   Error type: \(type(of: error))")
            
            // Print error string to check for specific error messages
            let errorString = String(describing: error)
            print("   Error string: \(errorString)")
            
            // If it's an NSError, print more details
            let nsError = error as NSError
            print("   NSError domain: \(nsError.domain)")
            print("   NSError code: \(nsError.code)")
            print("   NSError userInfo: \(nsError.userInfo)")
        }
    }
    
    // MARK: - Wallet Lifecycle Cleanup
    
    /// Explicitly shutdown and cleanup wallet resources
    /// Call this BEFORE deleting wallet files to ensure proper cleanup
    private func shutdownWallet() async {
        guard let wallet = wallet else { return }
        
        print("🛑 [BarkWalletFFI] Shutting down wallet...")
        
        // Try to sync any pending state before shutdown
        do {
            try await wallet.sync()
            print("   ✅ Final sync completed")
        } catch {
            print("   ⚠️ Final sync failed (non-critical): \(error)")
        }
        
        // Give the FFI time to flush any pending database writes
        // This is critical - the Rust layer may have buffered writes
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // Clear references (this should trigger Rust cleanup)
        self.wallet = nil
        self.onchainWallet = nil
        self.cachedMnemonic = nil
        
        print("   ✅ Wallet references cleared")
        
        // Additional delay to ensure Rust has fully released database handles
        // SQLite may need time to close connections properly
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        print("   ✅ Wallet shutdown complete")
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
        
        // ✅ NEW: Explicit shutdown before deletion
        print("🛑 Step 1: Shutting down wallet...")
        await shutdownWallet()
        
        // Delete from SecurityService (Keychain only - local deletion)
        if let securityService = securityService {
            print("🗑️ Step 2: Deleting mnemonic from Keychain via SecurityService")
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
        
        print("🗑️ Step 3: Deleting wallet directory: \(walletDir.path)")
        
        do {
            // Remove the entire wallet directory and its contents
            try fileManager.removeItem(at: walletDir)
            print("✅ Successfully deleted wallet directory")
            
            // ✅ NEW: Extra verification that directory is gone
            let stillExists = fileManager.fileExists(atPath: walletDir.path)
            if stillExists {
                print("⚠️ Warning: Directory still exists after deletion attempt")
                throw BarkWalletFFIError.configurationError("Failed to fully delete wallet directory")
            }
            
            return "Successfully deleted wallet directory at \(walletDir.path)"
        } catch {
            print("❌ Failed to delete wallet directory: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to delete wallet directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Debug Helpers
    
    /// Print detailed wallet state for diagnostics
    private func printWalletState(_ wallet: Wallet, context: String) async {
        print("🔍 [WALLET STATE] \(context)")
        let config = await wallet.config()
        print("   Config server: \(config.serverAddress)")
        print("   Config esplora: \(config.esploraAddress ?? "nil")")
        print("   Config network: \(config.network)")
        
        // Try to get properties if available
        do {
            let props = try await wallet.properties()
            print("   Wallet network: \(props.network)")
            print("   Wallet fingerprint: \(props.fingerprint)")
        } catch {
            print("   ⚠️ Could not get wallet properties: \(error)")
        }
        
        // Check if arkInfo is available
        if let arkInfo = await wallet.arkInfo() {
            print("   ✅ Has server connection (arkInfo available)")
            print("      Round interval: \(arkInfo.roundIntervalSecs)s")
            print("      Server pubkey: \(String(arkInfo.serverPubkey.prefix(20)))...")
        } else {
            print("   ❌ No server connection (arkInfo returns nil)")
        }
        
        // Try to get balance (requires server connection)
        do {
            let balance = try await wallet.balance()
            print("   ✅ Can fetch balance (server accessible)")
            print("      Spendable: \(balance.spendableSats) sats")
        } catch {
            print("   ❌ Cannot fetch balance: \(error)")
        }
    }
    
    /// Convert our NetworkConfig networkType string to FFI Network enum
    static func convertToFFINetwork(_ networkType: String) -> Network? {
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
}
