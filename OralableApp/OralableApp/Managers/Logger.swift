import Foundation

class Logger {
    static let shared = Logger()
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
        case success = "SUCCESS"
    }
    
    private var logs: [LogEntry] = []
    
    struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let message: String
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        logs.append(entry)
        
        #if DEBUG
        print("[\(level.rawValue)] \(message)")
        #endif
    }
    
    func getLogs() -> [LogEntry] {
        return logs
    }
    
    func clearLogs() {
        logs.removeAll()
    }
}
