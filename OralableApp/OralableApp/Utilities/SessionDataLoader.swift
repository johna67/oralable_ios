//
//  SessionDataLoader.swift
//  OralableApp
//
//  Created: December 7, 2025
//  Updated: December 8, 2025 - Added support for ShareView export files
//  Updated: December 8, 2025 - Fixed movement chart g-unit conversion
//  Purpose: Load and parse recorded session data from CSV files
//

import Foundation

/// Utility to load recorded session data from CSV files
class SessionDataLoader {
    
    // MARK: - Singleton
    static let shared = SessionDataLoader()
    private init() {}
    
    // MARK: - Constants
    
    /// LIS2DTW12 accelerometer conversion factor (±2g range, 14-bit resolution)
    /// 1g = 16384 LSB
    private let accelLSBPerG: Double = 16384.0
    
    // MARK: - Export File Info
    
    /// Information about a ShareView export file
    struct ExportFileInfo {
        let url: URL
        let creationDate: Date
        let fileSize: Int64
    }
    
    // MARK: - Public Methods - ShareView Exports
    
    /// Load historical data points from the most recent ShareView export
    /// - Parameter metricType: Filter by metric type ("EMG Activity", "IR Activity", "Movement", "Temperature")
    /// - Returns: Array of HistoricalDataPoint objects for charting
    func loadFromMostRecentExport(metricType: String) -> [HistoricalDataPoint] {
        guard let exportFile = getMostRecentExportFile() else {
            Logger.shared.info("[SessionDataLoader] No export files found")
            return []
        }
        
        Logger.shared.info("[SessionDataLoader] Loading from export: \(exportFile.url.lastPathComponent) for metric: \(metricType)")
        return loadFromExportFile(at: exportFile.url, metricType: metricType)
    }
    
    /// Load historical data points from a specific export file
    /// - Parameters:
    ///   - url: URL to the export CSV file
    ///   - metricType: Filter by metric type
    /// - Returns: Array of HistoricalDataPoint objects
    func loadFromExportFile(at url: URL, metricType: String) -> [HistoricalDataPoint] {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let readings = parseShareViewExport(content: content, metricType: metricType)
            Logger.shared.info("[SessionDataLoader] ✅ Loaded \(readings.count) data points for \(metricType)")
            return readings
        } catch {
            Logger.shared.error("[SessionDataLoader] ❌ Failed to load export file: \(error)")
            return []
        }
    }
    
    /// Get the most recent ShareView export file
    /// - Returns: ExportFileInfo for the most recent export, or nil
    func getMostRecentExportFile() -> ExportFileInfo? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            // Find CSV files that match the export pattern
            let csvFiles = files.filter { url in
                url.pathExtension == "csv" && url.lastPathComponent.hasPrefix("oralable_data_")
            }
            
            // Get file info and sort by creation date
            let fileInfos: [ExportFileInfo] = csvFiles.compactMap { url in
                guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                      let creationDate = resourceValues.creationDate,
                      let fileSize = resourceValues.fileSize else {
                    return nil
                }
                return ExportFileInfo(url: url, creationDate: creationDate, fileSize: Int64(fileSize))
            }
            
            // Return most recent
            return fileInfos.sorted { $0.creationDate > $1.creationDate }.first
            
        } catch {
            Logger.shared.error("[SessionDataLoader] Failed to list documents: \(error)")
            return nil
        }
    }
    
    /// Get all ShareView export files
    /// - Returns: Array of ExportFileInfo sorted by date (newest first)
    func getAllExportFiles() -> [ExportFileInfo] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            let csvFiles = files.filter { url in
                url.pathExtension == "csv" && url.lastPathComponent.hasPrefix("oralable_data_")
            }
            
            let fileInfos: [ExportFileInfo] = csvFiles.compactMap { url in
                guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                      let creationDate = resourceValues.creationDate,
                      let fileSize = resourceValues.fileSize else {
                    return nil
                }
                return ExportFileInfo(url: url, creationDate: creationDate, fileSize: Int64(fileSize))
            }
            
            return fileInfos.sorted { $0.creationDate > $1.creationDate }
            
        } catch {
            Logger.shared.error("[SessionDataLoader] Failed to list exports: \(error)")
            return []
        }
    }
    
    // MARK: - Public Methods - Recording Sessions (Legacy)
    
    /// Load sensor data from a session's CSV file and convert to HistoricalDataPoints
    func loadHistoricalDataPoints(from session: RecordingSession, metricType: String) -> [HistoricalDataPoint] {
        guard let filePath = session.dataFilePath else {
            Logger.shared.warning("[SessionDataLoader] No file path for session: \(session.id)")
            return []
        }
        
        let rawReadings = loadSessionCSVFile(at: filePath)
        return aggregateToHistoricalDataPoints(readings: rawReadings, metricType: metricType, deviceType: session.deviceType)
    }
    
    /// Get the most recent completed session
    func getMostRecentCompletedSession(from sessions: [RecordingSession]) -> RecordingSession? {
        return sessions
            .filter { $0.status == .completed && $0.dataFilePath != nil }
            .sorted { $0.startTime > $1.startTime }
            .first
    }
    
    /// Get the most recent completed session for a specific device type
    func getMostRecentCompletedSession(from sessions: [RecordingSession], deviceType: DeviceType) -> RecordingSession? {
        return sessions
            .filter { $0.status == .completed && $0.dataFilePath != nil && $0.deviceType == deviceType }
            .sorted { $0.startTime > $1.startTime }
            .first
    }
    
    // MARK: - Private Methods - ShareView Export Parsing
    
    /// Parse ShareView export CSV format
    /// Header: Timestamp,Device_Type,EMG,PPG_IR,PPG_Red,PPG_Green,Accel_X,Accel_Y,Accel_Z,Temperature,Battery,Heart_Rate
    private func parseShareViewExport(content: String, metricType: String) -> [HistoricalDataPoint] {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else {
            Logger.shared.warning("[SessionDataLoader] Empty CSV file")
            return []
        }
        
        // Verify header
        let header = lines[0].lowercased()
        guard header.contains("device_type") && header.contains("timestamp") else {
            Logger.shared.warning("[SessionDataLoader] Invalid export format - missing expected headers")
            return []
        }
        
        Logger.shared.info("[SessionDataLoader] 📄 Parsing \(lines.count - 1) CSV rows for metric: \(metricType)")
        
        // Determine which device type to filter for based on metric
        let targetDeviceType: String?
        switch metricType {
        case "EMG Activity":
            targetDeviceType = "ANR M40"
        case "IR Activity", "Muscle Activity":
            targetDeviceType = "Oralable"
        case "Movement":
            targetDeviceType = nil  // Both devices have accelerometer (but ANR doesn't send it)
        case "Temperature":
            targetDeviceType = "Oralable"  // Only Oralable has temperature
        default:
            targetDeviceType = nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        // Group by timestamp for aggregation
        var groupedData: [Date: [(emg: Double, ir: Double, red: Double, green: Double, accelX: Double, accelY: Double, accelZ: Double, temp: Double, battery: Int, hr: Double, deviceType: String)]] = [:]
        
        var rowsProcessed = 0
        var rowsWithAccel = 0
        
        for line in lines.dropFirst() {
            let columns = line.components(separatedBy: ",")
            guard columns.count >= 12 else { continue }
            
            guard let timestamp = dateFormatter.date(from: columns[0]) else { continue }
            
            let deviceType = columns[1]
            
            // Filter by device type if specified
            if let target = targetDeviceType, deviceType != target {
                continue
            }
            
            let emg = Double(columns[2]) ?? 0
            let ir = Double(columns[3]) ?? 0
            let red = Double(columns[4]) ?? 0
            let green = Double(columns[5]) ?? 0
            let accelX = Double(columns[6]) ?? 0
            let accelY = Double(columns[7]) ?? 0
            let accelZ = Double(columns[8]) ?? 0
            let temp = Double(columns[9]) ?? 0
            let battery = Int(Double(columns[10]) ?? 0)
            let hr = Double(columns[11]) ?? 0
            
            rowsProcessed += 1
            if accelX != 0 || accelY != 0 || accelZ != 0 {
                rowsWithAccel += 1
            }
            
            // Round timestamp to nearest second for grouping
            let roundedTimestamp = Date(timeIntervalSince1970: floor(timestamp.timeIntervalSince1970))
            
            if groupedData[roundedTimestamp] == nil {
                groupedData[roundedTimestamp] = []
            }
            groupedData[roundedTimestamp]?.append((emg, ir, red, green, accelX, accelY, accelZ, temp, battery, hr, deviceType))
        }
        
        Logger.shared.info("[SessionDataLoader] 📊 Processed \(rowsProcessed) rows, \(rowsWithAccel) with accelerometer data, \(groupedData.count) unique timestamps")
        
        // Convert grouped data to HistoricalDataPoints
        var dataPoints: [HistoricalDataPoint] = []
        for (timestamp, readings) in groupedData.sorted(by: { $0.key < $1.key }) {
            let point = createDataPointFromExport(timestamp: timestamp, readings: readings, metricType: metricType)
            dataPoints.append(point)
        }
        
        Logger.shared.info("[SessionDataLoader] ✅ Created \(dataPoints.count) data points for \(metricType)")
        return dataPoints
    }
    
    /// Create a HistoricalDataPoint from grouped export readings
    private func createDataPointFromExport(
        timestamp: Date,
        readings: [(emg: Double, ir: Double, red: Double, green: Double, accelX: Double, accelY: Double, accelZ: Double, temp: Double, battery: Int, hr: Double, deviceType: String)],
        metricType: String
    ) -> HistoricalDataPoint {
        
        // Calculate averages
        let count = Double(readings.count)
        
        let avgEMG = readings.map { $0.emg }.reduce(0, +) / count
        let avgIR = readings.map { $0.ir }.reduce(0, +) / count
        let avgRed = readings.map { $0.red }.reduce(0, +) / count
        let avgGreen = readings.map { $0.green }.reduce(0, +) / count
        let avgTemp = readings.map { $0.temp }.filter { $0 > 0 }.reduce(0, +) / max(Double(readings.filter { $0.temp > 0 }.count), 1)
        let avgBattery = readings.map { $0.battery }.filter { $0 > 0 }.max() ?? 0
        let avgHR = readings.map { $0.hr }.filter { $0 > 0 }.reduce(0, +) / max(Double(readings.filter { $0.hr > 0 }.count), 1)
        
        // Calculate movement magnitude in g units
        var movementIntensity: Double = 0
        var movementVariability: Double = 0
        
        // Filter readings that have accelerometer data (non-zero values)
        let accelReadings = readings.filter { reading in
            return reading.accelX != 0 || reading.accelY != 0 || reading.accelZ != 0
        }
        
        if !accelReadings.isEmpty {
            // Convert raw ADC values to g units, then calculate magnitude
            let magnitudes: [Double] = accelReadings.map { reading in
                let xG = reading.accelX / self.accelLSBPerG
                let yG = reading.accelY / self.accelLSBPerG
                let zG = reading.accelZ / self.accelLSBPerG
                let mag = sqrt(xG * xG + yG * yG + zG * zG)
                return mag
            }
            
            movementIntensity = magnitudes.reduce(0, +) / Double(magnitudes.count)
            
            if magnitudes.count > 1 {
                let mean = movementIntensity
                let squaredDiffs = magnitudes.map { pow($0 - mean, 2) }
                movementVariability = sqrt(squaredDiffs.reduce(0, +) / Double(magnitudes.count - 1))
            }
            
            // Log first data point's movement calculation for debugging
            if metricType == "Movement" {
                if let first = accelReadings.first {
                    let xG = first.accelX / self.accelLSBPerG
                    let yG = first.accelY / self.accelLSBPerG
                    let zG = first.accelZ / self.accelLSBPerG
                    Logger.shared.info("[SessionDataLoader] 🔢 Sample accel: raw(\(Int(first.accelX)),\(Int(first.accelY)),\(Int(first.accelZ))) -> g(\(String(format: "%.3f", xG)),\(String(format: "%.3f", yG)),\(String(format: "%.3f", zG))) = \(String(format: "%.3f", movementIntensity))g")
                }
            }
        }
        
        // Determine primary value based on metric type
        var primaryIRValue: Double? = nil
        
        switch metricType {
        case "EMG Activity":
            primaryIRValue = avgEMG > 0 ? avgEMG : nil
        case "IR Activity", "Muscle Activity":
            primaryIRValue = avgIR > 0 ? avgIR : nil
        default:
            primaryIRValue = avgIR > 0 ? avgIR : (avgEMG > 0 ? avgEMG : nil)
        }
        
        return HistoricalDataPoint(
            timestamp: timestamp,
            averageHeartRate: avgHR > 0 ? avgHR : nil,
            heartRateQuality: avgHR > 0 ? 0.8 : nil,
            averageSpO2: nil,
            spo2Quality: nil,
            averageTemperature: avgTemp,
            averageBattery: avgBattery,
            movementIntensity: movementIntensity,
            movementVariability: movementVariability,
            grindingEvents: nil,
            averagePPGIR: primaryIRValue,
            averagePPGRed: avgRed > 0 ? avgRed : nil,
            averagePPGGreen: avgGreen > 0 ? avgGreen : nil
        )
    }
    
    // MARK: - Private Methods - Recording Session Parsing (Legacy)
    
    /// Raw reading from session CSV file
    private struct RawReading {
        let timestamp: Date
        let deviceID: String
        let sensorType: String
        let value: Double
        let quality: Double
    }
    
    /// Load raw readings from a session CSV file
    private func loadSessionCSVFile(at url: URL) -> [RawReading] {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return parseSessionCSV(content: content)
        } catch {
            Logger.shared.error("[SessionDataLoader] Failed to load CSV: \(error)")
            return []
        }
    }
    
    /// Parse session CSV content (format: timestamp,deviceID,sensorType,value,quality)
    private func parseSessionCSV(content: String) -> [RawReading] {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }
        
        var readings: [RawReading] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let dateFormatterSimple = ISO8601DateFormatter()
        dateFormatterSimple.formatOptions = [.withInternetDateTime]
        
        for line in lines.dropFirst() {
            let columns = line.components(separatedBy: ",")
            guard columns.count >= 4 else { continue }
            
            var timestamp: Date?
            timestamp = dateFormatter.date(from: columns[0])
            if timestamp == nil {
                timestamp = dateFormatterSimple.date(from: columns[0])
            }
            
            guard let ts = timestamp else { continue }
            
            let deviceID = columns[1]
            let sensorType = columns[2]
            let value = Double(columns[3]) ?? 0
            let quality = columns.count > 4 ? (Double(columns[4]) ?? 0.8) : 0.8
            
            readings.append(RawReading(timestamp: ts, deviceID: deviceID, sensorType: sensorType, value: value, quality: quality))
        }
        
        return readings
    }
    
    /// Aggregate raw readings into HistoricalDataPoint objects
    private func aggregateToHistoricalDataPoints(
        readings: [RawReading],
        metricType: String,
        deviceType: DeviceType?
    ) -> [HistoricalDataPoint] {
        
        guard !readings.isEmpty else { return [] }
        
        let sortedReadings = readings.sorted { $0.timestamp < $1.timestamp }
        guard let firstTimestamp = sortedReadings.first?.timestamp,
              let lastTimestamp = sortedReadings.last?.timestamp else {
            return []
        }
        
        let totalDuration = lastTimestamp.timeIntervalSince(firstTimestamp)
        
        let aggregationInterval: TimeInterval
        if totalDuration < 60 {
            aggregationInterval = 1.0
        } else if totalDuration < 300 {
            aggregationInterval = 5.0
        } else if totalDuration < 3600 {
            aggregationInterval = 30.0
        } else {
            aggregationInterval = 60.0
        }
        
        var buckets: [Date: [RawReading]] = [:]
        
        for reading in sortedReadings {
            let bucketTime = Date(timeIntervalSince1970: floor(reading.timestamp.timeIntervalSince1970 / aggregationInterval) * aggregationInterval)
            if buckets[bucketTime] == nil {
                buckets[bucketTime] = []
            }
            buckets[bucketTime]?.append(reading)
        }
        
        var dataPoints: [HistoricalDataPoint] = []
        
        for (bucketTime, bucketReadings) in buckets.sorted(by: { $0.key < $1.key }) {
            let point = createHistoricalDataPoint(timestamp: bucketTime, readings: bucketReadings, metricType: metricType, deviceType: deviceType)
            dataPoints.append(point)
        }
        
        return dataPoints
    }
    
    /// Create a single HistoricalDataPoint from a bucket of readings
    private func createHistoricalDataPoint(
        timestamp: Date,
        readings: [RawReading],
        metricType: String,
        deviceType: DeviceType?
    ) -> HistoricalDataPoint {
        
        var ppgIRValues: [Double] = []
        var ppgRedValues: [Double] = []
        var ppgGreenValues: [Double] = []
        var emgValues: [Double] = []
        var accelXValues: [Double] = []
        var accelYValues: [Double] = []
        var accelZValues: [Double] = []
        var temperatureValues: [Double] = []
        var batteryValues: [Double] = []
        var heartRateValues: [Double] = []
        var heartRateQualities: [Double] = []
        
        for reading in readings {
            switch reading.sensorType.lowercased() {
            case "ppg_infrared", "ppginfrared", "ppgir", "ir":
                ppgIRValues.append(reading.value)
            case "ppg_red", "ppgred", "red":
                ppgRedValues.append(reading.value)
            case "ppg_green", "ppggreen", "green":
                ppgGreenValues.append(reading.value)
            case "emg", "muscle_activity", "muscleactivity":
                emgValues.append(reading.value)
            case "accel_x", "accelerometerx", "accelx":
                accelXValues.append(reading.value)
            case "accel_y", "accelerometery", "accely":
                accelYValues.append(reading.value)
            case "accel_z", "accelerometerz", "accelz":
                accelZValues.append(reading.value)
            case "temperature", "temp":
                temperatureValues.append(reading.value)
            case "battery":
                batteryValues.append(reading.value)
            case "heart_rate", "heartrate", "hr":
                heartRateValues.append(reading.value)
                heartRateQualities.append(reading.quality)
            default:
                break
            }
        }
        
        let avgPPGIR = ppgIRValues.isEmpty ? nil : ppgIRValues.reduce(0, +) / Double(ppgIRValues.count)
        let avgPPGRed = ppgRedValues.isEmpty ? nil : ppgRedValues.reduce(0, +) / Double(ppgRedValues.count)
        let avgPPGGreen = ppgGreenValues.isEmpty ? nil : ppgGreenValues.reduce(0, +) / Double(ppgGreenValues.count)
        let avgEMG = emgValues.isEmpty ? nil : emgValues.reduce(0, +) / Double(emgValues.count)
        let avgTemperature = temperatureValues.isEmpty ? 0 : temperatureValues.reduce(0, +) / Double(temperatureValues.count)
        let avgBattery = batteryValues.isEmpty ? 0 : Int(batteryValues.reduce(0, +) / Double(batteryValues.count))
        let avgHeartRate = heartRateValues.isEmpty ? nil : heartRateValues.reduce(0, +) / Double(heartRateValues.count)
        let avgHRQuality = heartRateQualities.isEmpty ? nil : heartRateQualities.reduce(0, +) / Double(heartRateQualities.count)
        
        var movementIntensity: Double = 0
        var movementVariability: Double = 0
        
        if !accelXValues.isEmpty && !accelYValues.isEmpty && !accelZValues.isEmpty {
            let count = min(accelXValues.count, accelYValues.count, accelZValues.count)
            var magnitudes: [Double] = []
            
            for i in 0..<count {
                // Convert raw ADC to g units
                let xG = accelXValues[i] / accelLSBPerG
                let yG = accelYValues[i] / accelLSBPerG
                let zG = accelZValues[i] / accelLSBPerG
                let mag = sqrt(xG * xG + yG * yG + zG * zG)
                magnitudes.append(mag)
            }
            
            movementIntensity = magnitudes.reduce(0, +) / Double(magnitudes.count)
            
            if magnitudes.count > 1 {
                let mean = movementIntensity
                let squaredDiffs = magnitudes.map { pow($0 - mean, 2) }
                movementVariability = sqrt(squaredDiffs.reduce(0, +) / Double(magnitudes.count - 1))
            }
        }
        
        var finalPPGIR = avgPPGIR
        if deviceType == .anr, let emg = avgEMG {
            finalPPGIR = emg
        }
        
        return HistoricalDataPoint(
            timestamp: timestamp,
            averageHeartRate: avgHeartRate,
            heartRateQuality: avgHRQuality,
            averageSpO2: nil,
            spo2Quality: nil,
            averageTemperature: avgTemperature,
            averageBattery: avgBattery,
            movementIntensity: movementIntensity,
            movementVariability: movementVariability,
            grindingEvents: nil,
            averagePPGIR: finalPPGIR,
            averagePPGRed: avgPPGRed,
            averagePPGGreen: avgPPGGreen
        )
    }
}
