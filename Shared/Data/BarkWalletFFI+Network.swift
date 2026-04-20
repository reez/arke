//
//  BarkWalletFFI+Network.swift
//  Arke
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark
import Network

extension BarkWalletFFI {
    
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
}
