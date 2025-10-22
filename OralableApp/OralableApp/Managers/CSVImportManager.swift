import Foundation
import UniformTypeIdentifiers

/// Manager for importing CSV data files in Viewer Mode
class CSVImportManager {
    static let shared = CSVImportManager()
    
    private init() {}
    
    /// Import historical data from a CSV file
    /// - Parameter url: URL of the CSV file
    /// - Returns: Array of SensorData or nil if parsing fails
    func importCSV(from url: URL) -> (data: [SensorData], logs: [String])? {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security scoped resource")
            return nil
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            return parseCSV(csvString)
        } catch {
            print("Error reading CSV file: \(error)")
            return nil
        }
    }
    
    /// Parse CSV string into SensorData array and logs
    /// - Parameter csvString: CSV content as string
    /// - Returns: Tuple of parsed data and logs
    private func parseCSV(_ csvString: String) -> (data: [SensorData], logs: [String])? {
        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        guard lines.count > 1 else {
            print("CSV file is empty or has no data rows")
            return nil
        }
        
        // Parse header to find column indices
        let header = lines[0].components(separatedBy: ",")
        guard let columnIndices = parseHeader(header) else {
            print("Invalid CSV header format")
            return nil
        }
        
        var sensorDataArray: [SensorData] = []
        var logs: [String] = []
        
        // Parse data rows (skip header)
        for (index, line) in lines.dropFirst().enumerated() {
            let values = parseCSVLine(line)
            
            if let sensorData = parseSensorDataRow(values, columnIndices: columnIndices) {
                sensorDataArray.append(sensorData)
            }
            
            // Extract log message if present
            if let messageIndex = columnIndices["Message"],
               messageIndex < values.count {
                let message = values[messageIndex].trimmingCharacters(in: .whitespaces)
                if !message.isEmpty && message != "\"\"" {
                    logs.append(message.replacingOccurrences(of: "\"", with: ""))
                }
            }
        }
        
        print("Successfully imported \(sensorDataArray.count) data points and \(logs.count) log entries")
        return (sensorDataArray, logs)
    }
    
    /// Parse CSV header to find column indices
    private func parseHeader(_ header: [String]) -> [String: Int]? {
        var indices: [String: Int] = [:]
        
        for (index, column) in header.enumerated() {
            let trimmed = column.trimmingCharacters(in: .whitespaces)
            indices[trimmed] = index
        }
        
        // Verify required columns exist
        let requiredColumns = ["Timestamp", "PPG_IR", "PPG_Red", "PPG_Green",
                              "Accel_X", "Accel_Y", "Accel_Z", "Temp_C",
                              "Battery_mV", "Battery_%"]
        
        for column in requiredColumns {
            if indices[column] == nil {
                print("Missing required column: \(column)")
                return nil
            }
        }
        
        return indices
    }
    
    /// Parse a single CSV line handling quoted values
    private func parseCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                values.append(currentValue)
                currentValue = ""
            } else {
                currentValue.append(char)
            }
        }
        values.append(currentValue)
        
        return values
    }
    
    /// Parse a single data row into SensorData
    private func parseSensorDataRow(_ values: [String], columnIndices: [String: Int]) -> SensorData? {
        guard values.count >= columnIndices.count else {
            return nil
        }
        
        var sensorData = SensorData()
        
        // Parse timestamp
        if let timestampIndex = columnIndices["Timestamp"],
           timestampIndex < values.count {
            let timestampString = values[timestampIndex].trimmingCharacters(in: .whitespaces)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            if let date = dateFormatter.date(from: timestampString) {
                sensorData.timestamp = date
            }
        }
        
        // Parse PPG data
        if let irIndex = columnIndices["PPG_IR"],
           let redIndex = columnIndices["PPG_Red"],
           let greenIndex = columnIndices["PPG_Green"],
           irIndex < values.count,
           redIndex < values.count,
           greenIndex < values.count {
            
            let ppgSample = PPGSample(
                red: UInt32(values[redIndex].trimmingCharacters(in: .whitespaces)) ?? 0,
                ir: UInt32(values[irIndex].trimmingCharacters(in: .whitespaces)) ?? 0,
                green: UInt32(values[greenIndex].trimmingCharacters(in: .whitespaces)) ?? 0,
                timestamp: sensorData.timestamp
            )
            sensorData.ppg.samples = [ppgSample]
        }
        
        // Parse accelerometer data
        if let xIndex = columnIndices["Accel_X"],
           let yIndex = columnIndices["Accel_Y"],
           let zIndex = columnIndices["Accel_Z"],
           xIndex < values.count,
           yIndex < values.count,
           zIndex < values.count {
            
            let sample = AccSample(
                x: Int16(values[xIndex].trimmingCharacters(in: .whitespaces)) ?? 0,
                y: Int16(values[yIndex].trimmingCharacters(in: .whitespaces)) ?? 0,
                z: Int16(values[zIndex].trimmingCharacters(in: .whitespaces)) ?? 0,
                timestamp: sensorData.timestamp
            )
            sensorData.accelerometer.samples = [sample]
        }
        
        // Parse temperature
        if let tempIndex = columnIndices["Temp_C"],
           tempIndex < values.count {
            sensorData.temperature = Double(values[tempIndex].trimmingCharacters(in: .whitespaces)) ?? 0.0
        }
        
        // Parse battery
        if let batteryIndex = columnIndices["Battery_mV"],
           batteryIndex < values.count {
            sensorData.batteryVoltage = Int32(values[batteryIndex].trimmingCharacters(in: .whitespaces)) ?? 0
        }
        
        // Parse activity level if present
        if let activityIndex = columnIndices["Activity"],
           activityIndex < values.count {
            sensorData.activityLevel = UInt8(values[activityIndex].trimmingCharacters(in: .whitespaces)) ?? 0
        }
        
        return sensorData
    }
    
    /// Get supported file types for import
    static var supportedTypes: [UTType] {
        return [.commaSeparatedText, .text, .plainText]
    }
}
