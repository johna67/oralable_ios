//
//  Logger.swift
//  OralableApp
//
//  Centralized logging system with proper levels and performance optimization
//

import Foundation
import OSLog

/// Centralized logger with support for different log levels and conditional compilation
@MainActor
final class Logger {
    static let shared = Logger()

    // MARK: - Log Levels

    enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4

        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🔥"
            }
        }

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }

    // MARK: - Log Categories

    enum Category: String {
        case ble = "BLE"
        case sensor = "Sensor"
        case ui = "UI"
        case data = "Data"
        case network = "Network"
        case auth = "Auth"
        case general = "General"

        var osLogger: OSLog {
            OSLog(subsystem: "com.oralable.app", category: rawValue)
        }
    }

    // MARK: - Configuration

    #if DEBUG
    private var minimumLogLevel: LogLevel = .debug
    private var enableConsoleLogging = true
    #else
    private var minimumLogLevel: LogLevel = .info
    private var enableConsoleLogging = false
    #endif

    private var enableOSLog = true
    private var logToFile = false

    // MARK: - Log Storage

    private var logMessages: [LogMessage] = []
    private let maxLogMessages = 1000
    private let logQueue = DispatchQueue(label: "com.oralable.logging", qos: .background)

    // MARK: - Initialization

    private init() {
        // Private initializer for singleton
    }

    // MARK: - Configuration Methods

    func setMinimumLogLevel(_ level: LogLevel) {
        minimumLogLevel = level
    }

    func enableFileLogging(_ enabled: Bool) {
        logToFile = enabled
    }

    // MARK: - Logging Methods

    func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: Category = .general, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(level: .error, message: fullMessage, category: category, file: file, function: function, line: line)
    }

    func critical(_ message: String, category: Category = .general, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(level: .critical, message: fullMessage, category: category, file: file, function: function, line: line)
    }

    // MARK: - Core Logging

    private func log(level: LogLevel, message: String, category: Category, file: String, function: String, line: Int) {
        // Check if we should log this level
        guard level >= minimumLogLevel else { return }

        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "[\(category.rawValue)] \(message)"

        // Log to OSLog (always in production, optional in debug)
        if enableOSLog {
            logToOSLog(level: level, message: formattedMessage, category: category)
        }

        // Console logging (debug only by default)
        if enableConsoleLogging {
            logToConsole(level: level, message: formattedMessage, file: fileName, function: function, line: line)
        }

        // Store in memory for viewing in app
        storeLogMessage(level: level, message: formattedMessage, category: category, file: fileName, function: function, line: line)

        // Optional: Log to file
        if logToFile {
            logToFileAsync(level: level, message: formattedMessage, file: fileName, function: function, line: line)
        }
    }

    private func logToOSLog(level: LogLevel, message: String, category: Category) {
        let osLogger = category.osLogger
        os_log("%{public}@", log: osLogger, type: level.osLogType, message)
    }

    private func logToConsole(level: LogLevel, message: String, file: String, function: String, line: Int) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("\(level.emoji) [\(timestamp)] \(message) (\(file):\(line))")
    }

    private func storeLogMessage(level: LogLevel, message: String, category: Category, file: String, function: String, line: Int) {
        let logMessage = LogMessage(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line
        )

        // Use background queue to avoid blocking main thread
        logQueue.async { [weak self] in
            guard let self = self else { return }

            Task { @MainActor in
                self.logMessages.append(logMessage)

                // Keep only the most recent messages
                if self.logMessages.count > self.maxLogMessages {
                    self.logMessages.removeFirst(self.logMessages.count - self.maxLogMessages)
                }
            }
        }
    }

    private func logToFileAsync(level: LogLevel, message: String, file: String, function: String, line: Int) {
        logQueue.async {
            // Implement file logging if needed
            // This would write to a log file in the documents directory
        }
    }

    // MARK: - Log Retrieval

    func getRecentLogs(limit: Int = 100, minimumLevel: LogLevel? = nil) -> [LogMessage] {
        var filteredLogs = logMessages

        if let minimumLevel = minimumLevel {
            filteredLogs = filteredLogs.filter { $0.level >= minimumLevel }
        }

        return Array(filteredLogs.suffix(limit))
    }

    func clearLogs() {
        logMessages.removeAll()
    }

    // MARK: - Performance Helpers

    /// Use this for logging in tight loops to avoid performance issues
    /// Only logs every nth call
    func logThrottled(_ message: String, level: LogLevel = .debug, category: Category = .general, key: String, interval: Int = 20) {
        // Use a static dictionary to track throttle counters
        struct ThrottleState {
            static var counters: [String: Int] = [:]
        }

        ThrottleState.counters[key, default: 0] += 1

        guard ThrottleState.counters[key]! % interval == 0 else { return }

        log(level: level, message: "\(message) [logged every \(interval) calls]", category: category, file: "", function: "", line: 0)
    }

    /// Measures and logs execution time of a block
    func measure<T>(_ label: String, category: Category = .general, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        info("⏱️ \(label) took \(String(format: "%.3f", elapsed))s", category: category)

        return result
    }

    /// Async version of measure
    func measureAsync<T>(_ label: String, category: Category = .general, block: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        info("⏱️ \(label) took \(String(format: "%.3f", elapsed))s", category: category)

        return result
    }
}

// MARK: - LogMessage Model

struct LogMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: Logger.LogLevel
    let category: Logger.Category
    let message: String
    let file: String
    let function: String
    let line: Int

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var fullDescription: String {
        "\(level.emoji) [\(formattedTimestamp)] [\(category.rawValue)] \(message)"
    }
}

// MARK: - Global Convenience Functions

/// Global logging functions for convenience
func logDebug(_ message: String, category: Logger.Category = .general) {
    Logger.shared.debug(message, category: category)
}

func logInfo(_ message: String, category: Logger.Category = .general) {
    Logger.shared.info(message, category: category)
}

func logWarning(_ message: String, category: Logger.Category = .general) {
    Logger.shared.warning(message, category: category)
}

func logError(_ message: String, error: Error? = nil, category: Logger.Category = .general) {
    Logger.shared.error(message, category: category, error: error)
}

func logCritical(_ message: String, error: Error? = nil, category: Logger.Category = .general) {
    Logger.shared.critical(message, category: category, error: error)
}

// MARK: - Example Usage
/*
 // Basic logging
 logDebug("BLE scan started", category: .ble)
 logInfo("User authenticated successfully", category: .auth)
 logWarning("Low battery detected", category: .sensor)
 logError("Failed to connect to device", error: someError, category: .ble)

 // Throttled logging (for tight loops)
 Logger.shared.logThrottled("PPG packet received", category: .sensor, key: "ppg_packets", interval: 20)

 // Performance measurement
 Logger.shared.measure("Heart rate calculation", category: .sensor) {
     calculateHeartRate()
 }

 // Async measurement
 await Logger.shared.measureAsync("Fetch historical data", category: .data) {
     await fetchHistoricalData()
 }
 */
