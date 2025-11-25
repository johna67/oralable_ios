//
//  LogMessage.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Simple log message model for system logs
//

import Foundation

/// Represents a log message in the system
struct LogMessage: Identifiable {
    let id: UUID
    let message: String
    let timestamp: Date
    
    init(id: UUID = UUID(), message: String, timestamp: Date = Date()) {
        self.id = id
        self.message = message
        self.timestamp = timestamp
    }
}
