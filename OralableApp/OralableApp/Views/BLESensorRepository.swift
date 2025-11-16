//
//  BLESensorRepository.swift
//  OralableApp
//
//  Created: November 8, 2025
//  Adapter that makes OralableBLE conform to SensorRepository protocol
//

import Foundation
import CoreBluetooth

/// Repository implementation that wraps OralableBLE
@MainActor
class BLESensorRepository: SensorRepository {
    
    private let ble: OralableBLE
    
    init(ble: OralableBLE) {
        self.ble = ble
    }
    
    // MARK: - Save Operations
    
    func save(_ reading: SensorReading) async throws {
        // OralableBLE receives data from devices, no manual save needed
        // This could be extended to persist to disk if needed
    }
    
    func save(_ readings: [SensorReading]) async throws {
        // OralableBLE receives data from devices, no manual save needed
    }
    
    // MARK: - Query Operations
    
    func readings(for sensorType: SensorType) async throws -> [SensorReading] {
        // Convert from legacy history arrays to SensorReading format
        let deviceId = ble.connectedDevice?.identifier.uuidString ?? "unknown"
        
        switch sensorType {
        case .heartRate:
            return ble.heartRateHistory.map { hrData in
                SensorReading(
                    id: UUID(),
                    sensorType: .heartRate,
                    value: hrData.bpm,
                    timestamp: hrData.timestamp,
                    deviceId: deviceId,
                    quality: hrData.quality
                )
            }
            
        case .spo2:
            return ble.spo2History.map { spo2Data in
                SensorReading(
                    id: UUID(),
                    sensorType: .spo2,
                    value: spo2Data.percentage,
                    timestamp: spo2Data.timestamp,
                    deviceId: deviceId,
                    quality: spo2Data.quality
                )
            }
            
        case .temperature:
            return ble.temperatureHistory.map { tempData in
                SensorReading(
                    id: UUID(),
                    sensorType: .temperature,
                    value: tempData.celsius,
                    timestamp: tempData.timestamp,
                    deviceId: deviceId,
                    quality: 1.0
                )
            }
            
        case .accelerometerX:
            return ble.accelerometerHistory.map { accelData in
                SensorReading(
                    id: UUID(),
                    sensorType: .accelerometerX,
                    value: Double(accelData.x) / 1000.0,
                    timestamp: accelData.timestamp,
                    deviceId: deviceId,
                    quality: 1.0
                )
            }
            
        case .accelerometerY:
            return ble.accelerometerHistory.map { accelData in
                SensorReading(
                    id: UUID(),
                    sensorType: .accelerometerY,
                    value: Double(accelData.y) / 1000.0,
                    timestamp: accelData.timestamp,
                    deviceId: deviceId,
                    quality: 1.0
                )
            }
            
        case .accelerometerZ:
            return ble.accelerometerHistory.map { accelData in
                SensorReading(
                    id: UUID(),
                    sensorType: .accelerometerZ,
                    value: Double(accelData.z) / 1000.0,
                    timestamp: accelData.timestamp,
                    deviceId: deviceId,
                    quality: 1.0
                )
            }
            
        case .battery:
            return ble.batteryHistory.map { batteryData in
                SensorReading(
                    id: UUID(),
                    sensorType: .battery,
                    value: Double(batteryData.percentage),
                    timestamp: batteryData.timestamp,
                    deviceId: deviceId,
                    quality: 1.0
                )
            }
            
        case .ppgRed:
            return ble.ppgHistory.map { ppgData in
                SensorReading(
                    id: UUID(),
                    sensorType: .ppgRed,
                    value: Double(ppgData.red),
                    timestamp: ppgData.timestamp,
                    deviceId: deviceId,
                    quality: 1.0
                )
            }
            
        case .ppgInfrared:
            return ble.ppgHistory.map { ppgData in
                SensorReading(
                    id: UUID(),
                    sensorType: .ppgInfrared,
                    value: Double(ppgData.ir),
                    timestamp: ppgData.timestamp,
                    deviceId: deviceId,
                    quality: 1.0
                )
            }
            
        case .ppgGreen:
            return ble.ppgHistory.map { ppgData in
                SensorReading(
                    id: UUID(),
                    sensorType: .ppgGreen,
                    value: Double(ppgData.green),
                    timestamp: ppgData.timestamp,
                    deviceId: deviceId,
                    quality: 1.0
                )
            }
            
        // For sensor types that don't have legacy history arrays, return empty
        case .emg, .muscleActivity:
            return []
        }
    }
    
    func readings(
        for sensorType: SensorType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [SensorReading] {
        let allReadings = try await readings(for: sensorType)
        return allReadings.filter { reading in
            reading.timestamp >= startDate && reading.timestamp <= endDate
        }
    }
    
    func readings(from deviceId: String) async throws -> [SensorReading] {
        // Get all sensor readings from all types for this device
        var allReadings: [SensorReading] = []
        
        for sensorType in SensorType.allCases {
            let readings = try await self.readings(for: sensorType)
            allReadings.append(contentsOf: readings.filter { $0.deviceId == deviceId })
        }
        
        return allReadings.sorted { $0.timestamp < $1.timestamp }
    }
    
    func latestReading(for sensorType: SensorType) async throws -> SensorReading? {
        let readings = try await self.readings(for: sensorType)
        return readings.max { $0.timestamp < $1.timestamp }
    }
    
    func readingsCount(for sensorType: SensorType) async throws -> Int {
        let readings = try await self.readings(for: sensorType)
        return readings.count
    }
    
    func allReadings(from startDate: Date, to endDate: Date) async throws -> [SensorReading] {
        var allReadings: [SensorReading] = []
        
        for sensorType in SensorType.allCases {
            let readings = try await self.readings(for: sensorType, from: startDate, to: endDate)
            allReadings.append(contentsOf: readings)
        }
        
        return allReadings.sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Summary Operations
    
    func dataSummary() async throws -> DataSummary {
        var readingsBySensor: [SensorType: Int] = [:]
        var latestReadings: [SensorType: SensorReading] = [:]
        var allReadings: [SensorReading] = []
        var totalReadings = 0
        var earliestDate: Date?
        var latestDate: Date?
        var deviceIds: Set<String> = []
        
        for sensorType in SensorType.allCases {
            let readings = try await self.readings(for: sensorType)
            readingsBySensor[sensorType] = readings.count
            totalReadings += readings.count
            allReadings.append(contentsOf: readings)
            
            // Collect device IDs
            readings.forEach { 
                if let deviceId = $0.deviceId {
                    deviceIds.insert(deviceId)
                }
            }
            
            if let latest = readings.max(by: { $0.timestamp < $1.timestamp }) {
                latestReadings[sensorType] = latest
                
                if latestDate == nil || latest.timestamp > latestDate! {
                    latestDate = latest.timestamp
                }
            }
            
            if let earliest = readings.min(by: { $0.timestamp < $1.timestamp }) {
                if earliestDate == nil || earliest.timestamp < earliestDate! {
                    earliestDate = earliest.timestamp
                }
            }
        }
        
        let dateRange: DateInterval?
        if let start = earliestDate, let end = latestDate {
            dateRange = DateInterval(start: start, end: end)
        } else {
            dateRange = nil
        }
        
        // Calculate quality metrics
        let qualityMetrics = calculateQualityMetrics(from: allReadings)
        
        return DataSummary(
            totalReadings: totalReadings,
            dateRange: dateRange,
            readingsBySensor: readingsBySensor,
            latestReadings: latestReadings,
            connectedDevices: deviceIds,
            qualityMetrics: qualityMetrics
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateQualityMetrics(from readings: [SensorReading]) -> DataQualityMetrics {
        let readingsWithQuality = readings.filter { $0.quality != nil }
        let readingsWithQualityPercentage = readings.isEmpty ? 0.0 : 
            Double(readingsWithQuality.count) / Double(readings.count)
        
        let averageQuality = readingsWithQuality.isEmpty ? 0.0 :
            readingsWithQuality.compactMap { $0.quality }.reduce(0.0, +) / Double(readingsWithQuality.count)
        
        let invalidReadings = readings.filter { !$0.isValid }.count
        let validReadingsPercentage = readings.isEmpty ? 0.0 :
            Double(readings.count - invalidReadings) / Double(readings.count)
        
        // Simple data gap detection (gaps > 1 minute)
        let dataGaps = detectDataGaps(in: readings)
        
        return DataQualityMetrics(
            readingsWithQuality: readingsWithQualityPercentage,
            averageQuality: averageQuality,
            invalidReadings: invalidReadings,
            validReadingsPercentage: validReadingsPercentage,
            dataGaps: dataGaps
        )
    }
    
    private func detectDataGaps(in readings: [SensorReading]) -> [DateInterval] {
        guard !readings.isEmpty else { return [] }
        
        let sortedReadings = readings.sorted { $0.timestamp < $1.timestamp }
        var gaps: [DateInterval] = []
        
        for i in 0..<(sortedReadings.count - 1) {
            let current = sortedReadings[i]
            let next = sortedReadings[i + 1]
            let timeDifference = next.timestamp.timeIntervalSince(current.timestamp)
            
            // Consider a gap if more than 1 minute between readings
            if timeDifference > 60 {
                gaps.append(DateInterval(start: current.timestamp, end: next.timestamp))
            }
        }
        
        return gaps
    }
    
    func recentReadings(limit: Int) async throws -> [SensorReading] {
        // Get all readings from sensor data history
        let deviceId = ble.connectedDevice?.identifier.uuidString ?? "unknown"
        
        let allReadings = ble.sensorDataHistory.flatMap { sensorData -> [SensorReading] in
            var readings: [SensorReading] = []
            
            if let hr = sensorData.heartRate {
                readings.append(SensorReading(
                    id: UUID(),
                    sensorType: .heartRate,
                    value: hr.bpm,
                    timestamp: sensorData.timestamp,
                    deviceId: deviceId,
                    quality: hr.quality
                ))
            }
            
            if let spo2 = sensorData.spo2 {
                readings.append(SensorReading(
                    id: UUID(),
                    sensorType: .spo2,
                    value: spo2.percentage,
                    timestamp: sensorData.timestamp,
                    deviceId: deviceId,
                    quality: spo2.quality
                ))
            }
            
            // Temperature is always present (not optional)
            let temp = sensorData.temperature
            readings.append(SensorReading(
                id: UUID(),
                sensorType: .temperature,
                value: temp.celsius,
                timestamp: sensorData.timestamp,
                deviceId: deviceId,
                quality: 1.0
            ))
            
            return readings
        }
        
        // Sort by timestamp descending and take limit
        return Array(allReadings.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    // MARK: - Maintenance Operations
    
    func clearAllData() async throws {
        // Clear all history arrays in OralableBLE
        ble.heartRateHistory.removeAll()
        ble.spo2History.removeAll()
        ble.temperatureHistory.removeAll()
        ble.accelerometerHistory.removeAll()
        ble.batteryHistory.removeAll()
        ble.ppgHistory.removeAll()
        ble.sensorDataHistory.removeAll()
    }
    
    func clearData(olderThan date: Date) async throws {
        // Filter out old data from each history array
        ble.heartRateHistory = ble.heartRateHistory.filter { $0.timestamp >= date }
        ble.spo2History = ble.spo2History.filter { $0.timestamp >= date }
        ble.temperatureHistory = ble.temperatureHistory.filter { $0.timestamp >= date }
        ble.accelerometerHistory = ble.accelerometerHistory.filter { $0.timestamp >= date }
        ble.batteryHistory = ble.batteryHistory.filter { $0.timestamp >= date }
        ble.ppgHistory = ble.ppgHistory.filter { $0.timestamp >= date }
        ble.sensorDataHistory = ble.sensorDataHistory.filter { $0.timestamp >= date }
    }
    
    func storageSize() async throws -> Int64 {
        // Rough estimate based on number of readings
        let summary = try await dataSummary()
        // Assume ~100 bytes per reading on average
        return Int64(summary.totalReadings * 100)
    }
}
