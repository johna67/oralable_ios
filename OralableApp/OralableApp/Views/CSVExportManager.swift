import Foundation

/// Manager for exporting sensor data and logs to CSV format
class CSVExportManager {
    static let shared = CSVExportManager()
    
    private init() {}
    
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
        
        // Get temporary directory URL
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            print("Successfully exported CSV to: \(tempURL.path)")
            return tempURL
        } catch {
            print("Failed to write CSV file: \(error)")
            return nil
        }
    }
    
    /// Generate CSV content from sensor data and logs
    private func generateCSVContent(sensorData: [SensorData], logs: [String]) -> String {
        var csvLines: [String] = []
        
        // CSV Header
        let header = [
            "Timestamp",
            "PPG_IR",
            "PPG_Red", 
            "PPG_Green",
            "Accel_X",
            "Accel_Y", 
            "Accel_Z",
            "Temp_C",
            "Battery_%",
            "HeartRate_BPM",
            "HeartRate_Quality",
            "SpO2_%",
            "SpO2_Quality",
            "Message"
        ].joined(separator: ",")
        
        csvLines.append(header)
        
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
            
            // Timestamp
            row.append(timestampString)
            
            // PPG Data
            row.append(String(data.ppg.ir))
            row.append(String(data.ppg.red))
            row.append(String(data.ppg.green))
            
            // Accelerometer Data
            row.append(String(data.accelerometer.x))
            row.append(String(data.accelerometer.y))
            row.append(String(data.accelerometer.z))
            
            // Temperature Data
            row.append(String(format: "%.2f", data.temperature.celsius))
            
            // Battery Data
            row.append(String(data.battery.percentage))
            
            // Heart Rate Data
            if let heartRate = data.heartRate {
                row.append(String(format: "%.1f", heartRate.bpm))
                row.append(String(format: "%.3f", heartRate.quality))
            } else {
                row.append("")
                row.append("")
            }
            
            // SpO2 Data
            if let spo2 = data.spo2 {
                row.append(String(format: "%.1f", spo2.percentage))
                row.append(String(format: "%.3f", spo2.quality))
            } else {
                row.append("")
                row.append("")
            }
            
            // Message (log entry for this timestamp if available)
            let message = logMessagesByTimestamp[timestampString] ?? ""
            row.append(escapeCSVField(message))
            
            csvLines.append(row.joined(separator: ","))
        }
        
        // If there are logs without corresponding sensor data, add them as separate rows
        let sensorTimestamps = Set(sensorData.map { dateFormatter.string(from: $0.timestamp) })
        
        for log in logs {
            // For now, we'll add logs at the end with current timestamp
            // In a real implementation, logs would have their own timestamps
            let timestampString = dateFormatter.string(from: Date())
            
            if !sensorTimestamps.contains(timestampString) {
                var row: [String] = []
                
                // Timestamp
                row.append(timestampString)
                
                // Empty sensor data fields
                for _ in 1...12 { // All sensor fields
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
}