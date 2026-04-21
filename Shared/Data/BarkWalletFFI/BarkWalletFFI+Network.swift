//
//  BarkWalletFFI+Network.swift
//  Arke
//
//  Network configuration and connectivity helpers
//  Provides network type, block height, and diagnostic utilities
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark
import Network
import os

extension BarkWalletFFI {
    
    // MARK: - Network Properties
    
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
            Self.logger.warning("MAINNET OPERATION - Real Bitcoin will be used!")
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
        
        Self.logger.debug("Fetching latest block height from esplora, URL: \(urlString)")
        
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
            
            Self.logger.info("Latest block height: \(height)")
            return height
            
        } catch {
            Self.logger.error("Error fetching block height: \(error)")
            throw BarkWalletFFIError.configurationError("Failed to fetch block height: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Network Diagnostics
    
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
            let logger = Self.logger
            
            monitor.pathUpdateHandler = { path in
                let statusString: String
                switch path.status {
                case .satisfied:
                    statusString = "satisfied"
                case .unsatisfied:
                    statusString = "unsatisfied"
                case .requiresConnection:
                    statusString = "requiresConnection"
                @unknown default:
                    statusString = "unknown"
                }
                
                var connectionType = ""
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        connectionType = "WiFi"
                    } else if path.usesInterfaceType(.cellular) {
                        connectionType = "Cellular"
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        connectionType = "Wired"
                    } else {
                        connectionType = "Other"
                    }
                    logger.debug("[DIAGNOSTIC] Network Status: \(statusString), Is Expensive: \(path.isExpensive), Is Constrained: \(path.isConstrained), Available Interfaces: \(path.availableInterfaces.map { $0.type }), Connection Type: \(connectionType)")
                } else {
                    logger.debug("[DIAGNOSTIC] Network Status: \(statusString), No network connection available")
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
                    logger.debug("[DIAGNOSTIC] Network status check timed out")
                    continuation.resume()
                }
            }
        }
    }
}
