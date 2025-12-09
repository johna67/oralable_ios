//
//  ProfessionalHistoricalDataModels.swift
//  OralableForProfessionals
//
//  Historical data models for displaying patient charts (mirrors OralableApp)
//

import Foundation

// MARK: - Time Range

enum TimeRange: String, CaseIterable, Identifiable {
    case minute = "Minute"
    case hour = "Hour"
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .minute: return 60
        case .hour: return 3600
        case .day: return 86400
        case .week: return 604800
        case .month: return 2592000
        }
    }

    var bucketDuration: TimeInterval {
        switch self {
        case .minute: return 1        // 1 second buckets
        case .hour: return 60         // 1 minute buckets
        case .day: return 3600        // 1 hour buckets
        case .week: return 86400      // 1 day buckets
        case .month: return 86400     // 1 day buckets
        }
    }

    var minimumDataPoints: Int {
        switch self {
        case .minute: return 10
        case .hour: return 5
        case .day: return 3
        case .week: return 2
        case .month: return 2
        }
    }
}

// MARK: - Historical Data Point

struct HistoricalDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let movementIntensity: Double
    let averageHeartRate: Double?
    let averageSpO2: Double?
    let averagePPGIR: Double?
    let averagePPGRed: Double?
    let averagePPGGreen: Double?
    let averageTemperature: Double?
    let sampleCount: Int

    init(
        timestamp: Date,
        movementIntensity: Double,
        averageHeartRate: Double? = nil,
        averageSpO2: Double? = nil,
        averagePPGIR: Double? = nil,
        averagePPGRed: Double? = nil,
        averagePPGGreen: Double? = nil,
        averageTemperature: Double? = nil,
        sampleCount: Int = 1
    ) {
        self.timestamp = timestamp
        self.movementIntensity = movementIntensity
        self.averageHeartRate = averageHeartRate
        self.averageSpO2 = averageSpO2
        self.averagePPGIR = averagePPGIR
        self.averagePPGRed = averagePPGRed
        self.averagePPGGreen = averagePPGGreen
        self.averageTemperature = averageTemperature
        self.sampleCount = sampleCount
    }
}

// MARK: - Data Aggregation

extension Array where Element == SerializableSensorData {
    /// Aggregate sensor data into time buckets for charting
    func aggregateIntoBuckets(bucketDuration: TimeInterval, from startDate: Date, to endDate: Date) -> [HistoricalDataPoint] {
        guard !isEmpty else { return [] }

        var buckets: [Date: [SerializableSensorData]] = [:]

        // Group data into buckets
        for reading in self {
            let bucketStart = Date(timeIntervalSince1970: floor(reading.timestamp.timeIntervalSince1970 / bucketDuration) * bucketDuration)

            if bucketStart >= startDate && bucketStart <= endDate {
                buckets[bucketStart, default: []].append(reading)
            }
        }

        // Convert buckets to HistoricalDataPoints
        return buckets.map { (bucketDate, readings) in
            let avgMovement = readings.reduce(0.0) { $0 + $1.accelMagnitude } / Double(readings.count)

            let heartRates = readings.compactMap { $0.heartRateBPM }
            let avgHeartRate = heartRates.isEmpty ? nil : heartRates.reduce(0.0, +) / Double(heartRates.count)

            let spo2Values = readings.compactMap { $0.spo2Percentage }
            let avgSpO2 = spo2Values.isEmpty ? nil : spo2Values.reduce(0.0, +) / Double(spo2Values.count)

            let avgPPGIR = readings.reduce(0.0) { $0 + Double($1.ppgIR) } / Double(readings.count)
            let avgPPGRed = readings.reduce(0.0) { $0 + Double($1.ppgRed) } / Double(readings.count)
            let avgPPGGreen = readings.reduce(0.0) { $0 + Double($1.ppgGreen) } / Double(readings.count)
            let avgTemp = readings.reduce(0.0) { $0 + $1.temperatureCelsius } / Double(readings.count)

            return HistoricalDataPoint(
                timestamp: bucketDate,
                movementIntensity: avgMovement,
                averageHeartRate: avgHeartRate,
                averageSpO2: avgSpO2,
                averagePPGIR: avgPPGIR,
                averagePPGRed: avgPPGRed,
                averagePPGGreen: avgPPGGreen,
                averageTemperature: avgTemp,
                sampleCount: readings.count
            )
        }.sorted { $0.timestamp < $1.timestamp }
    }
}
