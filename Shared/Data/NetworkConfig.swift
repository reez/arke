import Foundation
import Combine

// MARK: - Bitcoin Network Types

enum BitcoinNetwork: String, CaseIterable, Codable {
    case mainnet = "mainnet"
    case testnet = "testnet"
    case signet = "signet"
    case regtest = "regtest"
    
    var displayName: String {
        switch self {
        case .mainnet:
            return "Bitcoin Mainnet"
        case .testnet:
            return "Bitcoin Testnet"
        case .signet:
            return "Bitcoin Signet"
        case .regtest:
            return "Bitcoin Regtest"
        }
    }
    
    /// Initialize from NetworkConfig networkType string
    init?(networkType: String) {
        switch networkType.lowercased() {
        case "mainnet":
            self = .mainnet
        case "testnet":
            self = .testnet
        case "signet":
            self = .signet
        case "regtest":
            self = .regtest
        default:
            return nil
        }
    }
    
    /// Check if this network matches a NetworkConfig
    func matches(_ networkConfig: NetworkConfig) -> Bool {
        return self.rawValue == networkConfig.networkType.lowercased()
    }
}

// MARK: - Network Configuration Models

struct NetworkConfig: Codable, Equatable {
    let id: String
    let name: String
    let esploraURL: String
    let arkServerURL: String
    let arkServerAccessToken: String?
    let isMainnet: Bool
    let networkType: String // "mainnet", "signet", "testnet", "custom"
    
    var esploraBaseURL: String {
        // Ensure URL has https:// prefix and no trailing slash
        let url = esploraURL.hasPrefix("http") ? esploraURL : "https://\(esploraURL)"
        return url.hasSuffix("/") ? String(url.dropLast()) : url
    }
    
    var arkServerBaseURL: String {
        // Ensure URL has https:// prefix and no trailing slash
        let url = arkServerURL.hasPrefix("http") ? arkServerURL : "https://\(arkServerURL)"
        return url.hasSuffix("/") ? String(url.dropLast()) : url
    }
}

// MARK: - Predefined Network Configurations

extension NetworkConfig {
    static let mainnet = NetworkConfig(
        id: "mainnet",
        name: "Bitcoin Mainnet",
        esploraURL: "mempool.second.tech/api",
        arkServerURL: "ark.second.tech",
        arkServerAccessToken: "CJLPDM807GWCYXAYW40TWL434MCKXI6O",
        isMainnet: true,
        networkType: "mainnet"
    )
    
    static let signet = NetworkConfig(
        id: "signet",
        name: "Bitcoin Signet",
        esploraURL: "esplora.signet.2nd.dev",
        arkServerURL: "ark.signet.2nd.dev",
        arkServerAccessToken: nil,
        isMainnet: false,
        networkType: "signet"
    )
    
    static let testnet = NetworkConfig(
        id: "testnet",
        name: "Bitcoin Testnet",
        esploraURL: "none_available", // Replace with actual esplore URL when available
        arkServerURL: "none_available", // Replace with actual testnet Ark server when available
        arkServerAccessToken: nil,
        isMainnet: false,
        networkType: "testnet"
    )
    
    static let defaultNetworks: [NetworkConfig] = [signet, testnet, mainnet]
    
    static func custom(name: String, esploraURL: String, arkServerURL: String, isMainnet: Bool, arkServerAccessToken: String? = nil) -> NetworkConfig {
        NetworkConfig(
            id: "custom_\(UUID().uuidString)",
            name: name,
            esploraURL: esploraURL,
            arkServerURL: arkServerURL,
            arkServerAccessToken: arkServerAccessToken,
            isMainnet: isMainnet,
            networkType: "custom"
        )
    }
}

// MARK: - Address Validation Integration

extension NetworkConfig {
    /// Get the corresponding BitcoinNetwork for address validation
    var bitcoinNetwork: BitcoinNetwork? {
        return BitcoinNetwork(networkType: networkType)
    }
    
    /// Validate a payment request against this network configuration
    func isValidPaymentRequest(_ input: String) -> Bool {
        return AddressValidator.isValidPaymentRequest(input, for: self)
    }
    
    /// Parse a payment request ensuring it matches this network
    func parsePaymentRequest(_ input: String) -> PaymentRequest? {
        return AddressValidator.parsePaymentRequest(input, expectedNetwork: self)
    }
}
