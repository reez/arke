//
//  PaymentDestinationSelector.swift
//  Ark wallet prototype
//
//  Created by Assistant on 11/17/25.
//

import Foundation

/// Selects the optimal payment destination based on balances, fees, and user preferences
class PaymentDestinationSelector {
    
    // MARK: - Context
    
    /// Context information needed to make payment destination decisions
    struct PaymentContext {
        /// Ark balance in satoshis - used for both Ark and Lightning payments
        let arkBalance: Int?
        
        /// On-chain Bitcoin balance in satoshis
        let bitcoinBalance: Int?
        
        /// Current network configuration
        let networkConfig: NetworkConfig
        
        /// User's payment preferences
        let userPreferences: PaymentPreferences
        
        /// Whether the Ark server is currently reachable
        let arkServerConnected: Bool
        
        /// Whether the Ark server supports Lightning payments for this user
        let hasLightningCapability: Bool
        
        init(
            arkBalance: Int?,
            bitcoinBalance: Int?,
            networkConfig: NetworkConfig,
            userPreferences: PaymentPreferences = .default,
            arkServerConnected: Bool = true,
            hasLightningCapability: Bool = true
        ) {
            self.arkBalance = arkBalance
            self.bitcoinBalance = bitcoinBalance
            self.networkConfig = networkConfig
            self.userPreferences = userPreferences
            self.arkServerConnected = arkServerConnected
            self.hasLightningCapability = hasLightningCapability
        }
    }
    
    // MARK: - Preferences
    
    /// User preferences for payment destination selection
    struct PaymentPreferences {
        /// Default priority order optimized for lowest fees
        static let defaultPriority: [AddressFormat] = [
            .ark,              // Same server, instant, typically free
            .lightning,        // Fast, low fees (via Ark server using arkBalance)
            .lightningInvoice, // Fast, low fees (via Ark server using arkBalance)
            .silentPayments,   // On-chain with privacy
            .bitcoin,          // Standard on-chain
            .bip353,           // Resolves to another format
        ]
        
        /// Default preferences instance
        static let `default` = PaymentPreferences()
        
        /// Priority order for payment formats (first = highest priority)
        var priorityOrder: [AddressFormat]
        
        /// Prefer on-chain Bitcoin for large amounts even if other options available
        var preferOnChainForLargeAmounts: Bool
        
        /// Threshold in satoshis above which to prefer on-chain (if enabled)
        var largeAmountThreshold: Int
        
        /// Minimum Ark balance to keep in reserve (won't use if it would drain below this)
        var minimumArkReserve: Int
        
        init(
            priorityOrder: [AddressFormat] = defaultPriority,
            preferOnChainForLargeAmounts: Bool = false,
            largeAmountThreshold: Int = 1_000_000, // 1M sats = 0.01 BTC
            minimumArkReserve: Int = 10_000 // 10k sats reserve
        ) {
            self.priorityOrder = priorityOrder
            self.preferOnChainForLargeAmounts = preferOnChainForLargeAmounts
            self.largeAmountThreshold = largeAmountThreshold
            self.minimumArkReserve = minimumArkReserve
        }
    }
    
    // MARK: - Balance Source
    
    /// Indicates which balance would be used for a payment
    enum BalanceSource {
        case ark           // Direct Ark-to-Ark transfer using arkBalance
        case arkViaServer  // Lightning payment routed through Ark server using arkBalance
        case bitcoin       // On-chain Bitcoin payment using bitcoinBalance
        
        var displayName: String {
            switch self {
            case .ark:
                return "Ark Balance"
            case .arkViaServer:
                return "Ark Balance (via Lightning)"
            case .bitcoin:
                return "Bitcoin Balance"
            }
        }
    }
    
    // MARK: - Ranked Destination
    
    /// A payment destination with ranking and viability information
    struct RankedDestination {
        let destination: PaymentDestination
        let balanceSource: BalanceSource
        let availableBalance: Int?
        let estimatedFee: Int?
        let viable: Bool
        let reason: String
        let priority: Int // Lower number = higher priority
        
        var requiresServerRouting: Bool {
            balanceSource == .arkViaServer
        }
    }
    
    // MARK: - Main Selection Methods
    
    /// Selects the optimal payment destination from a payment request
    /// Returns nil if no destinations are viable
    static func selectOptimalDestination(
        from paymentRequest: PaymentRequest,
        context: PaymentContext
    ) -> PaymentDestination? {
        let ranked = rankDestinations(from: paymentRequest, context: context)
        return ranked.first(where: { $0.viable })?.destination
    }
    
    /// Ranks all destinations in a payment request by preference and viability
    /// Returns array ordered by priority (best first)
    static func rankDestinations(
        from paymentRequest: PaymentRequest,
        context: PaymentContext
    ) -> [RankedDestination] {
        print("🔍 [PaymentDestinationSelector] Starting rankDestinations")
        print("   Total destinations in request: \(paymentRequest.destinations.count)")
        for (index, dest) in paymentRequest.destinations.enumerated() {
            print("   [\(index)] \(dest.format.displayName) - \(dest.shortAddress)")
        }
        
        // Filter destinations to match network
        let networkCompatibleDestinations = paymentRequest.destinations.filter { destination in
            let isCompatible = destination.isCompatible(with: context.networkConfig)
            print("   🔍 Checking compatibility for \(destination.format.displayName):")
            print("      Destination network: \(destination.network?.displayName ?? "nil")")
            print("      Config network: \(context.networkConfig.networkType)")
            print("      Compatible: \(isCompatible)")
            return isCompatible
        }
        
        print("   Network compatible destinations: \(networkCompatibleDestinations.count)")
        for (index, dest) in networkCompatibleDestinations.enumerated() {
            print("   [\(index)] \(dest.format.displayName) - \(dest.shortAddress)")
        }
        
        // Rank each destination
        var rankedDestinations = networkCompatibleDestinations.compactMap { destination -> RankedDestination? in
            print("   🔄 Ranking: \(destination.format.displayName)")
            let ranked = rankDestination(destination, amount: paymentRequest.amount, context: context)
            if let ranked = ranked {
                print("      ✅ Ranked: viable=\(ranked.viable), priority=\(ranked.priority), reason=\(ranked.reason)")
            } else {
                print("      ❌ Ranking returned nil")
            }
            return ranked
        }
        
        print("   Ranked destinations before sort: \(rankedDestinations.count)")
        
        // Sort by priority (viable first, then by priority number)
        rankedDestinations.sort { lhs, rhs in
            if lhs.viable != rhs.viable {
                return lhs.viable // Viable destinations first
            }
            return lhs.priority < rhs.priority // Lower priority number = higher priority
        }
        
        print("   Ranked destinations after sort: \(rankedDestinations.count)")
        print("   Final order:")
        for (index, dest) in rankedDestinations.enumerated() {
            print("   [\(index)] \(dest.destination.format.displayName) - viable=\(dest.viable), priority=\(dest.priority)")
        }
        
        return rankedDestinations
    }
    
    /// Checks if a payment request can be fulfilled with any destination
    static func canFulfillPayment(
        _ paymentRequest: PaymentRequest,
        with context: PaymentContext
    ) -> (feasible: Bool, suggestedDestination: PaymentDestination?) {
        if let optimal = selectOptimalDestination(from: paymentRequest, context: context) {
            return (feasible: true, suggestedDestination: optimal)
        }
        return (feasible: false, suggestedDestination: nil)
    }
    
    // MARK: - Destination Analysis
    
    /// Ranks a single destination with viability and priority information
    private static func rankDestination(
        _ destination: PaymentDestination,
        amount: Int?,
        context: PaymentContext
    ) -> RankedDestination? {
        let balanceSource = balanceSource(for: destination)
        let availableBalance = availableBalance(for: destination, context: context)
        let estimatedFee = estimateFee(for: destination)
        let priority = priorityScore(for: destination.format, preferences: context.userPreferences)
        
        // Check viability
        let viabilityCheck = checkViability(
            destination: destination,
            amount: amount,
            availableBalance: availableBalance,
            balanceSource: balanceSource,
            context: context
        )
        
        return RankedDestination(
            destination: destination,
            balanceSource: balanceSource,
            availableBalance: availableBalance,
            estimatedFee: estimatedFee,
            viable: viabilityCheck.viable,
            reason: viabilityCheck.reason,
            priority: priority
        )
    }
    
    /// Checks if a destination is viable for payment
    private static func checkViability(
        destination: PaymentDestination,
        amount: Int?,
        availableBalance: Int?,
        balanceSource: BalanceSource,
        context: PaymentContext
    ) -> (viable: Bool, reason: String) {
        // Check server connectivity for Lightning payments
        if requiresServerRouting(destination) && !context.arkServerConnected {
            return (false, "Ark server not connected")
        }
        
        if requiresServerRouting(destination) && !context.hasLightningCapability {
            return (false, "Lightning not available")
        }
        
        // If no amount specified, all destinations are viable (amount will be entered later)
        guard let amount = amount else {
            return (true, "No amount specified")
        }
        
        // Check balance availability
        guard let balance = availableBalance else {
            return (false, "Balance unavailable")
        }
        
        // Check if balance is sufficient
        let estimatedFee = estimateFee(for: destination)
        let totalRequired = amount + estimatedFee
        
        // Special handling for Ark balance with reserve
        if balanceSource == .ark || balanceSource == .arkViaServer {
            let remainingAfterPayment = balance - totalRequired
            if remainingAfterPayment < context.userPreferences.minimumArkReserve {
                return (false, "Would drain below minimum Ark reserve")
            }
        }
        
        if balance < totalRequired {
            return (false, "Insufficient balance (\(balance) < \(totalRequired) sats)")
        }
        
        // Check large amount preference
        if context.userPreferences.preferOnChainForLargeAmounts &&
           amount >= context.userPreferences.largeAmountThreshold &&
           balanceSource != .bitcoin {
            // Deprioritize but don't make unviable
            return (true, "Large amount: on-chain preferred")
        }
        
        return (true, "Sufficient balance")
    }
    
    /// Determines priority score for a format (lower = higher priority)
    private static func priorityScore(for format: AddressFormat, preferences: PaymentPreferences) -> Int {
        if let index = preferences.priorityOrder.firstIndex(of: format) {
            return index
        }
        // Unknown formats get lowest priority
        return Int.max
    }
    
    // MARK: - Balance Helpers
    
    /// Determines which balance source a destination would use
    static func balanceSource(for destination: PaymentDestination) -> BalanceSource {
        switch destination.format {
        case .ark:
            return .ark
        case .lightning, .lightningInvoice:
            return .arkViaServer // Lightning uses Ark balance but routed through server
        case .bitcoin, .silentPayments:
            return .bitcoin
        case .bip353, .bip21:
            // These are wrapper formats that resolve to others
            // In practice, they should be resolved before reaching this point
            return .bitcoin // Default fallback
        }
    }
    
    /// Gets available balance for a specific destination
    static func availableBalance(
        for destination: PaymentDestination,
        context: PaymentContext
    ) -> Int? {
        switch balanceSource(for: destination) {
        case .ark, .arkViaServer:
            return context.arkBalance
        case .bitcoin:
            return context.bitcoinBalance
        }
    }
    
    /// Checks if a destination requires server routing
    static func requiresServerRouting(_ destination: PaymentDestination) -> Bool {
        return balanceSource(for: destination) == .arkViaServer
    }
    
    // MARK: - Fee Estimation
    
    /// Estimates fee for a destination (simplified, could be made more sophisticated)
    private static func estimateFee(for destination: PaymentDestination) -> Int {
        switch destination.format {
        case .ark:
            return 0 // Typically free for same-server transfers
        case .lightning, .lightningInvoice:
            return 100 // Small Lightning routing fee estimate (1 sat base + ppm)
        case .bitcoin:
            return 500 // Rough on-chain fee estimate (could be dynamic based on mempool)
        case .silentPayments:
            return 600 // Slightly higher due to additional outputs
        case .bip353, .bip21:
            return 0 // Wrapper formats
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Gets all viable destinations from a payment request
    static func viableDestinations(
        from paymentRequest: PaymentRequest,
        context: PaymentContext
    ) -> [PaymentDestination] {
        return rankDestinations(from: paymentRequest, context: context)
            .filter { $0.viable }
            .map { $0.destination }
    }
    
    /// Checks if a specific destination is viable for a payment
    static func isViable(
        destination: PaymentDestination,
        amount: Int?,
        context: PaymentContext
    ) -> Bool {
        guard let ranked = rankDestination(destination, amount: amount, context: context) else {
            return false
        }
        return ranked.viable
    }
    
    /// Gets a detailed viability report for debugging/UI
    static func viabilityReport(
        from paymentRequest: PaymentRequest,
        context: PaymentContext
    ) -> String {
        let ranked = rankDestinations(from: paymentRequest, context: context)
        var report = "Payment Destination Analysis:\n"
        report += "Amount: \(paymentRequest.amount.map { "\($0) sats" } ?? "Not specified")\n"
        report += "Ark Balance: \(context.arkBalance.map { "\($0) sats" } ?? "N/A")\n"
        report += "Bitcoin Balance: \(context.bitcoinBalance.map { "\($0) sats" } ?? "N/A")\n"
        report += "\nDestinations:\n"
        
        for (index, destination) in ranked.enumerated() {
            report += "\n\(index + 1). \(destination.destination.format.displayName)\n"
            report += "   Address: \(destination.destination.shortAddress)\n"
            report += "   Balance Source: \(destination.balanceSource.displayName)\n"
            report += "   Available: \(destination.availableBalance.map { "\($0) sats" } ?? "N/A")\n"
            report += "   Estimated Fee: \(destination.estimatedFee.map { "\($0) sats" } ?? "N/A")\n"
            report += "   Viable: \(destination.viable ? "✓" : "✗")\n"
            report += "   Reason: \(destination.reason)\n"
            report += "   Priority: #\(destination.priority + 1)\n"
        }
        
        return report
    }
}

// MARK: - PaymentRequest Extension

extension PaymentRequest {
    /// Convenience method to select optimal destination
    func selectOptimalDestination(context: PaymentDestinationSelector.PaymentContext) -> PaymentDestination? {
        return PaymentDestinationSelector.selectOptimalDestination(from: self, context: context)
    }
    
    /// Convenience method to get ranked destinations
    func rankedDestinations(context: PaymentDestinationSelector.PaymentContext) -> [PaymentDestinationSelector.RankedDestination] {
        return PaymentDestinationSelector.rankDestinations(from: self, context: context)
    }
    
    /// Convenience method to check viability
    func canFulfill(with context: PaymentDestinationSelector.PaymentContext) -> Bool {
        return PaymentDestinationSelector.canFulfillPayment(self, with: context).feasible
    }
}
