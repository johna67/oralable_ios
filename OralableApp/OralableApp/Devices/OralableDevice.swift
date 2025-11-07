//
//  OralableDevice.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Updated: November 7, 2025
//  Implementation of BLEDeviceProtocol for Oralable PPG device
//

import Foundation
import CoreBluetooth
import Combine

/// Oralable PPG-based bruxism monitoring device
class OralableDevice: NSObject, BLEDeviceProtocol {
    
    // MARK: - BLE UUIDs (Nordic UART Service)
    
    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // Write
    private let rxCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // Notify
    
    // MARK: - Published Properties (from Protocol)
    
    private(set) var deviceInfo: DeviceInfo
    var deviceType: DeviceType { .oralable }
    var name: String { deviceInfo.name }
    private(set) var peripheral: CBPeripheral?
    private(set) var connectionState: DeviceConnectionState = .disconnected
    var isConnected: Bool { connectionState == .connected }
    private(set) var signalStrength: Int?
    private(set) var batteryLevel: Int?
    private(set) var firmwareVersion: String?
    private(set) var hardwareVersion: String?
    
    // MARK: - Sensor Data
    
    var sensorReadings: AnyPublisher<SensorReading, Never> {
        sensorReadingsSubject.eraseToAnyPublisher()
    }
    
    private(set) var latestReadings: [SensorType: SensorReading] = [:]
    var supportedSensors: [SensorType] {
        deviceType.defaultSensors
    }
    
    // MARK: - Private Properties
    
    private let sensorReadingsSubject = PassthroughSubject<SensorReading, Never>()
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    private var isStreaming: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(peripheral: CBPeripheral, name: String? = nil, rssi: Int? = nil) {
        self.peripheral = peripheral
        self.deviceInfo = DeviceInfo(
            type: .oralable,
            name: name ?? peripheral.name ?? "Oralable",
            peripheralIdentifier: peripheral.identifier,
            connectionState: .disconnected,
            signalStrength: rssi
        )
        
        super.init()
        peripheral.delegate = self
    }
    
    // MARK: - Connection Management (Protocol)
    
    func connect() async throws {
        guard peripheral != nil else {
            throw DeviceError.invalidPeripheral
        }
        
        updateConnectionState(.connecting)
        
        // Note: Actual connection is managed by BLECentralManager
        // This method prepares the device for connection
        // The DeviceManager will call BLECentralManager.connect(to:)
    }
    
    func disconnect() async {
        updateConnectionState(.disconnecting)
        await stopDataStream()
        
        // Note: Actual disconnection is managed by BLECentralManager
        // The DeviceManager will call BLECentralManager.disconnect(from:)
        
        updateConnectionState(.disconnected)
    }
    
    func isAvailable() -> Bool {
        return peripheral != nil
    }
    
    // MARK: - Data Operations (Protocol)
    
    func startDataStream() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard let peripheral = peripheral,
              let rxChar = rxCharacteristic else {
            throw DeviceError.characteristicNotFound("RX Characteristic")
        }
        
        // Enable notifications on RX characteristic
        peripheral.setNotifyValue(true, for: rxChar)
        isStreaming = true
    }
    
    func stopDataStream() async {
        guard let peripheral = peripheral,
              let rxChar = rxCharacteristic else {
            return
        }
        
        peripheral.setNotifyValue(false, for: rxChar)
        isStreaming = false
    }
    
    func requestReading(for sensorType: SensorType) async throws -> SensorReading? {
        return latestReadings[sensorType]
    }
    
    // MARK: - Data Parsing (Protocol)
    
    func parseData(_ data: Data, from characteristic: CBCharacteristic) -> [SensorReading] {
        // Ensure this is from the RX characteristic
        guard characteristic.uuid == rxCharacteristicUUID else {
            return []
        }
        
        var readings: [SensorReading] = []
        
        // Oralable data format (adjust based on actual firmware):
        // Bytes 0-1: PPG Red (uint16)
        // Bytes 2-3: PPG Infrared (uint16)
        // Bytes 4-5: PPG Green (uint16)
        // Bytes 6-7: Accel X (int16, millig)
        // Bytes 8-9: Accel Y (int16, millig)
        // Bytes 10-11: Accel Z (int16, millig)
        // Byte 12: Battery level (uint8, 0-100%)
        // Bytes 13-14: Temperature (int16, scaled by 100)
        
        guard data.count >= 15 else {
            return []
        }
        
        let timestamp = Date()
        let deviceId = peripheral?.identifier.uuidString
        
        // Parse PPG values
        if let ppgRed = data.toUInt16(at: 0) {
            readings.append(SensorReading(
                sensorType: .ppgRed,
                value: Double(ppgRed),
                timestamp: timestamp,
                deviceId: deviceId
            ))
        }
        
        if let ppgIR = data.toUInt16(at: 2) {
            readings.append(SensorReading(
                sensorType: .ppgInfrared,
                value: Double(ppgIR),
                timestamp: timestamp,
                deviceId: deviceId
            ))
        }
        
        if let ppgGreen = data.toUInt16(at: 4) {
            readings.append(SensorReading(
                sensorType: .ppgGreen,
                value: Double(ppgGreen),
                timestamp: timestamp,
                deviceId: deviceId
            ))
        }
        
        // Parse accelerometer values (convert from millig to g)
        if let accelX = data.toInt16(at: 6) {
            readings.append(SensorReading(
                sensorType: .accelerometerX,
                value: Double(accelX) / 1000.0,
                timestamp: timestamp,
                deviceId: deviceId
            ))
        }
        
        if let accelY = data.toInt16(at: 8) {
            readings.append(SensorReading(
                sensorType: .accelerometerY,
                value: Double(accelY) / 1000.0,
                timestamp: timestamp,
                deviceId: deviceId
            ))
        }
        
        if let accelZ = data.toInt16(at: 10) {
            readings.append(SensorReading(
                sensorType: .accelerometerZ,
                value: Double(accelZ) / 1000.0,
                timestamp: timestamp,
                deviceId: deviceId
            ))
        }
        
        // Parse battery level
        if data.count > 12 {
            let battery = data[12]
            batteryLevel = Int(battery)
            deviceInfo.batteryLevel = Int(battery)
            
            readings.append(SensorReading(
                sensorType: .battery,
                value: Double(battery),
                timestamp: timestamp,
                deviceId: deviceId
            ))
        }
        
        // Parse temperature (scaled by 100)
        if let tempRaw = data.toInt16(at: 13) {
            let temperature = Double(tempRaw) / 100.0
            readings.append(SensorReading(
                sensorType: .temperature,
                value: temperature,
                timestamp: timestamp,
                deviceId: deviceId
            ))
        }
        
        // Update latest readings and publish
        for reading in readings {
            latestReadings[reading.sensorType] = reading
            sensorReadingsSubject.send(reading)
        }
        
        return readings
    }
    
    // MARK: - Device Control (Protocol)
    
    func sendCommand(_ command: DeviceCommand) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard let peripheral = peripheral,
              let txChar = txCharacteristic else {
            throw DeviceError.characteristicNotFound("TX Characteristic")
        }
        
        // Convert command to data and write
        let commandData = command.toCommandData()
        peripheral.writeValue(commandData, for: txChar, type: .withResponse)
    }
    
    func updateConfiguration(_ config: DeviceConfiguration) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Send configuration commands as needed
        // This would depend on what configuration options Oralable supports
        
        // Example: Update sampling rate
        try await sendCommand(.setSamplingRate(Hz: config.samplingRate))
        
        // Example: Enable/disable sensors
        for sensor in config.enabledSensors {
            try await sendCommand(.enableSensor(sensor))
        }
    }
    
    func updateDeviceInfo() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Request firmware version, hardware version, etc.
        try await sendCommand(.requestFirmwareVersion)
        try await sendCommand(.requestBatteryLevel)
    }
    
    // MARK: - Internal Connection Methods
    
    internal func handleConnected() {
        updateConnectionState(.connected)
        
        // Discover services
        peripheral?.discoverServices([serviceUUID])
    }
    
    internal func handleDisconnected() {
        updateConnectionState(.disconnected)
        txCharacteristic = nil
        rxCharacteristic = nil
        isStreaming = false
    }
    
    // MARK: - Private Helpers
    
    private func updateConnectionState(_ state: DeviceConnectionState) {
        connectionState = state
        deviceInfo.connectionState = state
    }
}

// MARK: - CBPeripheralDelegate

extension OralableDevice: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            updateConnectionState(.error)
            return
        }
        
        // Find our service
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            return
        }
        
        // Discover characteristics
        peripheral.discoverCharacteristics([txCharacteristicUUID, rxCharacteristicUUID], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            updateConnectionState(.error)
            return
        }
        
        // Store characteristics
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case txCharacteristicUUID:
                txCharacteristic = characteristic
            case rxCharacteristicUUID:
                rxCharacteristic = characteristic
            default:
                break
            }
        }
        
        // If both characteristics found, connection is complete
        if txCharacteristic != nil && rxCharacteristic != nil {
            updateConnectionState(.connected)
            deviceInfo.lastConnected = Date()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              let data = characteristic.value,
              characteristic.uuid == rxCharacteristicUUID else {
            return
        }
        
        // Parse and publish sensor data
        _ = parseData(data, from: characteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing to characteristic: \(error.localizedDescription)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating notification state: \(error.localizedDescription)")
            return
        }
        
        if characteristic.uuid == rxCharacteristicUUID {
            if characteristic.isNotifying {
                print("Notifications enabled for RX characteristic")
            } else {
                print("Notifications disabled for RX characteristic")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error == nil {
            signalStrength = RSSI.intValue
            deviceInfo.signalStrength = RSSI.intValue
        }
    }
}

// MARK: - Data Extension

private extension Data {
    
    /// Read UInt16 (little-endian) at specified offset
    func toUInt16(at offset: Int) -> UInt16? {
        guard offset + 1 < count else { return nil }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
    
    /// Read Int16 (little-endian) at specified offset
    func toInt16(at offset: Int) -> Int16? {
        guard let value = toUInt16(at: offset) else { return nil }
        return Int16(bitPattern: value)
    }
}

// MARK: - DeviceCommand Extension

extension DeviceCommand {
    
    /// Convert command to data for transmission via BLE
    func toCommandData() -> Data {
        // Convert command to byte array based on Oralable protocol
        // This should match your firmware's command protocol
        
        let commandString = self.rawValue
        return commandString.data(using: .utf8) ?? Data()
    }
}
