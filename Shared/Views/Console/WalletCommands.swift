//
//  WalletCommands.swift
//  Ark wallet prototype
//
//  Created by Christoph on 1/5/26.
//

import Foundation

// MARK: - Example Wallet Commands
// These demonstrate how to wrap FFI functions as console commands
// Adjust these based on your actual FFI bindings

/// Get wallet balance
struct BalanceCommand: ConsoleCommand {
    let name = "balance"
    let aliases = ["bal", "b"]
    let description = "Get the balance of a wallet address"
    let parameters = [
        CommandParameter(
            name: "address",
            type: .address,
            description: "The wallet address to query",
            isRequired: false,
            defaultValue: "current wallet"
        )
    ]
    let examples = [
        "balance",
        "balance --address 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
    ]
    
    var usage: String {
        "balance [--address <address>]"
    }
    
    func execute(args: ParsedArguments, context: CommandContext) async throws -> String {
        let address = args.named("address") ?? args.named("a")
        
        // Call your FFI binding here
        // Example:
        // let balance = try await context.walletManager.getBalance(address: address)
        // return "Balance: \(balance) ARK"
        
        if let address = address {
            return "Balance for \(address): 100.50 ARK (example)"
        } else {
            return "Current wallet balance: 100.50 ARK (example)"
        }
    }
}

/// Send transaction
struct SendCommand: ConsoleCommand {
    let name = "send"
    let aliases = ["transfer", "tx"]
    let description = "Send tokens to an address"
    let parameters = [
        CommandParameter(
            name: "to",
            type: .address,
            description: "Recipient address"
        ),
        CommandParameter(
            name: "amount",
            type: .double,
            description: "Amount to send"
        ),
        CommandParameter(
            name: "memo",
            type: .string,
            description: "Optional transaction memo",
            isRequired: false
        )
    ]
    let examples = [
        "send --to 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb --amount 10.5",
        "send --to 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb --amount 10.5 --memo \"Payment for services\""
    ]
    
    var usage: String {
        "send --to <address> --amount <amount> [--memo <text>]"
    }
    
    func execute(args: ParsedArguments, context: CommandContext) async throws -> String {
        // Get required parameters
        guard let toAddress = args.named("to") ?? args.named("t") else {
            throw CommandError.missingRequiredParameter("to")
        }
        
        guard let amount = try args.namedDouble("amount") ?? args.namedDouble("a") else {
            throw CommandError.missingRequiredParameter("amount")
        }
        
        let memo = args.named("memo") ?? args.named("m")
        
        // Validate amount
        guard amount > 0 else {
            throw CommandError.invalidArgument("Amount must be greater than 0")
        }
        
        // Call your FFI binding here
        // Example:
        // let txHash = try await context.walletManager.sendTransaction(
        //     to: toAddress,
        //     amount: amount,
        //     memo: memo
        // )
        // return "Transaction sent! Hash: \(txHash)"
        
        var result = "Transaction sent!\n"
        result += "  To: \(toAddress)\n"
        result += "  Amount: \(amount) ARK\n"
        if let memo = memo {
            result += "  Memo: \(memo)\n"
        }
        result += "  Hash: 0xabcd1234... (example)"
        
        return result
    }
}

/// Get transaction details
struct TransactionCommand: ConsoleCommand {
    let name = "transaction"
    let aliases = ["tx-info", "txn"]
    let description = "Get details of a transaction by hash"
    let parameters = [
        CommandParameter(
            name: "hash",
            type: .hex,
            description: "Transaction hash"
        )
    ]
    let examples = [
        "transaction --hash 0xabcd1234567890..."
    ]
    
    var usage: String {
        "transaction --hash <hash>"
    }
    
    func execute(args: ParsedArguments, context: CommandContext) async throws -> String {
        guard let hash = args.named("hash") ?? args.named("h") else {
            throw CommandError.missingRequiredParameter("hash")
        }
        
        // Validate hash format (basic check)
        guard hash.hasPrefix("0x") || hash.count >= 10 else {
            throw CommandError.invalidArgument("Invalid transaction hash format")
        }
        
        // Call your FFI binding here
        // Example:
        // let txDetails = try await context.walletManager.getTransaction(hash: hash)
        // return formatTransaction(txDetails)
        
        var result = "Transaction Details:\n"
        result += "  Hash: \(hash)\n"
        result += "  Status: Confirmed\n"
        result += "  Block: 12345\n"
        result += "  From: 0x1111...\n"
        result += "  To: 0x2222...\n"
        result += "  Amount: 10.5 ARK\n"
        result += "  Fee: 0.001 ARK\n"
        result += "  Timestamp: 2026-01-05 10:30:00 (example)"
        
        return result
    }
}

/// Get wallet info
struct WalletInfoCommand: ConsoleCommand {
    let name = "wallet-info"
    let aliases = ["info", "wallet"]
    let description = "Display information about the current wallet"
    let parameters: [CommandParameter] = []
    let examples = [
        "wallet-info"
    ]
    
    var usage: String {
        "wallet-info"
    }
    
    func execute(args: ParsedArguments, context: CommandContext) async throws -> String {
        // Call your FFI binding here
        // Example:
        // let walletInfo = try await context.walletManager.getWalletInfo()
        // return formatWalletInfo(walletInfo)
        
        var result = "Wallet Information:\n"
        result += "  Address: 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb\n"
        result += "  Network: Mainnet\n"
        result += "  Balance: 100.50 ARK\n"
        result += "  Transaction Count: 42 (example)"
        
        return result
    }
}

/// List recent transactions
struct HistoryCommand: ConsoleCommand {
    let name = "history"
    let aliases = ["txs", "transactions"]
    let description = "List recent transactions"
    let parameters = [
        CommandParameter(
            name: "limit",
            type: .integer,
            description: "Maximum number of transactions to show",
            isRequired: false,
            defaultValue: "10"
        )
    ]
    let examples = [
        "history",
        "history --limit 20"
    ]
    
    var usage: String {
        "history [--limit <number>]"
    }
    
    func execute(args: ParsedArguments, context: CommandContext) async throws -> String {
        let limit = (try args.namedInt("limit") ?? args.namedInt("l")) ?? 10
        
        guard limit > 0 && limit <= 100 else {
            throw CommandError.invalidArgument("Limit must be between 1 and 100")
        }
        
        // Call your FFI binding here
        // Example:
        // let transactions = try await context.walletManager.getTransactionHistory(limit: limit)
        // return formatTransactionList(transactions)
        
        var result = "Recent Transactions (showing \(limit)):\n\n"
        
        for i in 1...min(limit, 3) {
            result += "[\(i)] 0xabcd\(i)234...\n"
            result += "    From: 0x1111... → To: 0x2222...\n"
            result += "    Amount: 10.5 ARK\n"
            result += "    Status: Confirmed\n\n"
        }
        
        return result
    }
}

// MARK: - Command Registration Helper

/// Register all wallet commands with the executor
func registerWalletCommands(_ executor: CommandExecutor) {
    executor.register([
        BalanceCommand(),
        SendCommand(),
        TransactionCommand(),
        WalletInfoCommand(),
        HistoryCommand()
    ])
}
