# Console Command System

This console system provides a structured way to expose FFI wallet functions as interactive commands.

## Architecture

### Core Components

1. **ConsoleCommand.swift** - Protocol definition, parameter types, and error handling
2. **CommandExecutor.swift** - Command registry, parser, and execution coordinator
3. **WalletCommands.swift** - Example wallet command implementations
4. **ConsoleView.swift** - UI that uses the command system

## Creating New Commands

To add a new command for your FFI functions:

```swift
struct MyCommand: ConsoleCommand {
    let name = "my-command"
    let aliases = ["mc", "cmd"]
    let description = "Brief description of what this does"
    let parameters = [
        CommandParameter(
            name: "paramName",
            type: .string,  // .string, .integer, .double, .boolean, .address, .hex
            description: "What this parameter does",
            isRequired: true,
            defaultValue: nil
        )
    ]
    let examples = [
        "my-command --paramName value"
    ]
    
    var usage: String {
        "my-command --paramName <value>"
    }
    
    func execute(args: ParsedArguments, context: CommandContext) async throws -> String {
        // Get parameters
        guard let param = args.named("paramName") else {
            throw CommandError.missingRequiredParameter("paramName")
        }
        
        // Call your FFI binding
        let result = try await context.walletManager.someFFIFunction(param)
        
        // Format and return the result
        return "Result: \(result)"
    }
}
```

Then register it in `WalletCommands.swift`:

```swift
func registerWalletCommands(_ executor: CommandExecutor) {
    executor.register([
        // ... existing commands
        MyCommand()
    ])
}
```

## Command Syntax

### Named Arguments
```
command --param1 value1 --param2 value2
```

### Short Flags
```
command -p value1 -q value2
```

### Quoted Values
```
command --message "This is a multi-word value"
```

### Boolean Flags
```
command --verbose  # equivalent to --verbose true
```

## Built-in Commands

- `help` - Show all available commands
- `help <command>` - Show detailed help for a specific command
- `clear` - Clear console history

## Parameter Types

- `.string` - Any text value
- `.integer` - Whole numbers
- `.double` - Decimal numbers
- `.boolean` - true/false values
- `.address` - Blockchain addresses
- `.hex` - Hexadecimal strings

## Error Handling

Commands can throw `CommandError` for common issues:
- `.unknownCommand(String)`
- `.invalidSyntax(String)`
- `.invalidArgument(String)`
- `.missingRequiredParameter(String)`
- `.tooManyArguments`
- `.tooFewArguments`
- `.executionFailed(String)`

## Accessing Arguments

In your command's `execute` method:

```swift
// Named arguments
let address = args.named("address")
let amount = try args.namedInt("amount")
let flag = args.namedBool("verbose") ?? false

// Positional arguments (if you support them)
let first = args.positional(at: 0)

// Check if argument exists
if args.hasNamed("optional-param") {
    // ...
}
```

## Next Steps

1. Look at the example commands in `WalletCommands.swift`
2. Replace the example implementations with your actual FFI calls
3. Add new commands for all your FFI functions
4. Update parameter validation as needed
5. Consider adding command-specific error handling for FFI errors

## Tips

- Use descriptive parameter names
- Provide helpful error messages
- Include usage examples
- Add aliases for frequently-used commands
- Format output clearly (use newlines and spacing)
- Consider using short flags (-a) for common parameters
