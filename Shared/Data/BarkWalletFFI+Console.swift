//
//  BarkWalletFFI+Console.swift
//  Arke
//
//  Command execution stubs (not supported)
//  Provides placeholders for console-style command execution
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension BarkWalletFFI {
    
    // MARK: - Command Execution (Not Supported)
    
    func executeCustomCommand(_ commandString: String) async throws -> String {
        throw BarkWalletFFIError.notSupported("executeCustomCommand - FFI does not support arbitrary commands")
    }
    
    func executeCommand(_ args: [String]) async throws -> String {
        throw BarkWalletFFIError.notSupported("executeCommand - use specific FFI methods instead")
    }
}
