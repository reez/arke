//
//  ArkeTests.swift
//  ArkéTests
//
//  Unit tests for Arké
//

import Testing
import Foundation

@Suite("Basic Functionality Tests")
struct ArkeTests {
    
    @Test("Example test demonstrating basic assertion")
    func exampleTest() async throws {
        // Verify basic arithmetic works
        let result = 2 + 2
        #expect(result == 4)
    }
}
