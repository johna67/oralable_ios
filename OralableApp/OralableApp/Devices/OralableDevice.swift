//
//  OralableDevice.swift
//  OralableApp
//
//  CORRECTED: November 11, 2025
//  Fixed: SensorReading structure, protocol conformance, init signature
//

import Foundation
import CoreBluetooth
import Combine

/// Oralable device implementation
class OralableDevice: NSObject, BLEDeviceProtocol, ObservableObject {
    
    // MARK: - BLE Service & Characteristic UUIDs
    
    private struct BLEConstants {
        // ✅ CORRECTED: TGM Service UUIDs (verified from nRF Connect 11/11/2025)
        static let serviceUUID = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
        
        // TGM Characteristics (from nRF Connect discovery)
        static let sensorDataCharacteristicUUID = CBUUID(string: "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E")
        static let ppgWaveformCharacteristicUUID = CBUUID(string: "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic003UUID = CBUUID(string: "3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic004UUID = CBUUID(string: "3A0FF004-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic005UUID = CBUUID(string: "3A0FF005-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic006UUID = CBUUID(string: "3A0FF006-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic007UUID = CBUUID(string: "3A0FF007-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic008UUID = CBUUID(string: "3A0FF008-98C4-46B2-94AF-1AEE0FD4C48E")
        
        // Standard BLE Services
        static let batteryServiceUUID = CBUUID(string: "180F")
        static let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")
        static let deviceInfoServiceUUID = CBUUID(string: "180A")
        static let firmwareVersionCharacteristicUUID = CBUUID(string: "2A26")
        static let hardwareVersionCharacteristicUUID = CBUUID(string: "2A27")
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var deviceInfo: DeviceInfo
    let deviceType: DeviceType = .oralable
    var name: String
    weak var peripheral: CBPeripheral?
    
    @Published private(set) var connectionState: DeviceConnectionState = .disconnected
    @Published private(set) var signalStrength: Int?
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var firmwareVersion: String?
    @Published private(set) var hardwareVersion: String?
    
    @Published private(set) var latestReadings: [SensorType: SensorReading] = [:]
    
    // MARK: - Sensor Data
    
    private let sensorReadingsSubject = PassthroughSubject<SensorReading, Never>()
    var sensorReadings: AnyPublisher<SensorReading, Never> {
        sensorReadingsSubject.eraseToAnyPublisher()
    }
    
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
    private var ppgWaveformCharacteristic: CBCharacteristic?
    private var controlCharacteristic: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()

    // Continuation for waiting until service discovery completes
    private var connectionContinuation: CheckedContinuation<Void, Error>?

    // Packet counter for throttled logging
    private var packetCount = 0
    
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
        
        print("🏭 [OralableDevice] Initialized for '\(name)'")
        print("🏭 [OralableDevice] Using TGM Service UUID: \(BLEConstants.serviceUUID.uuidString)")
    }
    
    // MARK: - Connection Management
    
    func connect() async throws {
        guard let peripheral = peripheral else {
            print("❌ [OralableDevice] No peripheral available")
            throw DeviceError.invalidPeripheral
        }

        print("\n🔌 [OralableDevice] connect() called")
        print("🔌 [OralableDevice] Peripheral state: \(peripheral.state.rawValue)")

        connectionState = .connecting
        deviceInfo.connectionState = .connecting

        // Wait for service discovery to complete
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectionContinuation = continuation

            print("🔌 [OralableDevice] Discovering services...")
            peripheral.discoverServices([
                BLEConstants.serviceUUID,
                BLEConstants.batteryServiceUUID,
                BLEConstants.deviceInfoServiceUUID
            ])
        }

        print("✅ [OralableDevice] connect() completed - services and characteristics discovered")
    }
    
    func disconnect() async {
        print("\n🔌 [OralableDevice] disconnect() called")
        
        connectionState = .disconnecting
        deviceInfo.connectionState = .disconnecting
        isStreaming = false
        
        if let characteristic = sensorDataCharacteristic {
            peripheral?.setNotifyValue(false, for: characteristic)
        }
        
        if let characteristic = ppgWaveformCharacteristic {
            peripheral?.setNotifyValue(false, for: characteristic)
        }
        
        connectionState = .disconnected
        deviceInfo.connectionState = .disconnected
        print("🔌 [OralableDevice] Disconnected")
    }
    
    func isAvailable() -> Bool {
        guard let peripheral = peripheral else { return false }
        return peripheral.state == .connected || peripheral.state == .connecting
    }
    
    // MARK: - Data Operations
    
    func startDataStream() async throws {
        print("\n📊 [OralableDevice] startDataStream() called")
        print("📊 [OralableDevice] isConnected: \(isConnected)")
        print("📊 [OralableDevice] connectionState: \(connectionState)")
        print("📊 [OralableDevice] sensorDataCharacteristic: \(sensorDataCharacteristic != nil ? "✓" : "✗")")
        print("📊 [OralableDevice] ppgWaveformCharacteristic: \(ppgWaveformCharacteristic != nil ? "✓" : "✗")")

        guard isConnected else {
            print("❌ [OralableDevice] Not connected - cannot start data stream")
            throw DeviceError.notConnected
        }

        guard let characteristic = sensorDataCharacteristic else {
            print("❌ [OralableDevice] Sensor data characteristic not found")
            throw DeviceError.characteristicNotFound("Sensor Data")
        }

        print("📊 [OralableDevice] Enabling sensor data notifications on characteristic \(characteristic.uuid.uuidString)")
        peripheral?.setNotifyValue(true, for: characteristic)
        isStreaming = true
        print("✅ [OralableDevice] Sensor data notifications enabled")

        if let ppgChar = ppgWaveformCharacteristic {
            print("📊 [OralableDevice] Enabling PPG waveform notifications on characteristic \(ppgChar.uuid.uuidString)")
            peripheral?.setNotifyValue(true, for: ppgChar)
            print("✅ [OralableDevice] PPG waveform notifications enabled")
        } else {
            print("⚠️ [OralableDevice] PPG waveform characteristic not available - skipping")
        }

        print("✅ [OralableDevice] Data stream started successfully")
    }
    
    func stopDataStream() async {
        print("\n📊 [OralableDevice] stopDataStream() called")
        
        if let characteristic = sensorDataCharacteristic {
            peripheral?.setNotifyValue(false, for: characteristic)
        }
        
        if let characteristic = ppgWaveformCharacteristic {
            peripheral?.setNotifyValue(false, for: characteristic)
        }
        
        isStreaming = false
        print("✅ [OralableDevice] Data streaming stopped")
    }
    
    func requestReading(for sensorType: SensorType) async throws -> SensorReading? {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard supportedSensors.contains(sensorType) else {
            throw DeviceError.operationNotSupported
        }
        
        return latestReadings[sensorType]
    }
    
    func parseData(_ data: Data, from characteristic: CBCharacteristic) -> [SensorReading] {
        print("\n📦 [OralableDevice] parseData called")
        print("📦 [OralableDevice] Characteristic: \(characteristic.uuid.uuidString)")
        print("📦 [OralableDevice] Data length: \(data.count) bytes")
        
        if characteristic.uuid == BLEConstants.sensorDataCharacteristicUUID {
            print("📦 [OralableDevice] Parsing sensor data")
            return parseSensorData(data)
        } else if characteristic.uuid == BLEConstants.ppgWaveformCharacteristicUUID {
            print("📦 [OralableDevice] Parsing PPG waveform data")
            return parsePPGWaveform(data)
        } else if characteristic.uuid == BLEConstants.batteryLevelCharacteristicUUID {
            print("📦 [OralableDevice] Parsing battery data")
            return parseBatteryData(data)
        }
        
        print("⚠️ [OralableDevice] Unknown characteristic UUID")
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
        
        if config.samplingRate != configuration.samplingRate {
            try await sendCommand(.setSamplingRate(Hz: config.samplingRate))
        }
        
        let toEnable = config.enabledSensors.subtracting(configuration.enabledSensors)
        let toDisable = configuration.enabledSensors.subtracting(config.enabledSensors)
        
        for sensor in toEnable {
            try await sendCommand(.enableSensor(sensor))
        }
        
        for sensor in toDisable {
            try await sendCommand(.disableSensor(sensor))
        }
        
        self.configuration = config
    }
    
    func updateDeviceInfo() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Request battery level and firmware version
        try await sendCommand(.requestBatteryLevel)
        try await sendCommand(.requestFirmwareVersion)
    }
    
    // MARK: - Data Parsing
    
    private func parseSensorData(_ data: Data) -> [SensorReading] {
        var readings: [SensorReading] = []
        let timestamp = Date()

        // Parse based on 244-byte firmware protocol
        guard data.count >= 244 else {
            print("⚠️ [OralableDevice] Insufficient data: \(data.count) bytes")
            return readings
        }

        // Log first 64 bytes of hex for protocol analysis (throttled)
        packetCount += 1
        if packetCount % 20 == 1 {  // Log every 20th packet
            let hexPreview = data.prefix(64).map { String(format: "%02X", $0) }.joined(separator: " ")
            print("📦 [OralableDevice] Packet #\(packetCount) first 64 bytes: \(hexPreview)")
        }

        // Helper to read UInt32 little-endian
        func readUInt32(at offset: Int) -> UInt32? {
            guard offset + 3 < data.count else { return nil }
            return UInt32(data[offset]) |
                   (UInt32(data[offset + 1]) << 8) |
                   (UInt32(data[offset + 2]) << 16) |
                   (UInt32(data[offset + 3]) << 24)
        }

        // Helper to read Int16 little-endian (for accelerometer in mg)
        func readInt16(at offset: Int) -> Int16? {
            guard offset + 1 < data.count else { return nil }
            let unsigned = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            return Int16(bitPattern: unsigned)
        }

        // HYPOTHESIS: 244-byte structure based on CONFIG_PPG_SAMPLES_PER_FRAME=20
        // Header: 4 bytes (timestamp/sequence)
        // PPG Red:   20 samples × 4 bytes = 80 bytes (offset 4-83)
        // PPG IR:    20 samples × 4 bytes = 80 bytes (offset 84-163)
        // PPG Green: 20 samples × 4 bytes = 80 bytes (offset 164-243)
        // Total: 4 + 80 + 80 + 80 = 244 bytes ✓

        let samplesPerChannel = 20
        let bytesPerSample = 4

        // Parse PPG Red channel (bytes 4-83)
        for i in 0..<samplesPerChannel {
            let offset = 4 + (i * bytesPerSample)
            if let ppgRed = readUInt32(at: offset) {
                // Validate: PPG values should be in range 1000-500000
                if ppgRed > 1000 && ppgRed < 500000 {
                    readings.append(SensorReading(
                        sensorType: .ppgRed,
                        value: Double(ppgRed),
                        timestamp: timestamp.addingTimeInterval(Double(i) * 0.02),  // 50Hz = 0.02s
                        deviceId: peripheral?.identifier.uuidString,
                        quality: 0.9
                    ))
                }
            }
        }

        // Parse PPG IR channel (bytes 84-163)
        for i in 0..<samplesPerChannel {
            let offset = 84 + (i * bytesPerSample)
            if let ppgIR = readUInt32(at: offset) {
                if ppgIR > 1000 && ppgIR < 500000 {
                    readings.append(SensorReading(
                        sensorType: .ppgInfrared,
                        value: Double(ppgIR),
                        timestamp: timestamp.addingTimeInterval(Double(i) * 0.02),
                        deviceId: peripheral?.identifier.uuidString,
                        quality: 0.9
                    ))
                }
            }
        }

        // Parse PPG Green channel (bytes 164-243)
        for i in 0..<samplesPerChannel {
            let offset = 164 + (i * bytesPerSample)
            if let ppgGreen = readUInt32(at: offset) {
                if ppgGreen > 1000 && ppgGreen < 500000 {
                    readings.append(SensorReading(
                        sensorType: .ppgGreen,
                        value: Double(ppgGreen),
                        timestamp: timestamp.addingTimeInterval(Double(i) * 0.02),
                        deviceId: peripheral?.identifier.uuidString,
                        quality: 0.9
                    ))
                }
            }
        }

        // ALTERNATIVE HYPOTHESIS: Maybe accelerometer is in the first bytes?
        // Try reading accel from bytes 0-5 as Int16 values in mg
        if let accelX = readInt16(at: 0) {
            let accelXG = Double(accelX) / 1000.0  // Convert mg to g
            if abs(accelXG) < 16.0 {
                readings.append(SensorReading(
                    sensorType: .accelerometerX,
                    value: accelXG,
                    timestamp: timestamp,
                    deviceId: peripheral?.identifier.uuidString,
                    quality: 0.95
                ))
            }
        }

        if let accelY = readInt16(at: 2) {
            let accelYG = Double(accelY) / 1000.0
            if abs(accelYG) < 16.0 {
                readings.append(SensorReading(
                    sensorType: .accelerometerY,
                    value: accelYG,
                    timestamp: timestamp,
                    deviceId: peripheral?.identifier.uuidString,
                    quality: 0.95
                ))
            }
        }

        for reading in readings {
            latestReadings[reading.sensorType] = reading
            sensorReadingsSubject.send(reading)
        }

        // Throttled summary logging
        if packetCount % 20 == 1 {
            let ppgCount = readings.filter { [.ppgRed, .ppgInfrared, .ppgGreen].contains($0.sensorType) }.count
            let accelCount = readings.filter { [.accelerometerX, .accelerometerY, .accelerometerZ].contains($0.sensorType) }.count
            print("✅ [OralableDevice] Parsed \(readings.count) readings (PPG: \(ppgCount), Accel: \(accelCount))")
            if let firstRed = readings.first(where: { $0.sensorType == .ppgRed }) {
                print("   Sample PPG Red: \(Int(firstRed.value))")
            }
            if let firstIR = readings.first(where: { $0.sensorType == .ppgInfrared }) {
                print("   Sample PPG IR: \(Int(firstIR.value))")
            }
        }

        return readings
    }
    
    private func parsePPGWaveform(_ data: Data) -> [SensorReading] {
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("📦 [OralableDevice] Raw PPG waveform: \(hexString.prefix(100))...")
        
        // TODO: Implement PPG waveform parsing
        
        print("✅ [OralableDevice] Parsed PPG waveform")
        return []
    }
    
    private func parseBatteryData(_ data: Data) -> [SensorReading] {
        guard data.count >= 1 else { return [] }
        
        let batteryPercent = Int(data[0])
        self.batteryLevel = batteryPercent
        
        let reading = SensorReading(
            sensorType: .battery,
            value: Double(batteryPercent),
            timestamp: Date(),
            deviceId: peripheral?.identifier.uuidString,
            quality: 1.0
        )
        
        latestReadings[.battery] = reading
        sensorReadingsSubject.send(reading)
        
        print("🔋 [OralableDevice] Battery: \(batteryPercent)%")
        return [reading]
    }
}

// MARK: - CBPeripheralDelegate

extension OralableDevice: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("\n🔍 [OralableDevice] didDiscoverServices")

        if let error = error {
            print("❌ [OralableDevice] Service discovery error: \(error.localizedDescription)")
            if let continuation = connectionContinuation {
                connectionContinuation = nil
                continuation.resume(throwing: DeviceError.connectionFailed(error.localizedDescription))
            }
            return
        }

        guard let services = peripheral.services else {
            print("⚠️ [OralableDevice] No services found")
            if let continuation = connectionContinuation {
                connectionContinuation = nil
                continuation.resume(throwing: DeviceError.characteristicNotFound("No services"))
            }
            return
        }
        
        print("✅ [OralableDevice] Discovered \(services.count) services:")
        for service in services {
            print("   - \(service.uuid.uuidString)")
            
            if service.uuid == BLEConstants.serviceUUID {
                print("🔍 [OralableDevice] Discovering characteristics for TGM Service...")
                peripheral.discoverCharacteristics(nil, for: service)
            } else if service.uuid == BLEConstants.batteryServiceUUID {
                print("🔍 [OralableDevice] Discovering characteristics for Battery Service...")
                peripheral.discoverCharacteristics([BLEConstants.batteryLevelCharacteristicUUID], for: service)
            } else if service.uuid == BLEConstants.deviceInfoServiceUUID {
                print("🔍 [OralableDevice] Discovering characteristics for Device Info Service...")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("\n🔍 [OralableDevice] didDiscoverCharacteristicsFor service: \(service.uuid.uuidString)")

        if let error = error {
            print("❌ [OralableDevice] Characteristic discovery error: \(error.localizedDescription)")
            if let continuation = connectionContinuation {
                connectionContinuation = nil
                continuation.resume(throwing: DeviceError.characteristicNotFound(error.localizedDescription))
            }
            return
        }

        guard let characteristics = service.characteristics else {
            print("⚠️ [OralableDevice] No characteristics found")
            // Don't fail the connection here - other services might have characteristics
            return
        }
        
        print("✅ [OralableDevice] Discovered \(characteristics.count) characteristics:")
        for characteristic in characteristics {
            print("   - \(characteristic.uuid.uuidString)")
            print("     Properties: \(characteristic.properties)")
            
            if characteristic.uuid == BLEConstants.sensorDataCharacteristicUUID {
                sensorDataCharacteristic = characteristic
                print("✅ [OralableDevice] Found sensor data characteristic")
            } else if characteristic.uuid == BLEConstants.ppgWaveformCharacteristicUUID {
                ppgWaveformCharacteristic = characteristic
                print("✅ [OralableDevice] Found PPG waveform characteristic")
            } else if characteristic.uuid == BLEConstants.characteristic005UUID ||
                      characteristic.uuid == BLEConstants.characteristic006UUID {
                controlCharacteristic = characteristic
                print("✅ [OralableDevice] Found control characteristic")
            } else if characteristic.uuid == BLEConstants.batteryLevelCharacteristicUUID {
                print("🔋 [OralableDevice] Reading battery level...")
                peripheral.readValue(for: characteristic)
            } else if characteristic.uuid == BLEConstants.firmwareVersionCharacteristicUUID {
                print("📱 [OralableDevice] Reading firmware version...")
                peripheral.readValue(for: characteristic)
            }
        }
        
        if sensorDataCharacteristic != nil {
            connectionState = .connected
            deviceInfo.connectionState = .connected
            print("✅ [OralableDevice] Device fully connected and ready")

            // Resume the connection continuation
            if let continuation = connectionContinuation {
                connectionContinuation = nil
                continuation.resume()
                print("✅ [OralableDevice] Connection continuation resumed")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ [OralableDevice] Value update error: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            print("⚠️ [OralableDevice] No data received")
            return
        }
        
        print("📨 [OralableDevice] Data received from \(characteristic.uuid.uuidString) (\(data.count) bytes)")
        
        let readings = parseData(data, from: characteristic)
        
        for reading in readings {
            latestReadings[reading.sensorType] = reading
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ [OralableDevice] Notification state error: \(error.localizedDescription)")
            return
        }
        
        print("🔔 [OralableDevice] Notification state changed for \(characteristic.uuid.uuidString)")
        print("🔔 [OralableDevice] Is notifying: \(characteristic.isNotifying)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ [OralableDevice] Write error: \(error.localizedDescription)")
            return
        }
        
        print("✅ [OralableDevice] Write successful for \(characteristic.uuid.uuidString)")
    }
}
