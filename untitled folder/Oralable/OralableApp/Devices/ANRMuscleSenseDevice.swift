//
//  ANRMuscleSenseDevice.swift
//  OralableApp
//
//  Created by John A Cogan on 04/11/2025.
//


//
//  ANRMuscleSenseDevice.swift
//  OralableApp
//
//  Created: November 4, 2025
//  Concrete implementation of BLEDeviceProtocol for ANR Muscle Sense device
//

import Foundation
import CoreBluetooth
import Combine

/// ANR Muscle Sense device implementation
@MainActor
class ANRMuscleSenseDevice: NSObject, BLEDeviceProtocol {
    
    // MARK: - BLE Service & Characteristics UUIDs
    
    private static let serviceUUID = CBUUID(string: "0000180D-0000-1000-8000-00805F9B34FB") // Heart Rate Service
    private static let emgCharacteristicUUID = CBUUID(string: "00002A37-0000-1000-8000-00805F9B34FB") // Heart Rate Measurement
    private static let batteryServiceUUID = CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB")
    private static let batteryCharacteristicUUID = CBUUID(string: "00002A19-0000-1000-8000-00805F9B34FB")
    
    // MARK: - Protocol Properties
    
    var deviceInfo: DeviceInfo
    var deviceType: DeviceType { .anr }
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

    private let sensorReadingsBatchSubject = PassthroughSubject<[SensorReading], Never>()
    var sensorReadingsBatch: AnyPublisher<[SensorReading], Never> {
        sensorReadingsBatchSubject.eraseToAnyPublisher()
    }

    var latestReadings: [SensorType: SensorReading] = [:]
    
    var supportedSensors: [SensorType] {
        DeviceType.anr.defaultSensors
    }
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager?
    private var characteristics: [CBUUID: CBCharacteristic] = [:]
    
    // MARK: - Initialization
    
    init(peripheral: CBPeripheral, name: String) {
        self.peripheral = peripheral
        self.deviceInfo = DeviceInfo(
            type: .anr,
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
        
        // Enable notifications for EMG data
        if let emgChar = characteristics[Self.emgCharacteristicUUID] {
            peripheral.setNotifyValue(true, for: emgChar)
        }
        
        // Enable notifications for battery
        if let batteryChar = characteristics[Self.batteryCharacteristicUUID] {
            peripheral.setNotifyValue(true, for: batteryChar)
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
        
        // EMG Data (using Heart Rate Measurement characteristic)
        if characteristicUUID == Self.emgCharacteristicUUID {
            readings.append(contentsOf: parseEMGData(data, timestamp: timestamp))
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
        
        // Commands not implemented for ANR device
    }
    
    func updateConfiguration(_ config: DeviceConfiguration) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Configuration not implemented for ANR device
    }
    
    func updateDeviceInfo() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard let peripheral = peripheral else {
            throw DeviceError.invalidPeripheral
        }
        
        // Read battery
        if let batteryChar = characteristics[Self.batteryCharacteristicUUID] {
            peripheral.readValue(for: batteryChar)
        }
    }
    
    // MARK: - Data Parsing Helpers
    
    private func parseEMGData(_ data: Data, timestamp: Date) -> [SensorReading] {
        var readings: [SensorReading] = []
        
        // EMG data format: Using Heart Rate Measurement format
        // CRITICAL: Treat EMG data identically to PPG IR data
        // Data format varies, but typically 16-bit values
        
        guard data.count >= 2 else { return readings }
        
        let flags = data[0]
        var offset = 1
        
        // Check if heart rate is 16-bit (bit 0 of flags)
        let is16Bit = (flags & 0x01) != 0
        
        if is16Bit && data.count >= offset + 2 {
            let value = data.subdata(in: offset..<offset+2)
                .withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            
            // Store as EMG reading (treated like PPG IR)
            readings.append(SensorReading(
                sensorType: .emg,
                value: Double(value),
                timestamp: timestamp,
                deviceId: deviceInfo.id.uuidString,
                quality: 0.95
            ))
            
            offset += 2
        } else if data.count >= offset + 1 {
            let value = data[offset]
            
            // Store as EMG reading (treated like PPG IR)
            readings.append(SensorReading(
                sensorType: .emg,
                value: Double(value),
                timestamp: timestamp,
                deviceId: deviceInfo.id.uuidString,
                quality: 0.95
            ))
            
            offset += 1
        }
        
        // Parse additional samples if present (depends on ANR M40 firmware)
        while offset + 2 <= data.count {
            let value = data.subdata(in: offset..<offset+2)
                .withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            
            let sampleTimestamp = timestamp.addingTimeInterval(Double(readings.count) * 0.01) // 100 Hz
            
            readings.append(SensorReading(
                sensorType: .emg,
                value: Double(value),
                timestamp: sampleTimestamp,
                deviceId: deviceInfo.id.uuidString,
                quality: 0.95
            ))
            
            offset += 2
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
}

// MARK: - CBPeripheralDelegate

extension ANRMuscleSenseDevice: CBPeripheralDelegate {
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            Logger.shared.error(" ANR Service discovery error: \(error!.localizedDescription)")
            return
        }

        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == Self.serviceUUID || service.uuid == Self.batteryServiceUUID {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            Logger.shared.error(" ANR Characteristic discovery error: \(error!.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            // Need to dispatch to main actor for state updates
            Task { @MainActor in
                self.characteristics[characteristic.uuid] = characteristic

                // Read initial battery value
                if characteristic.uuid == Self.batteryCharacteristicUUID {
                    peripheral.readValue(for: characteristic)
                }
            }
        }

        Task { @MainActor in
            self.deviceInfo.connectionState = .connected
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            Logger.shared.error(" ANR Value update error: \(error!.localizedDescription)")
            return
        }

        guard let data = characteristic.value else { return }

        // Parse data using the existing parseData method
        Task { @MainActor in
            let _ = self.parseData(data, from: characteristic)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            Logger.shared.error(" ANR Notification state error: \(error.localizedDescription)")
        } else {
            Logger.shared.info(" ANR Notifications \(characteristic.isNotifying ? "enabled" : "disabled") for \(characteristic.uuid)")
        }
    }
}
