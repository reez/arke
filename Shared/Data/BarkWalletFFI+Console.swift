//
//  BarkWalletFFI+Console.swift
//  Arke
//
//  Created by Christoph on 4/20/26.
//

import Foundation
import Bark

extension BarkWalletFFI {
    
    func executeCustomCommand(_ commandString: String) async throws -> String {
        throw BarkWalletFFIError.notSupported("executeCustomCommand - FFI does not support arbitrary commands")
    }
    
    // MARK: - Internal Command Execution (placeholder for actual FFI calls)
    
    func executeCommand(_ args: [String]) async throws -> String {
        throw BarkWalletFFIError.notSupported("executeCommand - use specific FFI methods instead")
    }
}
