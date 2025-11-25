//
//  LogLevel.swift
//  OralableApp
//
//  Created by John A Cogan on 07/11/2025.
//


//
//  LogModels.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Shared log models to fix conflicts
//

import SwiftUI

// MARK: - Single LogLevel Definition (fixes ambiguity errors)
public enum LogLevel: String, CaseIterable, Codable {
    case all = "All"
    case error = "ERROR"
    case warning = "WARNING"
    case info = "INFO"
    case debug = "DEBUG"
    case utf8 = "UTF8"  // Add this if needed
    
    public var displayName: String {
        rawValue
    }
    
    public var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .error: return "exclamationmark.triangle"
        case .warning: return "exclamationmark.circle"
        case .info: return "info.circle"
        case .debug: return "ant.circle"
        case .utf8: return "doc.text"
        }
    }
    
    public var color: Color {
        switch self {
        case .all: return .gray
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .debug: return .purple
        case .utf8: return .green
        }
    }
}

// MARK: - LogEntry (Codable for CSVServiceProtocols)
public struct LogEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
    public let category: String
    public let details: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, timestamp, level, message, category, details
    }
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        message: String,
        category: String = "General",
        details: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.category = category
        self.details = details
    }
    
    public static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        lhs.id == rhs.id
    }
}
