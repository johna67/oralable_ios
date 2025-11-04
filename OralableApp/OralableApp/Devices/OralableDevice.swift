//
//  OralableDevice.swift
//  OralableApp
//
//  Created: November 4, 2025
//  Concrete implementation of BLEDeviceProtocol for Oralable device
//

import Foundation
import CoreBluetooth
import Combine

/// Oralable device implementation
@MainActor
class OralableDevice: NSObject, BLEDeviceProtocol {
    
    // MARK: - BLE Service & Characteristics UUIDs
    
    private static let serviceUUID = CBUUID(string: "0000180D-0000-1000-8000-00805F9B34FB") // Heart Rate Service
    private static let heartRateCharacteristicUUID = CBUUID(string: "00002A37-0000-1000-8000-00805F9B34FB") // Heart Rate Measurement
    private static let batteryServiceUUID = CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB")
    private static let batteryCharacteristicUUID = CBUUID(string: "00002A19-0000-1000-8000-00805F9B34FB")
    private static let temperatureServiceUUID = CBUUID(string: "00001809-0000-1000-8000-00805F9B34FB") // Health Thermometer
    private static let temperatureCharacteristicUUID = CBUUID(string: "00002A1C-0000-1000-8000-00805F9B34FB") // Temperature Measurement
    
    // MARK: - Protocol Properties
    
    var deviceInfo: DeviceInfo
    var deviceType: DeviceType { .oralable }
    var name: String { deviceInfo.name }
    var peripheral: CBPeripheral?
    var connectionState: DeviceConnectionState { deviceInfo.connectionState }
    var isConnected: Bool { connectionState == .connected }
    var signalStrength: Int? { deviceInfo.signalStrength }
    var batteryLevel: Int? { deviceInfo.batteryLevel }
    var firmwareVersion: String? { deviceInfo.firmwareVersion }
    var hardwareVersion: String? { deviceInfo.hardwareVersion }
    
    private let sensorReadingsSubject = PassthroughSubject<SensorReading, Never>()
    var sensorReadings: AnyPublisher<SensorReading, Never> {
        sensorReadingsSubject.eraseToAnyPublisher()
    }
    
    var latestReadings: [SensorType: SensorReading] = [:]
    
    var supportedSensors: [SensorType] {
        DeviceType.oralable.defaultSensors
    }
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager?
    private var characteristics: [CBUUID: CBCharacteristic] = [:]
    
    // MARK: - Initialization
    
    init(peripheral: CBPeripheral, name: String) {
        self.peripheral = peripheral
        self.deviceInfo = DeviceInfo(
            type: .oralable,
            name: name,
            peripheralIdentifier: peripheral.identifier,
            connectionState: .disconnected
        )
        super.init()
    }
    
    // MARK: - Connection Management
    
    func connect() async throws {
        guard let peripheral = peripheral else {
            throw DeviceError.invalidPeripheral
        }
        
        deviceInfo.connectionState = .connecting
        
        peripheral.delegate = self
    }
    
    func disconnect() async {
        deviceInfo.connectionState = .disconnecting
        
        await stopDataStream()
        
        deviceInfo.connectionState = .disconnected
    }
    
    func isAvailable() -> Bool {
        guard let peripheral = peripheral else { return false }
        return peripheral.state == .connected || peripheral.state == .connecting
    }
    
    // MARK: - Data Operations
    
    func startDataStream() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard let peripheral = peripheral else {
            throw DeviceError.invalidPeripheral
        }
        
        // Enable notifications for all supported characteristics
        for characteristic in characteristics.values {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func stopDataStream() async {
        guard let peripheral = peripheral else { return }
        
        for characteristic in characteristics.values {
            peripheral.setNotifyValue(false, for: characteristic)
        }
    }
    
    func requestReading(for sensorType: SensorType) async throws -> SensorReading? {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        return latestReadings[sensorType]
    }
    
    func parseData(_ data: Data, from characteristic: CBCharacteristic) -> [SensorReading] {
        var readings: [SensorReading] = []
        let characteristicUUID = characteristic.uuid
        let timestamp = Date()
        
        // Heart Rate / PPG Data
        if characteristicUUID == Self.heartRateCharacteristicUUID {
            readings.append(contentsOf: parseHeartRateData(data, timestamp: timestamp))
        }
        // Battery Data
        else if characteristicUUID == Self.batteryCharacteristicUUID {
            if let reading = parseBatteryData(data, timestamp: timestamp) {
                readings.append(reading)
            }
        }
        // Temperature Data
        else if characteristicUUID == Self.temperatureCharacteristicUUID {
            if let reading = parseTemperatureData(data, timestamp: timestamp) {
                readings.append(reading)
            }
        }
        
        // Update latest readings
        for reading in readings {
            latestReadings[reading.sensorType] = reading
            sensorReadingsSubject.send(reading)
        }
        
        return readings
    }
    
    // MARK: - Device Control
    
    func sendCommand(_ command: DeviceCommand) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Commands implementation would go here
        // This depends on the specific Oralable device protocol
    }
    
    func updateConfiguration(_ config: DeviceConfiguration) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Configuration implementation would go here
        // This depends on the specific Oralable device protocol
    }
    
    func updateDeviceInfo() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard let peripheral = peripheral else {
            throw DeviceError.invalidPeripheral
        }
        
        // Read battery and other device info
        for characteristic in characteristics.values {
            peripheral.readValue(for: characteristic)
        }
    }
    
    // MARK: - Data Parsing Helpers
    
    private func parseHeartRateData(_ data: Data, timestamp: Date) -> [SensorReading] {
        var readings: [SensorReading] = []
        
        guard data.count >= 2 else { return readings }
        
        let flags = data[0]
        var offset = 1
        
        // Check if heart rate is 16-bit (bit 0 of flags)
        let is16Bit = (flags & 0x01) != 0
        
        var heartRateValue: UInt16 = 0
        
        if is16Bit && data.count >= offset + 2 {
            heartRateValue = data.subdata(in: offset..<offset+2)
                .withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            offset += 2
        } else if data.count >= offset + 1 {
            heartRateValue = UInt16(data[offset])
            offset += 1
        }
        
        // Create heart rate reading
        if heartRateValue > 0 {
            readings.append(SensorReading(
                sensorType: .heartRate,
                value: Double(heartRateValue),
                timestamp: timestamp,
                deviceId: deviceInfo.id.uuidString,
                quality: 0.95
            ))
        }
        
        // Parse RR intervals if present (contact detected bit)
        if (flags & 0x10) != 0 {
            while offset + 2 <= data.count {
                let rrInterval = data.subdata(in: offset..<offset+2)
                    .withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
                
                // RR interval is in 1/1024 seconds
                let rrSeconds = Double(rrInterval) / 1024.0
                
                readings.append(SensorReading(
                    sensorType: .ppgInfrared, // Use PPG IR for RR intervals
                    value: Double(rrInterval),
                    timestamp: timestamp,
                    deviceId: deviceInfo.id.uuidString,
                    quality: 0.9
                ))
                
                offset += 2
            }
        }
        
        return readings
    }
    
    private func parseBatteryData(_ data: Data, timestamp: Date) -> SensorReading? {
        guard data.count >= 1 else { return nil }
        
        let batteryValue = data[0]
        deviceInfo.batteryLevel = Int(batteryValue)
        
        return SensorReading(
            sensorType: .battery,
            value: Double(batteryValue),
            timestamp: timestamp,
            deviceId: deviceInfo.id.uuidString
        )
    }
    
    private func parseTemperatureData(_ data: Data, timestamp: Date) -> SensorReading? {
        guard data.count >= 5 else { return nil } // Minimum for temperature measurement
        
        let flags = data[0]
        var offset = 1
        
        // Temperature value is 32-bit IEEE-754 float
        if data.count >= offset + 4 {
            let tempValue = data.subdata(in: offset..<offset+4)
                .withUnsafeBytes { $0.load(as: Float32.self) }
            
            // Check if temperature is in Fahrenheit (bit 0 of flags)
            let isInFahrenheit = (flags & 0x01) != 0
            let temperatureCelsius = isInFahrenheit ? (tempValue - 32.0) * 5.0 / 9.0 : tempValue
            
            return SensorReading(
                sensorType: .temperature,
                value: Double(temperatureCelsius),
                timestamp: timestamp,
                deviceId: deviceInfo.id.uuidString,
                quality: 0.98
            )
        }
        
        return nil
    }
}

// MARK: - CBPeripheralDelegate

extension OralableDevice: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("❌ Oralable Service discovery error: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            if [Self.serviceUUID, Self.batteryServiceUUID, Self.temperatureServiceUUID].contains(service.uuid) {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("❌ Oralable Characteristic discovery error: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            self.characteristics[characteristic.uuid] = characteristic
            
            // Read initial values
            peripheral.readValue(for: characteristic)
        }
        
        deviceInfo.connectionState = .connected
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("❌ Oralable Value update error: \(error!.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        // Parse data
        _ = parseData(data, from: characteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Oralable Notification state error: \(error.localizedDescription)")
        } else {
            print("✅ Oralable Notifications \(characteristic.isNotifying ? "enabled" : "disabled") for \(characteristic.uuid)")
        }
    }
}
