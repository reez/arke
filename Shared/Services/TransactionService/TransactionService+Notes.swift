//
//  TransactionService+Notes.swift
//  Arke
//
//  Transaction notes management.
//  Handles updating, searching, and validating transaction notes.
//

import Foundation
import SwiftData
import ArkeUI
import OSLog

// MARK: - TransactionService+Notes

extension TransactionService {
    
    // MARK: Public Methods
    
    /// Update notes for a transaction
    /// - Parameters:
    ///   - txid: The transaction ID to update
    ///   - notes: The notes text to set (nil to clear notes, empty strings are converted to nil)
    /// - Throws: TransactionServiceError if validation fails or transaction not found
    func updateNotes(for txid: String, notes: String?) async throws {
        guard let modelContext = modelContext else {
            throw TransactionServiceError.noModelContext
        }
        
        // Validate and sanitize notes
        let sanitizedNotes = try Self.validateAndSanitizeNotes(notes)
        
        // Find the transaction
        let descriptor = FetchDescriptor<PersistentTransaction>(
            predicate: #Predicate<PersistentTransaction> { transaction in
                transaction.txid == txid
            }
        )
        
        let transactions = try modelContext.fetch(descriptor)
        
        guard let transaction = transactions.first else {
            throw TransactionServiceError.transactionNotFound(txid: txid)
        }
        
        // Update the notes
        transaction.notes = sanitizedNotes
        
        // Save changes
        try modelContext.save()
        
        if let sanitizedNotes = sanitizedNotes {
            Self.logger.info("Updated notes for transaction \(txid): \"\(sanitizedNotes.prefix(50))...\"")
        } else {
            Self.logger.info("Cleared notes for transaction \(txid)")
        }
    }
    
    /// Search transactions by notes content
    /// - Parameter query: The search query string
    /// - Returns: Array of transactions whose notes contain the query string (case-insensitive)
    func searchTransactionsByNotes(query: String) async throws -> [TransactionModel] {
        guard let modelContext = modelContext else {
            throw TransactionServiceError.noModelContext
        }
        
        // Normalize query for case-insensitive search
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !normalizedQuery.isEmpty else {
            return []
        }
        
        // Fetch all transactions with notes
        let descriptor = FetchDescriptor<PersistentTransaction>(
            predicate: #Predicate<PersistentTransaction> { transaction in
                transaction.notes != nil
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let transactions = try modelContext.fetch(descriptor)
        
        // Filter by query (case-insensitive)
        let matchingTransactions = transactions.filter { transaction in
            guard let notes = transaction.notes else { return false }
            return notes.lowercased().contains(normalizedQuery)
        }
        
        Self.logger.info("Found \(matchingTransactions.count) transactions matching notes query: \"\(query)\"")
        
        return matchingTransactions.map { TransactionModel(from: $0) }
    }
    
    // MARK: Private Helpers
    
    /// Validate and sanitize notes text
    /// - Parameter notes: The raw notes text
    /// - Returns: Sanitized notes (nil if empty after trimming)
    /// - Throws: TransactionServiceError.notesTooLong if exceeds character limit
    private static func validateAndSanitizeNotes(_ notes: String?) throws -> String? {
        guard let notes = notes else {
            return nil
        }
        
        // Trim whitespace
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty after trimming? Return nil
        if trimmed.isEmpty {
            return nil
        }
        
        // Check character limit
        if trimmed.count > 1000 {
            throw TransactionServiceError.notesTooLong(count: trimmed.count, limit: 1000)
        }
        
        return trimmed
    }
}
