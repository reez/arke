//
//  SignetFaucetService.swift
//  Arké
//
//  Created by Assistant on 1/23/26.
//

import Foundation

// MARK: - Faucet Response Models

enum FaucetStatus: String, Codable {
    case success
    case failed
    case rateLimited = "rate_limited"
    case insufficientFunds = "insufficient_funds"
    case invalidAddress = "invalid_address"
    case error
}

struct SignetFaucetResponse: Codable {
    let status: String
    let message: String?
    let txid: String?
    let amount: Int?
    let retryAfter: Int? // Seconds until next allowed request
    
    enum CodingKeys: String, CodingKey {
        case status
        case message
        case txid
        case amount
        case retryAfter = "retry_after"
    }
    
    var parsedStatus: FaucetStatus {
        FaucetStatus(rawValue: status) ?? .error
    }
    
    var isSuccess: Bool {
        parsedStatus == .success
    }
    
    var retryAfterTimeInterval: TimeInterval? {
        guard let seconds = retryAfter else { return nil }
        return TimeInterval(seconds)
    }
}

// MARK: - Faucet Service

@Observable
@MainActor
class SignetFaucetService {
    
    // MARK: - Configuration
    
    /// Signet faucet endpoint (using mempool.space signet faucet)
    private let faucetURL = "https://arke.cash/api/faucetto"
    
    // Alternative faucet endpoints (if primary fails):
    // - https://signet.bc-2.jp/claim
    // - https://alt.signetfaucet.com/claim
    
    // MARK: - Dependencies
    
    private let urlSession: URLSession
    private let taskManager: TaskDeduplicationManager
    
    // MARK: - State
    
    var isRequesting = false
    var lastResponse: SignetFaucetResponse?
    var lastRequestDate: Date?
    
    // MARK: - Initialization
    
    init(taskManager: TaskDeduplicationManager, urlSession: URLSession = .shared) {
        self.taskManager = taskManager
        self.urlSession = urlSession
    }
    
    // MARK: - Public API
    
    /// Request signet bitcoin from the faucet
    /// - Parameter address: Bitcoin address to receive the testnet coins
    /// - Returns: Faucet response with status and details
    func requestFaucet(toAddress address: String) async throws -> SignetFaucetResponse {
        // Validate address format (basic check)
        guard !address.isEmpty else {
            throw FaucetError.invalidAddress("Address cannot be empty")
        }
        
        // Check if we're rate limited from previous request
        if let lastRequest = lastRequestDate,
           let retryAfter = lastResponse?.retryAfterTimeInterval {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < retryAfter {
                let remainingTime = Int(retryAfter - timeSinceLastRequest)
                throw FaucetError.rateLimited(remainingSeconds: remainingTime)
            }
        }
        
        isRequesting = true
        defer { isRequesting = false }
        
        print("🚰 [SignetFaucetService] Requesting faucet for address: \(address)")
        
        do {
            let response = try await performFaucetRequest(address: address)
            lastResponse = response
            lastRequestDate = Date()
            
            print("   ✅ Faucet response: \(response.status)")
            if let txid = response.txid {
                print("   📝 Transaction ID: \(txid)")
            }
            
            return response
        } catch let error as FaucetError {
            print("   ❌ Faucet error: \(error.localizedDescription)")
            throw error
        } catch {
            print("   ❌ Unexpected error: \(error.localizedDescription)")
            throw FaucetError.networkError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func performFaucetRequest(address: String) async throws -> SignetFaucetResponse {
        // Construct request
        guard let url = URL(string: faucetURL) else {
            throw FaucetError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        // Request body
        let requestBody: [String: Any] = [
            "address": address
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Perform request
        let (data, response) = try await urlSession.data(for: request)
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FaucetError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message from response
            if let errorResponse = try? JSONDecoder().decode(SignetFaucetResponse.self, from: data) {
                throw FaucetError.serverError(errorResponse.message ?? "HTTP \(httpResponse.statusCode)")
            }
            throw FaucetError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let faucetResponse = try decoder.decode(SignetFaucetResponse.self, from: data)
        
        // Check for application-level errors
        switch faucetResponse.parsedStatus {
        case .success:
            return faucetResponse
        case .rateLimited:
            throw FaucetError.rateLimited(remainingSeconds: faucetResponse.retryAfter ?? 3600)
        case .invalidAddress:
            throw FaucetError.invalidAddress(faucetResponse.message ?? "Invalid address format")
        case .insufficientFunds:
            throw FaucetError.insufficientFunds(faucetResponse.message ?? "Faucet is currently empty")
        case .failed, .error:
            throw FaucetError.serverError(faucetResponse.message ?? "Request failed")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Get remaining time before next request is allowed
    var remainingCooldownTime: TimeInterval? {
        guard let lastRequest = lastRequestDate,
              let retryAfter = lastResponse?.retryAfterTimeInterval else {
            return nil
        }
        
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
        let remaining = retryAfter - timeSinceLastRequest
        
        return remaining > 0 ? remaining : nil
    }
    
    /// Check if we can make a request right now
    var canMakeRequest: Bool {
        remainingCooldownTime == nil
    }
}

// MARK: - Faucet Errors

enum FaucetError: LocalizedError {
    case invalidAddress(String)
    case rateLimited(remainingSeconds: Int)
    case insufficientFunds(String)
    case serverError(String)
    case networkError(Error)
    case invalidResponse
    case invalidURL
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress(let message):
            return "Invalid Address: \(message)"
        case .rateLimited(let seconds):
            let minutes = seconds / 60
            if minutes > 0 {
                return "Rate Limited: Please wait \(minutes) minute\(minutes == 1 ? "" : "s") before trying again"
            } else {
                return "Rate Limited: Please wait \(seconds) second\(seconds == 1 ? "" : "s") before trying again"
            }
        case .insufficientFunds(let message):
            return "Faucet Empty: \(message)"
        case .serverError(let message):
            return "Server Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from faucet server"
        case .invalidURL:
            return "Invalid faucet URL configuration"
        case .httpError(let statusCode):
            return "HTTP Error: \(statusCode)"
        }
    }
}
