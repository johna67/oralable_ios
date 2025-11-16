//
//  LogMessage.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Simple log message model for BLE logs
//

import Foundation

/// Represents a simple BLE log message
struct BLELogMessage: Identifiable {
    let id: UUID
    let message: String
    let timestamp: Date
    
    init(id: UUID = UUID(), message: String, timestamp: Date = Date()) {
        self.id = id
        self.message = message
        self.timestamp = timestamp
    }
}
