//
//  BarkWalletFFI+WalletLifecycle.swift
//  Arke
//
//  Wallet lifecycle operations: open, close, shutdown
//  Handles wallet state management and cleanup
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension BarkWalletFFI {
    
    // MARK: - Wallet Opening
    
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
    
    // MARK: - Wallet Shutdown
    
    /// Explicitly shutdown and cleanup wallet resources
    /// Call this BEFORE deleting wallet files to ensure proper cleanup
    func shutdownWallet() async {
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
}
