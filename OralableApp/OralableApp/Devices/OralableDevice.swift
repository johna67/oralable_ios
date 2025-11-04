//
//  OralableDevice.swift
//  OralableApp
//
//  Created by John A Cogan on 04/11/2025.
//


//
//  OralableDevice.swift
//  OralableApp
//
//  Created: November 4, 2025
//  Concrete implementation of BLEDeviceProtocol for Oralable TGM/MAM device
//

import Foundation
import CoreBluetooth
import Combine

/// Oralable device implementation
@MainActor
class OralableDevice: NSObject, BLEDeviceProtocol {
    
    // MARK: - BLE Service & Characteristics UUIDs
    
    private static let serviceUUID = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
    private static let ppgCharacteristicUUID = CBUUID(string: "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E")
    private static let accelCharacteristicUUID = CBUUID(string: "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E")
    private static let tempCharacteristicUUID = CBUUID(string: "3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E")
    private static let batteryCharacteristicUUID = CBUUID(string: "3A0FF004-98C4-46B2-94AF-1AEE0FD4C48E")
    private static let uuidCharacteristicUUID = CBUUID(string: "3A0FF005-98C4-46B2-94AF-1AEE0FD4C48E")
    private static let firmwareCharacteristicUUID = CBUUID(string: "3A0FF006-98C4-46B2-94AF-1AEE0FD4C48E")
    
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
    private var deviceUUID: String?
    
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
        
        // Connection will be handled by CBCentralManager
        // This is a placeholder - actual connection happens via BLE manager
        
        peripheral.delegate = self
    }
    
    func disconnect() async {
        deviceInfo.connectionState = .disconnecting
        
        // Stop notifications
        await stopDataStream()
        
        // Disconnection will be handled by CBCentralManager
        
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
        
        // Enable notifications for all data characteristics
        if let ppgChar = characteristics[Self.ppgCharacteristicUUID] {
            peripheral.setNotifyValue(true, for: ppgChar)
        }
        
        if let accelChar = characteristics[Self.accelCharacteristicUUID] {
            peripheral.setNotifyValue(true, for: accelChar)
        }
        
        if let tempChar = characteristics[Self.tempCharacteristicUUID] {
            peripheral.setNotifyValue(true, for: tempChar)
        }
        
        if let batteryChar = characteristics[Self.batteryCharacteristicUUID] {
            peripheral.setNotifyValue(true, for: batteryChar)
        }
    }
    
    func stopDataStream() async {
        guard let peripheral = peripheral else { return }
        
        // Disable notifications
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
        
        // PPG Data
        if characteristicUUID == Self.ppgCharacteristicUUID {
            readings.append(contentsOf: parsePPGData(data, timestamp: timestamp))
        }
        // Accelerometer Data
        else if characteristicUUID == Self.accelCharacteristicUUID {
            readings.append(contentsOf: parseAccelData(data, timestamp: timestamp))
        }
        // Temperature Data
        else if characteristicUUID == Self.tempCharacteristicUUID {
            if let reading = parseTempData(data, timestamp: timestamp) {
                readings.append(reading)
            }
        }
        // Battery Data
        else if characteristicUUID == Self.batteryCharacteristicUUID {
            if let reading = parseBatteryData(data, timestamp: timestamp) {
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
        
        // Commands not implemented for current Oralable firmware
        // Future firmware may support commands
    }
    
    func updateConfiguration(_ config: DeviceConfiguration) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Configuration not implemented for current Oralable firmware
    }
    
    func updateDeviceInfo() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard let peripheral = peripheral else {
            throw DeviceError.invalidPeripheral
        }
        
        // Read UUID
        if let uuidChar = characteristics[Self.uuidCharacteristicUUID] {
            peripheral.readValue(for: uuidChar)
        }
        
        // Read firmware version
        if let firmwareChar = characteristics[Self.firmwareCharacteristicUUID] {
            peripheral.readValue(for: firmwareChar)
        }
        
        // Read battery
        if let batteryChar = characteristics[Self.batteryCharacteristicUUID] {
            peripheral.readValue(for: batteryChar)
        }
    }
    
    // MARK: - Data Parsing Helpers
    
    private func parsePPGData(_ data: Data, timestamp: Date) -> [SensorReading] {
        var readings: [SensorReading] = []
        
        // PPG data format: 12-bit samples, 3 channels (Red, IR, Green)
        // Each sample: 2 bytes per channel (12 bits, MSB aligned)
        let bytesPerSample = 6 // 2 bytes × 3 channels
        let sampleCount = data.count / bytesPerSample
        
        for i in 0..<sampleCount {
            let offset = i * bytesPerSample
            
            guard offset + bytesPerSample <= data.count else { break }
            
            // Parse Red channel
            let red = data.subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            let redValue = Double(red & 0x0FFF) // 12-bit mask
            
            // Parse IR channel
            let ir = data.subdata(in: offset+2..<offset+4).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            let irValue = Double(ir & 0x0FFF)
            
            // Parse Green channel
            let green = data.subdata(in: offset+4..<offset+6).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            let greenValue = Double(green & 0x0FFF)
            
            let sampleTimestamp = timestamp.addingTimeInterval(Double(i) * 0.01) // 100 Hz
            
            readings.append(SensorReading(
                sensorType: .ppgRed,
                value: redValue,
                timestamp: sampleTimestamp,
                deviceId: deviceInfo.id.uuidString
            ))
            
            readings.append(SensorReading(
                sensorType: .ppgInfrared,
                value: irValue,
                timestamp: sampleTimestamp,
                deviceId: deviceInfo.id.uuidString
            ))
            
            readings.append(SensorReading(
                sensorType: .ppgGreen,
                value: greenValue,
                timestamp: sampleTimestamp,
                deviceId: deviceInfo.id.uuidString
            ))
        }
        
        return readings
    }
    
    private func parseAccelData(_ data: Data, timestamp: Date) -> [SensorReading] {
        var readings: [SensorReading] = []
        
        // Accelerometer data format: 16-bit signed integers, 3 axes (X, Y, Z)
        let bytesPerSample = 6 // 2 bytes × 3 axes
        let sampleCount = data.count / bytesPerSample
        
        for i in 0..<sampleCount {
            let offset = i * bytesPerSample
            
            guard offset + bytesPerSample <= data.count else { break }
            
            let x = data.subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: Int16.self).bigEndian }
            let y = data.subdata(in: offset+2..<offset+4).withUnsafeBytes { $0.load(as: Int16.self).bigEndian }
            let z = data.subdata(in: offset+4..<offset+6).withUnsafeBytes { $0.load(as: Int16.self).bigEndian }
            
            // Convert to g (assuming ±16g range, 16-bit resolution)
            let scale = 16.0 / 32768.0
            
            let sampleTimestamp = timestamp.addingTimeInterval(Double(i) * 0.02) // 50 Hz
            
            readings.append(SensorReading(
                sensorType: .accelerometerX,
                value: Double(x) * scale,
                timestamp: sampleTimestamp,
                deviceId: deviceInfo.id.uuidString
            ))
            
            readings.append(SensorReading(
                sensorType: .accelerometerY,
                value: Double(y) * scale,
                timestamp: sampleTimestamp,
                deviceId: deviceInfo.id.uuidString
            ))
            
            readings.append(SensorReading(
                sensorType: .accelerometerZ,
                value: Double(z) * scale,
                timestamp: sampleTimestamp,
                deviceId: deviceInfo.id.uuidString
            ))
        }
        
        return readings
    }
    
    private func parseTempData(_ data: Data, timestamp: Date) -> SensorReading? {
        guard data.count >= 4 else { return nil }
        
        // Temperature as Float32 - convert from big endian
        let tempValue = data.withUnsafeBytes { bytes in
            let rawValue = bytes.load(as: UInt32.self).bigEndian
            return Float32(bitPattern: rawValue)
        }
        
        return SensorReading(
            sensorType: .temperature,
            value: Double(tempValue),
            timestamp: timestamp,
            deviceId: deviceInfo.id.uuidString
        )
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
}

// MARK: - CBPeripheralDelegate

extension OralableDevice: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("❌ Service discovery error: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == Self.serviceUUID {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("❌ Characteristic discovery error: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            self.characteristics[characteristic.uuid] = characteristic
            
            // Read initial values
            if characteristic.uuid == Self.uuidCharacteristicUUID ||
               characteristic.uuid == Self.firmwareCharacteristicUUID ||
               characteristic.uuid == Self.batteryCharacteristicUUID {
                peripheral.readValue(for: characteristic)
            }
        }
        
        deviceInfo.connectionState = .connected
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("❌ Value update error: \(error!.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        // Parse data
        let readings = parseData(data, from: characteristic)
        
        // Handle special characteristics
        if characteristic.uuid == Self.uuidCharacteristicUUID {
            deviceUUID = data.map { String(format: "%02X", $0) }.joined()
        } else if characteristic.uuid == Self.firmwareCharacteristicUUID {
            deviceInfo.firmwareVersion = String(data: data, encoding: .utf8)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Notification state error: \(error.localizedDescription)")
        } else {
            print("✅ Notifications \(characteristic.isNotifying ? "enabled" : "disabled") for \(characteristic.uuid)")
        }
    }
}
