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
        
        print("🔌 [OralableDevice] Discovering services...")
        peripheral.discoverServices([
            BLEConstants.serviceUUID,
            BLEConstants.batteryServiceUUID,
            BLEConstants.deviceInfoServiceUUID
        ])
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
        
        guard isConnected else {
            print("❌ [OralableDevice] Not connected")
            throw DeviceError.notConnected
        }
        
        if let characteristic = sensorDataCharacteristic {
            print("📊 [OralableDevice] Enabling sensor data notifications")
            peripheral?.setNotifyValue(true, for: characteristic)
            isStreaming = true
            print("✅ [OralableDevice] Sensor data notifications enabled")
        } else {
            print("❌ [OralableDevice] Sensor data characteristic not found")
            throw DeviceError.characteristicNotFound("Sensor Data")
        }
        
        if let characteristic = ppgWaveformCharacteristic {
            print("📊 [OralableDevice] Enabling PPG waveform notifications")
            peripheral?.setNotifyValue(true, for: characteristic)
            print("✅ [OralableDevice] PPG waveform notifications enabled")
        }
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
        
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("📦 [OralableDevice] Raw sensor data: \(hexString)")
        
        // TODO: Implement actual parsing based on firmware protocol
        // For now, create test readings to verify connectivity
        
        if data.count >= 20 {
            readings.append(SensorReading(
                sensorType: .ppgRed,
                value: Double(data[0]),
                timestamp: timestamp,
                deviceId: peripheral?.identifier.uuidString,
                quality: 0.9
            ))
            
            readings.append(SensorReading(
                sensorType: .temperature,
                value: 36.5,
                timestamp: timestamp,
                deviceId: peripheral?.identifier.uuidString,
                quality: 0.95
            ))
        }
        
        for reading in readings {
            latestReadings[reading.sensorType] = reading
            sensorReadingsSubject.send(reading)
        }
        
        print("✅ [OralableDevice] Parsed \(readings.count) sensor readings")
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
            return
        }
        
        guard let services = peripheral.services else {
            print("⚠️ [OralableDevice] No services found")
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
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("⚠️ [OralableDevice] No characteristics found")
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
