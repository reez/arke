//
//  ContactService+StateManagement.swift
//  Arké
//
//  State management and error handling utilities
//

import Foundation

extension ContactService {
    
    /// Clear error state
    func clearError() {
        error = nil
    }
    
    /// Refresh contacts from storage
    func refreshContacts() async {
        await loadContacts()
    }
}
