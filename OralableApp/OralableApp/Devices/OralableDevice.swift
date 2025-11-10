//
//  OralableDevice.swift
//  OralableApp
//
//  Updated: November 10, 2025
//  FIXED: Now using correct TGM Service UUIDs that match firmware
//  FIXED: Removed duplicate DeviceError enum (now in BLEDeviceProtocol.swift)
//  FIXED: Updated supportedSensors to use individual sensor channels
//  Based on v31 architecture with BLEDeviceProtocol
//

import Foundation
import CoreBluetooth
import Combine

/// Oralable device implementation with correct TGM Service UUIDs
@MainActor
class OralableDevice: NSObject, BLEDeviceProtocol {
    
    // MARK: - BLE UUIDs (TGM Service - Matches Firmware!)
    // CRITICAL FIX: These UUIDs now match the tgm_firmware implementation
    
    private let serviceUUID = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")  // TGM Service
    private let ppgCharacteristicUUID = CBUUID(string: "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E")  // PPG Data
    private let accCharacteristicUUID = CBUUID(string: "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E")  // Accelerometer
    private let tempCharacteristicUUID = CBUUID(string: "3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E") // Temperature
    private let batCharacteristicUUID = CBUUID(string: "3A0FF004-98C4-46B2-94AF-1AEE0FD4C48E")  // Battery
    private let uuidCharacteristicUUID = CBUUID(string: "3A0FF005-98C4-46B2-94AF-1AEE0FD4C48E") // Device UUID
    private let fwCharacteristicUUID = CBUUID(string: "3A0FF006-98C4-46B2-94AF-1AEE0FD4C48E")   // Firmware Version
    private let readPpgRegCharacteristicUUID = CBUUID(string: "3A0FF007-98C4-46B2-94AF-1AEE0FD4C48E")  // Read PPG Register
    private let writePpgRegCharacteristicUUID = CBUUID(string: "3A0FF008-98C4-46B2-94AF-1AEE0FD4C48E") // Write PPG Register
    
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
    
    // MARK: - Sensor Data Subjects
    
    private let sensorDataSubject = PassthroughSubject<SensorData, Never>()
    var sensorDataPublisher: AnyPublisher<SensorData, Never> {
        sensorDataSubject.eraseToAnyPublisher()
    }
    
    // Protocol requirement - must be internal
    private let sensorReadingsSubject = PassthroughSubject<SensorReading, Never>()
    var sensorReadings: AnyPublisher<SensorReading, Never> {
        sensorReadingsSubject.eraseToAnyPublisher()
    }
    
    var latestReadings: [SensorType: SensorReading] = [:]
    var supportedSensors: [SensorType] {
        [
            .heartRate, .spo2, .temperature,
            .ppgRed, .ppgInfrared, .ppgGreen,
            .accelerometerX, .accelerometerY, .accelerometerZ,
            .battery
        ]
    }
    
    // MARK: - Private Properties
    
    private var characteristics: [CBUUID: CBCharacteristic] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var ppgFrameBuffer = Data()
    private var accFrameBuffer = Data()
    
    // Constants from firmware
    private let PPG_PACKET_SIZE = 244  // 4 bytes counter + 20 samples * 12 bytes
    private let ACC_PACKET_SIZE = 154  // 4 bytes counter + 25 samples * 6 bytes
    private let TEMP_PACKET_SIZE = 8   // 4 bytes counter + 2 bytes temp + 2 bytes padding
    
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
        
        connectionState = .connecting
        peripheral.delegate = self
        
        // Discover TGM Service
        peripheral.discoverServices([serviceUUID])
    }
    
    func disconnect() async {
        connectionState = .disconnecting
        
        await stopDataStream()
        characteristics.removeAll()
        
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
        
        guard let peripheral = peripheral else {
            throw DeviceError.invalidPeripheral
        }
        
        // Enable notifications for all sensor characteristics
        for (uuid, characteristic) in characteristics {
            if [ppgCharacteristicUUID, accCharacteristicUUID, tempCharacteristicUUID, batCharacteristicUUID].contains(uuid) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func stopDataStream() async {
        guard let peripheral = peripheral else { return }
        
        for characteristic in characteristics.values {
            if characteristic.isNotifying {
                peripheral.setNotifyValue(false, for: characteristic)
            }
        }
    }
    
    func readSensor(_ type: SensorType) async throws -> SensorReading {
        if let reading = latestReadings[type] {
            return reading
        }
        throw DeviceError.sensorNotAvailable(type)
    }
    
    // MARK: - Protocol Required Methods
    
    func requestReading(for sensorType: SensorType) async throws -> SensorReading? {
        return latestReadings[sensorType]
    }
    
    func parseData(_ data: Data, from characteristic: CBCharacteristic) -> [SensorReading] {
        // This is handled internally via didUpdateValueFor callbacks
        return []
    }
    
    func sendCommand(_ command: DeviceCommand) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        // Commands not yet implemented for Oralable
    }
    
    func updateConfiguration(_ config: DeviceConfiguration) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        // Configuration not yet implemented for Oralable
    }
    
    func updateDeviceInfo() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard let peripheral = peripheral else {
            throw DeviceError.invalidPeripheral
        }
        
        // Request fresh values
        if let batChar = characteristics[batCharacteristicUUID] {
            peripheral.readValue(for: batChar)
        }
        if let fwChar = characteristics[fwCharacteristicUUID] {
            peripheral.readValue(for: fwChar)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension OralableDevice: CBPeripheralDelegate {
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                // Discover all TGM characteristics
                let characteristicUUIDs = [
                    ppgCharacteristicUUID,
                    accCharacteristicUUID,
                    tempCharacteristicUUID,
                    batCharacteristicUUID,
                    uuidCharacteristicUUID,
                    fwCharacteristicUUID,
                    readPpgRegCharacteristicUUID,
                    writePpgRegCharacteristicUUID
                ]
                peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        Task { @MainActor in
            for characteristic in characteristics {
                self.characteristics[characteristic.uuid] = characteristic
                
                // Read initial values for certain characteristics
                if [batCharacteristicUUID, fwCharacteristicUUID, uuidCharacteristicUUID].contains(characteristic.uuid) {
                    peripheral.readValue(for: characteristic)
                }
            }
            
            // Mark as connected once characteristics are discovered
            self.connectionState = .connected
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let value = characteristic.value else { return }
        
        Task { @MainActor in
            switch characteristic.uuid {
            case ppgCharacteristicUUID:
                self.handlePPGData(value)
                
            case accCharacteristicUUID:
                self.handleAccelerometerData(value)
                
            case tempCharacteristicUUID:
                self.handleTemperatureData(value)
                
            case batCharacteristicUUID:
                self.handleBatteryData(value)
                
            case fwCharacteristicUUID:
                self.handleFirmwareVersion(value)
                
            case uuidCharacteristicUUID:
                self.handleDeviceUUID(value)
                
            default:
                break
            }
        }
    }
}

// MARK: - Data Parsing (Based on FIRMWARE_PROTOCOL.md)

private extension OralableDevice {
    
    func handlePPGData(_ data: Data) {
        // PPG Packet Structure (244 bytes total):
        // Bytes 0-3: Frame counter (uint32_t, little-endian)
        // Then 20 samples, each with:
        //   Bytes 0-3: Red LED (uint32_t)
        //   Bytes 4-7: IR LED (uint32_t)
        //   Bytes 8-11: Green LED (uint32_t)
        
        guard data.count == PPG_PACKET_SIZE else {
            print("Invalid PPG packet size: \(data.count) (expected \(PPG_PACKET_SIZE))")
            return
        }
        
        let frameCounter = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        
        // Process all 20 samples
        for i in 0..<20 {
            let offset = 4 + (i * 12)  // 4 bytes header + sample index * 12 bytes per sample
            
            let redValue = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
            let irValue = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: UInt32.self) }
            let greenValue = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 8, as: UInt32.self) }
            
            let timestamp = Date()
            
            // Create individual sensor readings for each channel
            let redReading = SensorReading(
                sensorType: .ppgRed,
                value: Double(redValue),
                timestamp: timestamp,
                deviceId: peripheral?.identifier.uuidString
            )
            
            let irReading = SensorReading(
                sensorType: .ppgInfrared,
                value: Double(irValue),
                timestamp: timestamp,
                deviceId: peripheral?.identifier.uuidString
            )
            
            let greenReading = SensorReading(
                sensorType: .ppgGreen,
                value: Double(greenValue),
                timestamp: timestamp,
                deviceId: peripheral?.identifier.uuidString
            )
            
            // Update latest readings
            latestReadings[.ppgRed] = redReading
            latestReadings[.ppgInfrared] = irReading
            latestReadings[.ppgGreen] = greenReading
            
            // Emit sensor readings
            sensorReadingsSubject.send(redReading)
            sensorReadingsSubject.send(irReading)
            sensorReadingsSubject.send(greenReading)
            
            // Calculate SpO2 if possible
            if let spo2Value = calculateSpO2(red: redValue, ir: irValue) {
                let spo2Reading = SensorReading(
                    sensorType: .spo2,
                    value: spo2Value,
                    timestamp: timestamp,
                    deviceId: peripheral?.identifier.uuidString,
                    quality: 0.8
                )
                latestReadings[.spo2] = spo2Reading
                sensorReadingsSubject.send(spo2Reading)
            }
            
            // Create structured sensor data for legacy support
            let ppgData = PPGData(
                red: Int32(redValue),
                ir: Int32(irValue),
                green: Int32(greenValue),
                timestamp: timestamp
            )
            
            let accelData = AccelerometerData(
                x: Int16(latestReadings[.accelerometerX]?.value ?? 0),
                y: Int16(latestReadings[.accelerometerY]?.value ?? 0),
                z: Int16(latestReadings[.accelerometerZ]?.value ?? 0),
                timestamp: timestamp
            )
            
            let tempData = TemperatureData(
                celsius: latestReadings[.temperature]?.value ?? 36.5,
                timestamp: timestamp
            )
            
            let batteryData = BatteryData(
                percentage: Int(latestReadings[.battery]?.value ?? 100),
                timestamp: timestamp
            )
            
            let heartRateData = latestReadings[.heartRate].map {
                HeartRateData(bpm: $0.value, quality: $0.quality ?? 0.8, timestamp: $0.timestamp)
            }
            
            let spo2Data = latestReadings[.spo2].map {
                SpO2Data(percentage: $0.value, quality: $0.quality ?? 0.8, timestamp: $0.timestamp)
            }
            
            let sensorData = SensorData(
                timestamp: timestamp,
                ppg: ppgData,
                accelerometer: accelData,
                temperature: tempData,
                battery: batteryData,
                heartRate: heartRateData,
                spo2: spo2Data
            )
            
            sensorDataSubject.send(sensorData)
        }
    }
    
    func handleAccelerometerData(_ data: Data) {
        // ACC Packet Structure (154 bytes total):
        // Bytes 0-3: Frame counter (uint32_t, little-endian)
        // Then 25 samples, each with:
        //   Bytes 0-1: X axis (int16_t, in milligravity)
        //   Bytes 2-3: Y axis (int16_t, in milligravity)
        //   Bytes 4-5: Z axis (int16_t, in milligravity)
        
        guard data.count == ACC_PACKET_SIZE else {
            print("Invalid ACC packet size: \(data.count) (expected \(ACC_PACKET_SIZE))")
            return
        }
        
        let frameCounter = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        
        // Process all 25 samples
        for i in 0..<25 {
            let offset = 4 + (i * 6)  // 4 bytes header + sample index * 6 bytes per sample
            
            let xValue = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int16.self) }
            let yValue = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 2, as: Int16.self) }
            let zValue = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: Int16.self) }
            
            // Convert from milligravity to g (divide by 1000)
            let xG = Double(xValue) / 1000.0
            let yG = Double(yValue) / 1000.0
            let zG = Double(zValue) / 1000.0
            
            let timestamp = Date()
            
            // Create individual sensor readings for each axis
            let xReading = SensorReading(
                sensorType: .accelerometerX,
                value: xG,
                timestamp: timestamp,
                deviceId: peripheral?.identifier.uuidString
            )
            
            let yReading = SensorReading(
                sensorType: .accelerometerY,
                value: yG,
                timestamp: timestamp,
                deviceId: peripheral?.identifier.uuidString
            )
            
            let zReading = SensorReading(
                sensorType: .accelerometerZ,
                value: zG,
                timestamp: timestamp,
                deviceId: peripheral?.identifier.uuidString
            )
            
            // Update latest readings
            latestReadings[.accelerometerX] = xReading
            latestReadings[.accelerometerY] = yReading
            latestReadings[.accelerometerZ] = zReading
            
            // Emit sensor readings
            sensorReadingsSubject.send(xReading)
            sensorReadingsSubject.send(yReading)
            sensorReadingsSubject.send(zReading)
        }
    }
    
    func handleTemperatureData(_ data: Data) {
        // Temperature Packet Structure (8 bytes):
        // Bytes 0-3: Frame counter (uint32_t, little-endian)
        // Bytes 4-5: Temperature (int16_t, in centidegrees Celsius)
        // Bytes 6-7: Unused/padding
        
        guard data.count == TEMP_PACKET_SIZE else {
            print("Invalid temperature packet size: \(data.count)")
            return
        }
        
        let frameCounter = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        let tempCentidegrees = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int16.self) }
        
        // Convert from centidegrees to degrees
        let temperature = Double(tempCentidegrees) / 100.0
        
        let tempReading = SensorReading(
            sensorType: .temperature,
            value: temperature,
            timestamp: Date(),
            deviceId: peripheral?.identifier.uuidString
        )
        
        latestReadings[.temperature] = tempReading
        sensorReadingsSubject.send(tempReading)
    }
    
    func handleBatteryData(_ data: Data) {
        // Battery Packet Structure (4 bytes):
        // Bytes 0-3: Battery voltage (int32_t, in millivolts)
        
        guard data.count >= 4 else {
            print("Invalid battery packet size: \(data.count)")
            return
        }
        
        let millivolts = data.withUnsafeBytes { $0.load(as: Int32.self) }
        let voltage = Double(millivolts) / 1000.0
        
        // Convert voltage to percentage (Li-ion battery)
        // 4.2V = 100%, 3.7V = 50%, 3.0V = 0%
        let percentage: Double
        if voltage >= 4.2 {
            percentage = 100
        } else if voltage <= 3.0 {
            percentage = 0
        } else {
            // Linear approximation between 3.0V and 4.2V
            percentage = ((voltage - 3.0) / 1.2) * 100
        }
        
        batteryLevel = Int(percentage)
        
        let batteryReading = SensorReading(
            sensorType: .battery,
            value: percentage,
            timestamp: Date(),
            deviceId: peripheral?.identifier.uuidString
        )
        
        latestReadings[.battery] = batteryReading
        sensorReadingsSubject.send(batteryReading)
    }
    
    func handleFirmwareVersion(_ data: Data) {
        if let version = String(data: data, encoding: .utf8) {
            firmwareVersion = version
        }
    }
    
    func handleDeviceUUID(_ data: Data) {
        guard data.count == 8 else { return }
        
        let uuid = data.withUnsafeBytes { $0.load(as: UInt64.self) }
        hardwareVersion = String(format: "%016llX", uuid)
    }
    
    func calculateSpO2(red: UInt32, ir: UInt32) -> Double? {
        guard red > 0 && ir > 0 else { return nil }
        
        // Simple SpO2 calculation (needs calibration)
        let ratio = Double(red) / Double(ir)
        let spo2 = 110.0 - 25.0 * ratio
        
        return max(0, min(100, spo2))
    }
}

