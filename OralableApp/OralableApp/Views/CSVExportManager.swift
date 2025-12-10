import Foundation

// MARK: - CSV Export Manager

/// Manager for exporting sensor data and logs to CSV format
/// Only exports columns for metrics that have visible dashboard cards
class CSVExportManager: ObservableObject {
    static let shared = CSVExportManager()
    private let featureFlags = FeatureFlags.shared

    init() {}
    
    /// Export sensor data and logs to CSV file
    /// - Parameters:
    ///   - sensorData: Array of sensor data points
    ///   - logs: Array of log messages
    /// - Returns: URL of the exported CSV file, or nil if export fails
    func exportData(sensorData: [SensorData], logs: [String]) -> URL? {
        let csvContent = generateCSVContent(sensorData: sensorData, logs: logs)
        
        // Create filename with current timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "oralable_data_\(timestamp).csv"
        
        // Use the cache directory for temporary files that need to be shared
        // This is accessible by the share sheet and gets cleaned up automatically
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let exportDirectory = cacheDirectory.appendingPathComponent("Exports", isDirectory: true)
        
        // Create exports directory if it doesn't exist
        if !fileManager.fileExists(atPath: exportDirectory.path) {
            try? fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        }
        
        let fileURL = exportDirectory.appendingPathComponent(filename)
        
        do {
            // Remove existing file if present
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            
            // Write the CSV content
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            
            Logger.shared.info("[CSVExportManager] Successfully exported CSV to: \(fileURL.path)")
            return fileURL
        } catch {
            Logger.shared.error("[to write CSV file: \(error)")
            return nil
        }
    }
    
    /// Generate CSV content from sensor data and logs
    /// Only includes columns for metrics that have visible dashboard cards
    private func generateCSVContent(sensorData: [SensorData], logs: [String]) -> String {
        var csvLines: [String] = []

        // Get current feature flag settings for conditional columns
        let includeMovement = featureFlags.showMovementCard
        let includeTemperature = featureFlags.showTemperatureCard
        let includeHeartRate = featureFlags.showHeartRateCard
        let includeBattery = featureFlags.showBatteryCard
        let includeSpO2 = featureFlags.showSpO2Card

        // Build CSV Header based on enabled features
        var headerParts = ["Timestamp", "PPG_IR", "PPG_Red", "PPG_Green"]
        if includeMovement {
            headerParts.append(contentsOf: ["Accel_X", "Accel_Y", "Accel_Z"])
        }
        if includeTemperature {
            headerParts.append("Temp_C")
        }
        if includeBattery {
            headerParts.append("Battery_%")
        }
        if includeHeartRate {
            headerParts.append(contentsOf: ["HeartRate_BPM", "HeartRate_Quality"])
        }
        if includeSpO2 {
            headerParts.append(contentsOf: ["SpO2_%", "SpO2_Quality"])
        }
        headerParts.append("Message")

        csvLines.append(headerParts.joined(separator: ","))

        // Date formatter for timestamps
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Create a map of timestamps to log messages for efficient lookup
        var logMessagesByTimestamp: [String: String] = [:]
        for log in logs {
            let timestamp = dateFormatter.string(from: Date()) // In real scenario, logs would have timestamps
            logMessagesByTimestamp[timestamp] = log
        }

        // Export each sensor data point
        for data in sensorData {
            let timestampString = dateFormatter.string(from: data.timestamp)

            var row: [String] = []

            // Timestamp (always included)
            row.append(timestampString)

            // PPG Data (always included - core metric)
            row.append(String(data.ppg.ir))
            row.append(String(data.ppg.red))
            row.append(String(data.ppg.green))

            // Accelerometer Data (conditional)
            if includeMovement {
                row.append(String(data.accelerometer.x))
                row.append(String(data.accelerometer.y))
                row.append(String(data.accelerometer.z))
            }

            // Temperature Data (conditional)
            if includeTemperature {
                row.append(String(format: "%.2f", data.temperature.celsius))
            }

            // Battery Data (conditional)
            if includeBattery {
                row.append(String(data.battery.percentage))
            }

            // Heart Rate Data (conditional)
            if includeHeartRate {
                if let heartRate = data.heartRate {
                    row.append(String(format: "%.1f", heartRate.bpm))
                    row.append(String(format: "%.3f", heartRate.quality))
                } else {
                    row.append("")
                    row.append("")
                }
            }

            // SpO2 Data (conditional)
            if includeSpO2 {
                if let spo2 = data.spo2 {
                    row.append(String(format: "%.1f", spo2.percentage))
                    row.append(String(format: "%.3f", spo2.quality))
                } else {
                    row.append("")
                    row.append("")
                }
            }

            // Message (log entry for this timestamp if available)
            let message = logMessagesByTimestamp[timestampString] ?? ""
            row.append(escapeCSVField(message))

            csvLines.append(row.joined(separator: ","))
        }

        // If there are logs without corresponding sensor data, add them as separate rows
        let sensorTimestamps = Set(sensorData.map { dateFormatter.string(from: $0.timestamp) })

        // Calculate number of empty columns needed for log-only rows
        var emptyColumnCount = 3 // PPG columns
        if includeMovement { emptyColumnCount += 3 }
        if includeTemperature { emptyColumnCount += 1 }
        if includeBattery { emptyColumnCount += 1 }
        if includeHeartRate { emptyColumnCount += 2 }
        if includeSpO2 { emptyColumnCount += 2 }

        for log in logs {
            // For now, we'll add logs at the end with current timestamp
            // In a real implementation, logs would have their own timestamps
            let timestampString = dateFormatter.string(from: Date())

            if !sensorTimestamps.contains(timestampString) {
                var row: [String] = []

                // Timestamp
                row.append(timestampString)

                // Empty sensor data fields
                for _ in 0..<emptyColumnCount {
                    row.append("")
                }

                // Message
                row.append(escapeCSVField(log))

                csvLines.append(row.joined(separator: ","))
            }
        }

        return csvLines.joined(separator: "\n")
    }
    
    /// Escape CSV field by wrapping in quotes if it contains commas or quotes
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    /// Get estimated file size for export
    func estimateExportSize(sensorDataCount: Int, logCount: Int) -> String {
        // Rough estimation: each sensor data row is about 150 characters
        // Each log entry is about 100 characters on average
        let estimatedBytes = (sensorDataCount * 150) + (logCount * 100) + 200 // 200 for header
        
        return ByteCountFormatter.string(fromByteCount: Int64(estimatedBytes), countStyle: .file)
    }
    
    /// Get export summary information
    func getExportSummary(sensorData: [SensorData], logs: [String]) -> ExportSummary {
        let dateRange = getDateRange(from: sensorData)
        let estimatedSize = estimateExportSize(sensorDataCount: sensorData.count, logCount: logs.count)
        
        return ExportSummary(
            sensorDataCount: sensorData.count,
            logCount: logs.count,
            dateRange: dateRange,
            estimatedSize: estimatedSize
        )
    }
    
    /// Get date range from sensor data
    private func getDateRange(from sensorData: [SensorData]) -> String {
        guard !sensorData.isEmpty else { return "No data" }
        
        let sortedData = sensorData.sorted { $0.timestamp < $1.timestamp }
        let startDate = sortedData.first!.timestamp
        let endDate = sortedData.last!.timestamp
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return dateFormatter.string(from: startDate)
        } else {
            return "\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))"
        }
    }
    
    /// Clean up old export files from the cache directory
    /// This helps manage disk space by removing temporary export files
    func cleanupOldExports() {
        let fileManager = FileManager.default
        guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }
        
        let exportDirectory = cacheDirectory.appendingPathComponent("Exports", isDirectory: true)
        
        guard fileManager.fileExists(atPath: exportDirectory.path) else {
            return
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: exportDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            // Remove files older than 24 hours
            let dayAgo = Date().addingTimeInterval(-24 * 60 * 60)
            
            for fileURL in fileURLs {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < dayAgo {
                    try? fileManager.removeItem(at: fileURL)
                    Logger.shared.debug("[CSVExportManager] Cleaned up old export file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            Logger.shared.error("[cleaning up exports: \(error)")
        }
    }
}