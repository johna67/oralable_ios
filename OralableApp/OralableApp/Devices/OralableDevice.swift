//
//  OralableDevice.swift
//  OralableApp
//
//  Created: November 10, 2025
//  Oralable device implementation conforming to BLEDeviceProtocol
//

import Foundation
import CoreBluetooth
import Combine

/// Oralable device implementation
class OralableDevice: NSObject, BLEDeviceProtocol, ObservableObject {
    
    // MARK: - BLE Service & Characteristic UUIDs
    
    private struct BLEConstants {
        static let serviceUUID = CBUUID(string: "180D") // Replace with actual Oralable service UUID
        static let sensorDataCharacteristicUUID = CBUUID(string: "2A37") // Replace with actual UUID
        static let controlCharacteristicUUID = CBUUID(string: "2A39") // Replace with actual UUID
        static let batteryServiceUUID = CBUUID(string: "180F")
        static let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")
        static let deviceInfoServiceUUID = CBUUID(string: "180A")
        static let firmwareVersionCharacteristicUUID = CBUUID(string: "2A26")
        static let hardwareVersionCharacteristicUUID = CBUUID(string: "2A27")
    }
    
    // MARK: - Properties
    
    @Published private(set) var deviceInfo: DeviceInfo
    let deviceType: DeviceType = .oralable
    var name: String
    weak var peripheral: CBPeripheral?
    
    @Published private(set) var connectionState: DeviceConnectionState = .disconnected
    @Published private(set) var signalStrength: Int?
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var firmwareVersion: String?
    @Published private(set) var hardwareVersion: String?
    
    private let sensorReadingsSubject = PassthroughSubject<SensorReading, Never>()
    var sensorReadings: AnyPublisher<SensorReading, Never> {
        sensorReadingsSubject.eraseToAnyPublisher()
    }
    
    @Published private(set) var latestReadings: [SensorType: SensorReading] = [:]
    
    let supportedSensors: [SensorType] = [
        .ppgRed,
        .ppgInfrared,
        .ppgGreen,
        .accelerometerX,
        .accelerometerY,
        .accelerometerZ,
        .temperature,
        .battery
    ]
    
    var isConnected: Bool {
        connectionState == .connected
    }
    
    // MARK: - Private Properties
    
    private var configuration: DeviceConfiguration = .defaultOralable
    private var isStreaming = false
    private var sensorDataCharacteristic: CBCharacteristic?
    private var controlCharacteristic: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(peripheral: CBPeripheral, deviceInfo: DeviceInfo? = nil) {
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Oralable Device"
        self.deviceInfo = deviceInfo ?? DeviceInfo(
            type: .oralable,
            name: peripheral.name ?? "Oralable Device",
            peripheralIdentifier: peripheral.identifier,
            connectionState: .disconnected
        )
        
        super.init()
        peripheral.delegate = self
    }
    
    // MARK: - Connection Management
    
    func connect() async throws {
        guard let peripheral = peripheral else {
            throw DeviceError.invalidPeripheral
        }
        
        connectionState = .connecting
        
        // Note: Actual connection is handled by CBCentralManager
        // This method should be called after the central manager connects
        peripheral.discoverServices([
            BLEConstants.serviceUUID,
            BLEConstants.batteryServiceUUID,
            BLEConstants.deviceInfoServiceUUID
        ])
    }
    
    func disconnect() async {
        connectionState = .disconnecting
        isStreaming = false
        
        // Disable notifications
        if let characteristic = sensorDataCharacteristic {
            peripheral?.setNotifyValue(false, for: characteristic)
        }
        
        // Note: Actual disconnection is handled by CBCentralManager
        connectionState = .disconnected
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
        
        guard let characteristic = sensorDataCharacteristic else {
            throw DeviceError.characteristicNotFound("Sensor Data")
        }
        
        peripheral?.setNotifyValue(true, for: characteristic)
        try await sendCommand(.startSensors)
        isStreaming = true
    }
    
    func stopDataStream() async {
        guard let characteristic = sensorDataCharacteristic else { return }
        
        peripheral?.setNotifyValue(false, for: characteristic)
        try? await sendCommand(.stopSensors)
        isStreaming = false
    }
    
    func requestReading(for sensorType: SensorType) async throws -> SensorReading? {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard supportedSensors.contains(sensorType) else {
            throw DeviceError.operationNotSupported
        }
        
        // Return cached reading or request new one
        return latestReadings[sensorType]
    }
    
    func parseData(_ data: Data, from characteristic: CBCharacteristic) -> [SensorReading] {
        // Parse based on characteristic UUID
        if characteristic.uuid == BLEConstants.sensorDataCharacteristicUUID {
            return parseSensorData(data)
        } else if characteristic.uuid == BLEConstants.batteryLevelCharacteristicUUID {
            return parseBatteryData(data)
        }
        
        return []
    }
    
    // MARK: - Device Control
    
    func sendCommand(_ command: DeviceCommand) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard let characteristic = controlCharacteristic else {
            throw DeviceError.characteristicNotFound("Control")
        }
        
        let commandData = command.rawValue.data(using: .utf8) ?? Data()
        peripheral?.writeValue(commandData, for: characteristic, type: .withResponse)
    }
    
    func updateConfiguration(_ config: DeviceConfiguration) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Update sampling rate
        if config.samplingRate != configuration.samplingRate {
            try await sendCommand(.setSamplingRate(Hz: config.samplingRate))
        }
        
        // Update enabled sensors
        let toEnable = config.enabledSensors.subtracting(configuration.enabledSensors)
        let toDisable = configuration.enabledSensors.subtracting(config.enabledSensors)
        
        for sensor in toEnable {
            try await sendCommand(.enableSensor(sensor))
        }
        
        for sensor in toDisable {
            try await sendCommand(.disableSensor(sensor))
        }
        
        configuration = config
    }
    
    func updateDeviceInfo() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        try await sendCommand(.requestBatteryLevel)
        try await sendCommand(.requestFirmwareVersion)
    }
    
    // MARK: - Private Parsing Methods
    
    private func parseSensorData(_ data: Data) -> [SensorReading] {
        var readings: [SensorReading] = []
        
        // Example parsing logic - adjust based on actual Oralable protocol
        guard data.count >= 20 else { return [] }
        
        let timestamp = Date()
        
        // Parse PPG data (bytes 0-5, 16-bit values)
        if data.count >= 6 {
            let ppgRed = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) })
            let ppgIR = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) })
            let ppgGreen = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self) })
            
            readings.append(SensorReading(sensorType: .ppgRed, value: ppgRed, timestamp: timestamp))
            readings.append(SensorReading(sensorType: .ppgInfrared, value: ppgIR, timestamp: timestamp))
            readings.append(SensorReading(sensorType: .ppgGreen, value: ppgGreen, timestamp: timestamp))
        }
        
        // Parse accelerometer data (bytes 6-11, 16-bit signed values)
        if data.count >= 12 {
            let accelX = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 6, as: Int16.self) }) / 1000.0
            let accelY = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Int16.self) }) / 1000.0
            let accelZ = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 10, as: Int16.self) }) / 1000.0
            
            readings.append(SensorReading(sensorType: .accelerometerX, value: accelX, timestamp: timestamp))
            readings.append(SensorReading(sensorType: .accelerometerY, value: accelY, timestamp: timestamp))
            readings.append(SensorReading(sensorType: .accelerometerZ, value: accelZ, timestamp: timestamp))
        }
        
        // Parse temperature (bytes 12-13, 16-bit value)
        if data.count >= 14 {
            let temp = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt16.self) }) / 100.0
            readings.append(SensorReading(sensorType: .temperature, value: temp, timestamp: timestamp))
        }
        
        // Update latest readings
        for reading in readings {
            latestReadings[reading.sensorType] = reading
            sensorReadingsSubject.send(reading)
        }
        
        return readings
    }
    
    private func parseBatteryData(_ data: Data) -> [SensorReading] {
        guard let batteryValue = data.first else { return [] }
        
        batteryLevel = Int(batteryValue)
        
        let reading = SensorReading(
            sensorType: .battery,
            value: Double(batteryValue),
            timestamp: Date()
        )
        
        latestReadings[.battery] = reading
        sensorReadingsSubject.send(reading)
        
        return [reading]
    }
}

// MARK: - CBPeripheralDelegate

extension OralableDevice: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            connectionState = .disconnected
            return
        }
        
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        
        service.characteristics?.forEach { characteristic in
            switch characteristic.uuid {
            case BLEConstants.sensorDataCharacteristicUUID:
                sensorDataCharacteristic = characteristic
                
            case BLEConstants.controlCharacteristicUUID:
                controlCharacteristic = characteristic
                
            case BLEConstants.batteryLevelCharacteristicUUID:
                peripheral.readValue(for: characteristic)
                
            case BLEConstants.firmwareVersionCharacteristicUUID:
                peripheral.readValue(for: characteristic)
                
            case BLEConstants.hardwareVersionCharacteristicUUID:
                peripheral.readValue(for: characteristic)
                
            default:
                break
            }
        }
        
        // All characteristics discovered
        if sensorDataCharacteristic != nil && controlCharacteristic != nil {
            connectionState = .connected
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        
        let readings = parseData(data, from: characteristic)
        
        // Handle firmware/hardware version updates
        if characteristic.uuid == BLEConstants.firmwareVersionCharacteristicUUID {
            firmwareVersion = String(data: data, encoding: .utf8)
        } else if characteristic.uuid == BLEConstants.hardwareVersionCharacteristicUUID {
            hardwareVersion = String(data: data, encoding: .utf8)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Write failed: \(error.localizedDescription)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Notification state update failed: \(error.localizedDescription)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        signalStrength = RSSI.intValue
    }
}
