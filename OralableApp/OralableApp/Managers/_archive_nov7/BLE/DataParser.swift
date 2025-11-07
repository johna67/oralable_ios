//
//  DataParser.swift
//  OralableApp
//
//  Created by John A Cogan on 05/11/2025.
//


//
//  DataParser.swift
//  OralableApp
//
//  Created: November 5, 2025
//  Parses raw BLE characteristic data into sensor readings
//

import Foundation
import CoreBluetooth
import Combine

/// Handles parsing of BLE characteristic data
@MainActor
class DataParser: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var latestPPGIR: Double?
    @Published var latestPPGRed: Double?
    @Published var latestPPGGreen: Double?
    @Published var latestAccelerometerX: Double?
    @Published var latestAccelerometerY: Double?
    @Published var latestAccelerometerZ: Double?
    @Published var latestTemperature: Double?
    @Published var latestBatteryLevel: Int?
    @Published var latestHeartRate: HeartRateResult?
    
    // MARK: - Properties
    
    private var heartRateCalculator = HeartRateCalculator()
    private var ppgBuffer: [UInt32] = []
    private let ppgBufferSize = 150 // Need 150+ samples for heart rate
    
    // MARK: - Subjects for streaming
    
    let sensorReadingSubject = PassthroughSubject<SensorReading, Never>()
    
    // MARK: - UUIDs (from your firmware)
    
    struct CharacteristicUUIDs {
        static let ppg = CBUUID(string: "00002A37-0000-1000-8000-00805F9B34FB")
        static let accelerometer = CBUUID(string: "00002A38-0000-1000-8000-00805F9B34FB")
        static let temperature = CBUUID(string: "00002A6E-0000-1000-8000-00805F9B34FB")
        static let battery = CBUUID(string: "00002A19-0000-1000-8000-00805F9B34FB")
    }
    
    // MARK: - Public Methods
    
    /// Main parsing method - called when characteristic updates
    func parseCharacteristic(_ characteristic: CBCharacteristic) {
        guard let data = characteristic.value else { return }
        
        switch characteristic.uuid {
        case CharacteristicUUIDs.ppg:
            parsePPGData(data)
            
        case CharacteristicUUIDs.accelerometer:
            parseAccelerometerData(data)
            
        case CharacteristicUUIDs.temperature:
            parseTemperatureData(data)
            
        case CharacteristicUUIDs.battery:
            parseBatteryData(data)
            
        default:
            print("Unknown characteristic: \(characteristic.uuid)")
        }
    }
    
    // MARK: - PPG Parsing
    
    private func parsePPGData(_ data: Data) {
        // PPG data format from firmware:
        // Bytes 0-3: IR value (uint32, little endian)
        // Bytes 4-7: Red value (uint32, little endian)
        // Bytes 8-11: Green value (uint32, little endian)
        
        guard data.count >= 12 else {
            print("Invalid PPG data length: \(data.count)")
            return
        }
        
        let ir = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        let red = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
        let green = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self) }
        
        // Store latest values
        latestPPGIR = Double(ir)
        latestPPGRed = Double(red)
        latestPPGGreen = Double(green)
        
        // Create sensor readings for each channel
        let irReading = SensorReading(
            sensorType: .ppgInfrared,
            value: Double(ir),
            timestamp: Date(),
            deviceId: "oralable"
        )
        sensorReadingSubject.send(irReading)
        
        let redReading = SensorReading(
            sensorType: .ppgRed,
            value: Double(red),
            timestamp: Date(),
            deviceId: "oralable"
        )
        sensorReadingSubject.send(redReading)
        
        let greenReading = SensorReading(
            sensorType: .ppgGreen,
            value: Double(green),
            timestamp: Date(),
            deviceId: "oralable"
        )
        sensorReadingSubject.send(greenReading)
        
        // Add IR value to buffer for heart rate calculation
        ppgBuffer.append(ir)
        if ppgBuffer.count > ppgBufferSize {
            ppgBuffer.removeFirst()
        }
        
        // Calculate heart rate if we have enough samples
        if ppgBuffer.count >= ppgBufferSize {
            calculateHeartRate()
        }
    }
    
    // MARK: - Accelerometer Parsing
    
    private func parseAccelerometerData(_ data: Data) {
        // Accelerometer data format from firmware:
        // Bytes 0-1: X axis (int16, little endian, in mg)
        // Bytes 2-3: Y axis (int16, little endian, in mg)
        // Bytes 4-5: Z axis (int16, little endian, in mg)
        
        guard data.count >= 6 else {
            print("Invalid accelerometer data length: \(data.count)")
            return
        }
        
        let x = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Int16.self) }
        let y = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: Int16.self) }
        let z = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int16.self) }
        
        // Convert from mg to g
        let xG = Double(x) / 1000.0
        let yG = Double(y) / 1000.0
        let zG = Double(z) / 1000.0
        
        // Store latest values
        latestAccelerometerX = xG
        latestAccelerometerY = yG
        latestAccelerometerZ = zG
        
        // Send sensor readings for each axis
        let xReading = SensorReading(
            sensorType: .accelerometerX,
            value: xG,
            timestamp: Date(),
            deviceId: "oralable"
        )
        sensorReadingSubject.send(xReading)
        
        let yReading = SensorReading(
            sensorType: .accelerometerY,
            value: yG,
            timestamp: Date(),
            deviceId: "oralable"
        )
        sensorReadingSubject.send(yReading)
        
        let zReading = SensorReading(
            sensorType: .accelerometerZ,
            value: zG,
            timestamp: Date(),
            deviceId: "oralable"
        )
        sensorReadingSubject.send(zReading)
    }
    
    // MARK: - Temperature Parsing
    
    private func parseTemperatureData(_ data: Data) {
        // Temperature format from firmware:
        // Bytes 0-1: Temperature (int16, little endian, in 0.01°C units)
        
        guard data.count >= 2 else {
            print("Invalid temperature data length: \(data.count)")
            return
        }
        
        let tempRaw = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Int16.self) }
        let tempCelsius = Double(tempRaw) / 100.0
        
        latestTemperature = tempCelsius
        
        let sensorReading = SensorReading(
            sensorType: .temperature,
            value: tempCelsius,
            timestamp: Date(),
            deviceId: "oralable"
        )
        
        sensorReadingSubject.send(sensorReading)
    }
    
    // MARK: - Battery Parsing
    
    private func parseBatteryData(_ data: Data) {
        // Battery format: single byte (0-100)
        
        guard data.count >= 1 else {
            print("Invalid battery data length: \(data.count)")
            return
        }
        
        let batteryLevel = Int(data[0])
        latestBatteryLevel = batteryLevel
        
        let sensorReading = SensorReading(
            sensorType: .battery,
            value: Double(batteryLevel),
            timestamp: Date(),
            deviceId: "oralable"
        )
        
        sensorReadingSubject.send(sensorReading)
    }
    
    // MARK: - Heart Rate Calculation
    
    private func calculateHeartRate() {
        guard ppgBuffer.count >= ppgBufferSize else { return }
        
        // Use HeartRateCalculator to compute BPM
        if let result = heartRateCalculator.calculateHeartRate(irSamples: ppgBuffer) {
            latestHeartRate = result
            
            let sensorReading = SensorReading(
                sensorType: .heartRate,
                value: result.bpm,
                timestamp: result.timestamp,
                deviceId: "oralable",
                quality: result.quality
            )
            
            sensorReadingSubject.send(sensorReading)
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        ppgBuffer.removeAll()
        latestPPGIR = nil
        latestPPGRed = nil
        latestPPGGreen = nil
        latestAccelerometerX = nil
        latestAccelerometerY = nil
        latestAccelerometerZ = nil
        latestTemperature = nil
        latestBatteryLevel = nil
        latestHeartRate = nil
    }
}