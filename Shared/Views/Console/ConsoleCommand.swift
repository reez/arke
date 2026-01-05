//
//  ConsoleCommand.swift
//  Ark wallet prototype
//
//  Created by Christoph on 1/5/26.
//

import Foundation

/// Parameter definition for a console command
struct CommandParameter {
    let name: String
    let type: ParameterType
    let description: String
    let isRequired: Bool
    let defaultValue: String?
    
    enum ParameterType: String {
        case string
        case integer
        case double
        case boolean
        case address  // Special type for blockchain addresses
        case hex      // Special type for hex strings
        
        var displayName: String {
            switch self {
            case .address: return "address"
            case .hex: return "hex"
            default: return rawValue
            }
        }
    }
    
    init(name: String, type: ParameterType, description: String, isRequired: Bool = true, defaultValue: String? = nil) {
        self.name = name
        self.type = type
        self.description = description
        self.isRequired = isRequired
        self.defaultValue = defaultValue
    }
}

/// Context passed to commands for execution
struct CommandContext {
    let walletManager: WalletManager
    // Add other dependencies here as needed
}

/// Protocol that all console commands must implement
protocol ConsoleCommand {
    var name: String { get }
    var aliases: [String] { get }
    var usage: String { get }
    var description: String { get }
    var parameters: [CommandParameter] { get }
    var examples: [String] { get }
    
    func execute(args: ParsedArguments, context: CommandContext) async throws -> String
}

/// Parsed command arguments
struct ParsedArguments {
    private var positional: [String] = []
    private var named: [String: String] = [:]
    
    init(positional: [String] = [], named: [String: String] = [:]) {
        self.positional = positional
        self.named = named
    }
    
    // Access positional arguments by index
    func positional(at index: Int) -> String? {
        guard index < positional.count else { return nil }
        return positional[index]
    }
    
    func positionalCount() -> Int {
        return positional.count
    }
    
    // Access named arguments
    func named(_ key: String) -> String? {
        return named[key]
    }
    
    func hasNamed(_ key: String) -> Bool {
        return named[key] != nil
    }
    
    // Get all named argument keys
    func namedKeys() -> [String] {
        return Array(named.keys)
    }
    
    // Convenience accessors with type conversion
    func namedInt(_ key: String) throws -> Int? {
        guard let value = named[key] else { return nil }
        guard let intValue = Int(value) else {
            throw CommandError.invalidArgument("'\(key)' must be an integer, got: \(value)")
        }
        return intValue
    }
    
    func namedDouble(_ key: String) throws -> Double? {
        guard let value = named[key] else { return nil }
        guard let doubleValue = Double(value) else {
            throw CommandError.invalidArgument("'\(key)' must be a number, got: \(value)")
        }
        return doubleValue
    }
    
    func namedBool(_ key: String) -> Bool? {
        guard let value = named[key] else { return nil }
        let lowercased = value.lowercased()
        if ["true", "yes", "1", "on"].contains(lowercased) { return true }
        if ["false", "no", "0", "off"].contains(lowercased) { return false }
        return nil
    }
    
    mutating func addPositional(_ arg: String) {
        positional.append(arg)
    }
    
    mutating func addNamed(_ key: String, value: String) {
        named[key] = value
    }
}

/// Errors that can occur during command execution
enum CommandError: LocalizedError {
    case unknownCommand(String)
    case invalidSyntax(String)
    case invalidArgument(String)
    case missingRequiredParameter(String)
    case tooManyArguments
    case tooFewArguments
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unknownCommand(let cmd):
            return "Unknown command: '\(cmd)'. Type 'help' to see available commands."
        case .invalidSyntax(let msg):
            return "Invalid syntax: \(msg)"
        case .invalidArgument(let msg):
            return "Invalid argument: \(msg)"
        case .missingRequiredParameter(let param):
            return "Missing required parameter: \(param)"
        case .tooManyArguments:
            return "Too many arguments provided"
        case .tooFewArguments:
            return "Too few arguments provided"
        case .executionFailed(let msg):
            return "Execution failed: \(msg)"
        }
    }
}

// Default implementations for convenience
extension ConsoleCommand {
    var aliases: [String] { [] }
    var examples: [String] { [] }
    
    // Generate usage string from parameters
    var generatedUsage: String {
        var parts = [name]
        
        for param in parameters {
            if param.isRequired {
                parts.append("--\(param.name) <\(param.type.displayName)>")
            } else {
                parts.append("[--\(param.name) <\(param.type.displayName)>]")
            }
        }
        
        return parts.joined(separator: " ")
    }
}
