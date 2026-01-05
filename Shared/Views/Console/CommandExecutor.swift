//
//  CommandExecutor.swift
//  Ark wallet prototype
//
//  Created by Christoph on 1/5/26.
//

import Foundation

/// Main coordinator for parsing and executing console commands
@Observable
class CommandExecutor {
    private var commands: [String: ConsoleCommand] = [:]
    private var aliases: [String: String] = [:]
    
    init() {
        registerBuiltInCommands()
    }
    
    /// Register a command
    func register(_ command: ConsoleCommand) {
        commands[command.name] = command
        
        // Register aliases
        for alias in command.aliases {
            aliases[alias] = command.name
        }
    }
    
    /// Register multiple commands at once
    func register(_ commands: [ConsoleCommand]) {
        for command in commands {
            register(command)
        }
    }
    
    /// Execute a command string
    func execute(_ input: String, context: CommandContext) async throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CommandError.invalidSyntax("Empty command")
        }
        
        // Parse the input
        let (commandName, args) = try parseInput(trimmed)
        
        // Resolve aliases
        let resolvedName = aliases[commandName] ?? commandName
        
        // Find the command
        guard let command = commands[resolvedName] else {
            throw CommandError.unknownCommand(commandName)
        }
        
        // Validate arguments against command parameters
        try validateArguments(args, against: command.parameters)
        
        // Execute the command
        return try await command.execute(args: args, context: context)
    }
    
    /// Get all registered commands (sorted by name)
    func allCommands() -> [ConsoleCommand] {
        return commands.values.sorted { $0.name < $1.name }
    }
    
    /// Get a specific command by name or alias
    func command(named name: String) -> ConsoleCommand? {
        let resolvedName = aliases[name] ?? name
        return commands[resolvedName]
    }
    
    /// Find commands matching a search term
    func search(_ term: String) -> [ConsoleCommand] {
        let lowercasedTerm = term.lowercased()
        return commands.values.filter { command in
            command.name.lowercased().contains(lowercasedTerm) ||
            command.description.lowercased().contains(lowercasedTerm) ||
            command.aliases.contains { $0.lowercased().contains(lowercasedTerm) }
        }.sorted { $0.name < $1.name }
    }
    
    // MARK: - Private Methods
    
    private func parseInput(_ input: String) throws -> (command: String, args: ParsedArguments) {
        var parts: [String] = []
        var currentPart = ""
        var inQuotes = false
        var escapeNext = false
        
        // Simple tokenizer that handles quotes and escaping
        for char in input {
            if escapeNext {
                currentPart.append(char)
                escapeNext = false
                continue
            }
            
            if char == "\\" {
                escapeNext = true
                continue
            }
            
            if char == "\"" {
                inQuotes.toggle()
                continue
            }
            
            if char.isWhitespace && !inQuotes {
                if !currentPart.isEmpty {
                    parts.append(currentPart)
                    currentPart = ""
                }
                continue
            }
            
            currentPart.append(char)
        }
        
        if !currentPart.isEmpty {
            parts.append(currentPart)
        }
        
        guard let commandName = parts.first else {
            throw CommandError.invalidSyntax("No command provided")
        }
        
        // Parse arguments (everything after the command)
        var args = ParsedArguments()
        var i = 1
        
        while i < parts.count {
            let part = parts[i]
            
            // Check if it's a named argument (starts with --)
            if part.hasPrefix("--") {
                let key = String(part.dropFirst(2))
                
                // Check if there's a value
                if i + 1 < parts.count && !parts[i + 1].hasPrefix("--") {
                    args.addNamed(key, value: parts[i + 1])
                    i += 2
                } else {
                    // Flag without value (treat as true)
                    args.addNamed(key, value: "true")
                    i += 1
                }
            } else if part.hasPrefix("-") && part.count == 2 {
                // Short flag (single character)
                let key = String(part.dropFirst(1))
                
                if i + 1 < parts.count && !parts[i + 1].hasPrefix("-") {
                    args.addNamed(key, value: parts[i + 1])
                    i += 2
                } else {
                    args.addNamed(key, value: "true")
                    i += 1
                }
            } else {
                // Positional argument
                args.addPositional(part)
                i += 1
            }
        }
        
        return (commandName, args)
    }
    
    private func validateArguments(_ args: ParsedArguments, against parameters: [CommandParameter]) throws {
        // Check for required parameters
        for param in parameters where param.isRequired {
            if args.named(param.name) == nil && args.named(String(param.name.prefix(1))) == nil {
                throw CommandError.missingRequiredParameter(param.name)
            }
        }
        
        // Check for unknown named arguments
        let validParamNames = Set(parameters.map { $0.name } + parameters.map { String($0.name.prefix(1)) })
        for key in args.namedKeys() {
            if !validParamNames.contains(key) {
                throw CommandError.invalidArgument("Unknown parameter: --\(key)")
            }
        }
    }
    
    private func registerBuiltInCommands() {
        register(HelpCommand(executor: self))
        register(ClearCommand())
    }
}

// MARK: - Built-in Commands

/// Help command to show available commands and usage
private struct HelpCommand: ConsoleCommand {
    let name = "help"
    let aliases = ["?", "h"]
    let usage = "help [command]"
    let description = "Show help information for commands"
    let parameters: [CommandParameter] = []
    let examples = [
        "help - Show all available commands",
        "help balance - Show detailed help for the balance command"
    ]
    
    weak var executor: CommandExecutor?
    
    init(executor: CommandExecutor) {
        self.executor = executor
    }
    
    func execute(args: ParsedArguments, context: CommandContext) async throws -> String {
        guard let executor = executor else {
            return "Help system unavailable"
        }
        
        // If a specific command is requested
        if let commandName = args.positional(at: 0) {
            guard let command = executor.command(named: commandName) else {
                throw CommandError.unknownCommand(commandName)
            }
            
            return formatDetailedHelp(for: command)
        }
        
        // Otherwise, show all commands
        return formatAllCommands(executor.allCommands())
    }
    
    private func formatAllCommands(_ commands: [ConsoleCommand]) -> String {
        var output = "Available Commands:\n\n"
        
        let maxNameLength = commands.map { $0.name.count }.max() ?? 0
        
        for command in commands {
            let padding = String(repeating: " ", count: maxNameLength - command.name.count + 2)
            output += "  \(command.name)\(padding)\(command.description)\n"
        }
        
        output += "\nType 'help <command>' for detailed information about a specific command."
        
        return output
    }
    
    private func formatDetailedHelp(for command: ConsoleCommand) -> String {
        var output = ""
        
        output += "Command: \(command.name)\n"
        
        if !command.aliases.isEmpty {
            output += "Aliases: \(command.aliases.joined(separator: ", "))\n"
        }
        
        output += "\nDescription:\n  \(command.description)\n"
        
        output += "\nUsage:\n  \(command.usage.isEmpty ? command.generatedUsage : command.usage)\n"
        
        if !command.parameters.isEmpty {
            output += "\nParameters:\n"
            for param in command.parameters {
                let required = param.isRequired ? "required" : "optional"
                output += "  --\(param.name) <\(param.type.displayName)> (\(required))\n"
                output += "    \(param.description)\n"
                if let defaultValue = param.defaultValue {
                    output += "    Default: \(defaultValue)\n"
                }
            }
        }
        
        if !command.examples.isEmpty {
            output += "\nExamples:\n"
            for example in command.examples {
                output += "  \(example)\n"
            }
        }
        
        return output
    }
}

/// Clear command to clear console history
private struct ClearCommand: ConsoleCommand {
    let name = "clear"
    let aliases = ["cls"]
    let usage = "clear"
    let description = "Clear the console history"
    let parameters: [CommandParameter] = []
    
    func execute(args: ParsedArguments, context: CommandContext) async throws -> String {
        // This is a special command that will be handled by ConsoleView
        return "__CLEAR__"
    }
}
