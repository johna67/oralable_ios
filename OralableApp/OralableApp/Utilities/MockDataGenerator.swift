//
//  MockDataGenerator.swift
//  OralableApp
//
//  Created: November 12, 2025
//  Generates realistic mock data for demo mode
//

import Foundation

/// Generates realistic mock sensor data for demo and testing purposes
class MockDataGenerator {

    // MARK: - Singleton

    static let shared = MockDataGenerator()

    private init() {}

    // MARK: - PPG Data Generation

    /// Generate realistic PPG waveform data
    func generatePPGData(duration: TimeInterval = 10.0, samplingRate: Double = 100.0) -> [UInt32] {
        let samples = Int(duration * samplingRate)
        var data: [UInt32] = []

        let heartRate: Double = 72.0 // BPM
        let frequency = heartRate / 60.0 // Hz
        let baselineOffset: UInt32 = 524288 // 19-bit mid-point
        let amplitude: UInt32 = 50000

        for i in 0..<samples {
            let time = Double(i) / samplingRate
            let angle = 2 * .pi * frequency * time

            // Main pulse wave (systolic peak)
            let systolic = sin(angle)

            // Dicrotic notch (diastolic component)
            let diastolic = 0.3 * sin(2 * angle + .pi / 4)

            // Add some realistic noise
            let noise = Double.random(in: -0.05...0.05)

            // Combine components
            let signal = systolic + diastolic + noise
            let value = baselineOffset + UInt32(signal * Double(amplitude))

            data.append(value)
        }

        return data
    }

    // MARK: - Heart Rate Generation

    /// Generate realistic heart rate value with variation
    func generateHeartRate() -> Int {
        // Normal resting heart rate 60-100 BPM
        // Add some natural variation
        let baseRate = 72
        let variation = Int.random(in: -5...5)
        return max(60, min(100, baseRate + variation))
    }

    /// Generate heart rate history data
    func generateHeartRateHistory(points: Int = 100) -> [(date: Date, value: Int)] {
        var data: [(date: Date, value: Int)] = []
        let now = Date()

        for i in 0..<points {
            let date = now.addingTimeInterval(Double(-i) * 60) // 1 minute intervals
            let baseRate = 72
            // Add daily rhythm - higher during day, lower at night
            let hour = Calendar.current.component(.hour, from: date)
            let dailyAdjustment = hour >= 8 && hour <= 22 ? 10 : -5
            let variation = Int.random(in: -3...3)
            let rate = max(55, min(95, baseRate + dailyAdjustment + variation))

            data.append((date: date, value: rate))
        }

        return data.reversed()
    }

    // MARK: - SpO2 Generation

    /// Generate realistic SpO2 value
    func generateSpO2() -> Int {
        // Normal SpO2 96-100%
        let baseValue = 98
        let variation = Int.random(in: -1...1)
        return max(96, min(100, baseValue + variation))
    }

    /// Generate SpO2 history data
    func generateSpO2History(points: Int = 100) -> [(date: Date, value: Int)] {
        var data: [(date: Date, value: Int)] = []
        let now = Date()

        for i in 0..<points {
            let date = now.addingTimeInterval(Double(-i) * 60)
            let baseValue = 98
            let variation = Int.random(in: -1...1)
            let value = max(95, min(100, baseValue + variation))

            data.append((date: date, value: value))
        }

        return data.reversed()
    }

    // MARK: - Temperature Generation

    /// Generate realistic temperature value in Celsius
    func generateTemperature() -> Double {
        // Normal body temperature 36.5-37.5°C
        let baseTemp = 37.0
        let variation = Double.random(in: -0.3...0.3)
        return baseTemp + variation
    }

    /// Generate temperature history data
    func generateTemperatureHistory(points: Int = 100) -> [(date: Date, value: Double)] {
        var data: [(date: Date, value: Double)] = []
        let now = Date()

        for i in 0..<points {
            let date = now.addingTimeInterval(Double(-i) * 60)
            let baseTemp = 37.0
            // Slight circadian rhythm - slightly higher in evening
            let hour = Calendar.current.component(.hour, from: date)
            let circadianAdjustment = hour >= 16 && hour <= 20 ? 0.2 : 0.0
            let variation = Double.random(in: -0.1...0.1)
            let temp = baseTemp + circadianAdjustment + variation

            data.append((date: date, value: temp))
        }

        return data.reversed()
    }

    // MARK: - Battery Generation

    /// Generate realistic battery level
    func generateBatteryLevel() -> Int {
        // Simulate battery drain
        let level = Int.random(in: 65...95)
        return level
    }

    // MARK: - Accelerometer Generation

    /// Generate realistic accelerometer data (simulating slight movement)
    func generateAccelerometerData() -> (x: Int16, y: Int16, z: Int16) {
        // Simulate gravity (z-axis) with slight movement
        let x = Int16.random(in: -200...200)
        let y = Int16.random(in: -200...200)
        let z = Int16.random(in: 900...1100) // ~1g in z-axis

        return (x: x, y: y, z: z)
    }

    // MARK: - Complete Sensor Packet

    /// Generate a complete realistic sensor data packet
    func generateSensorPacket() -> MockSensorPacket {
        return MockSensorPacket(
            timestamp: Date(),
            heartRate: generateHeartRate(),
            spO2: generateSpO2(),
            temperature: generateTemperature(),
            batteryLevel: generateBatteryLevel(),
            ppgRed: generatePPGData(duration: 1.0, samplingRate: 100.0),
            ppgIR: generatePPGData(duration: 1.0, samplingRate: 100.0),
            ppgGreen: generatePPGData(duration: 1.0, samplingRate: 100.0),
            accelerometer: generateAccelerometerData()
        )
    }

    // MARK: - Session Data

    /// Generate a complete mock recording session
    func generateMockSession(duration: TimeInterval = 300.0) -> MockRecordingSession {
        let sessionID = UUID()
        let startTime = Date().addingTimeInterval(-duration)
        let endTime = Date()

        // Generate data points at 1-second intervals
        let intervals = Int(duration)
        var dataPoints: [MockDataPoint] = []

        for i in 0..<intervals {
            let timestamp = startTime.addingTimeInterval(Double(i))
            let point = MockDataPoint(
                timestamp: timestamp,
                heartRate: generateHeartRate(),
                spO2: generateSpO2(),
                temperature: generateTemperature(),
                batteryLevel: max(50, generateBatteryLevel() - i / 100) // Simulate drain
            )
            dataPoints.append(point)
        }

        return MockRecordingSession(
            id: sessionID,
            startTime: startTime,
            endTime: endTime,
            dataPoints: dataPoints
        )
    }
}

// MARK: - Mock Data Models

struct MockSensorPacket {
    let timestamp: Date
    let heartRate: Int
    let spO2: Int
    let temperature: Double
    let batteryLevel: Int
    let ppgRed: [UInt32]
    let ppgIR: [UInt32]
    let ppgGreen: [UInt32]
    let accelerometer: (x: Int16, y: Int16, z: Int16)
}

struct MockDataPoint {
    let timestamp: Date
    let heartRate: Int
    let spO2: Int
    let temperature: Double
    let batteryLevel: Int
}

struct MockRecordingSession {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let dataPoints: [MockDataPoint]

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var averageHeartRate: Int {
        let sum = dataPoints.reduce(0) { $0 + $1.heartRate }
        return dataPoints.isEmpty ? 0 : sum / dataPoints.count
    }

    var averageSpO2: Int {
        let sum = dataPoints.reduce(0) { $0 + $1.spO2 }
        return dataPoints.isEmpty ? 0 : sum / dataPoints.count
    }

    var averageTemperature: Double {
        let sum = dataPoints.reduce(0.0) { $0 + $1.temperature }
        return dataPoints.isEmpty ? 0.0 : sum / Double(dataPoints.count)
    }
}
