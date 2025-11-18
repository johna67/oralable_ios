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
    private var batteryCharacteristic: CBCharacteristic?
    private var otherCharacteristics: [CBCharacteristic] = []  // For characteristics 003-008
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

        if let characteristic = batteryCharacteristic {
            peripheral?.setNotifyValue(false, for: characteristic)
        }

        for characteristic in otherCharacteristics {
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

        // Enable notifications on battery characteristic
        if let batteryChar = batteryCharacteristic {
            print("🔋 [OralableDevice] Enabling battery notifications on characteristic \(batteryChar.uuid.uuidString)")
            peripheral?.setNotifyValue(true, for: batteryChar)
            print("✅ [OralableDevice] Battery notifications enabled")
        } else {
            print("⚠️ [OralableDevice] Battery characteristic not available - skipping")
        }

        // Enable notifications on other TGM characteristics (may contain temperature, etc.)
        for char in otherCharacteristics {
            print("📊 [OralableDevice] Enabling notifications on characteristic \(char.uuid.uuidString)")
            peripheral?.setNotifyValue(true, for: char)
        }
        if !otherCharacteristics.isEmpty {
            print("✅ [OralableDevice] Enabled notifications on \(otherCharacteristics.count) additional TGM characteristics")
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

        if let characteristic = batteryCharacteristic {
            peripheral?.setNotifyValue(false, for: characteristic)
        }

        for characteristic in otherCharacteristics {
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
        // Route based on known characteristic UUIDs (no logging per packet - too verbose)
        if characteristic.uuid == BLEConstants.sensorDataCharacteristicUUID {
            return parseSensorData(data)
        } else if characteristic.uuid == BLEConstants.ppgWaveformCharacteristicUUID {
            return parsePPGWaveform(data)
        } else if characteristic.uuid == BLEConstants.batteryLevelCharacteristicUUID {
            return parseBatteryData(data)
        } else {
            // For unknown characteristics (003-008), use data size to identify type
            switch data.count {
            case 4:
                return parseBatteryData(data)
            case 8:
                return parseTemperatureData(data)
            case 154:
                return parsePPGWaveform(data)
            case 244:
                return parseSensorData(data)
            default:
                // Only log unknown formats
                print("⚠️ [OralableDevice] Unknown data format: \(data.count) bytes from \(characteristic.uuid.uuidString)")
                let hexPreview = data.prefix(32).map { String(format: "%02X", $0) }.joined(separator: " ")
                print("   First 32 bytes: \(hexPreview)")
                return []
            }
        }
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

        // PPG characteristic 3A0FF001: tgm_service_ppg_data_t structure
        // Bytes 0-3: frame counter (uint32)
        // Then CONFIG_PPG_SAMPLES_PER_FRAME (20) samples, each sample is 12 bytes:
        //   - Bytes 0-3: Red (uint32)
        //   - Bytes 4-7: IR (uint32)
        //   - Bytes 8-11: Green (uint32)
        // Total: 4 + (20 * 12) = 244 bytes

        guard data.count >= 244 else {
            print("⚠️ [OralableDevice] Insufficient PPG data: \(data.count) bytes (expected 244)")
            return readings
        }

        // Log first packet for debugging (throttled)
        packetCount += 1
        if packetCount % 20 == 1 {
            let hexPreview = data.prefix(32).map { String(format: "%02X", $0) }.joined(separator: " ")
            print("📦 [OralableDevice] PPG Packet #\(packetCount) first 32 bytes: \(hexPreview)")
        }

        // Helper to read UInt32 little-endian
        func readUInt32(at offset: Int) -> UInt32? {
            guard offset + 3 < data.count else { return nil }
            return UInt32(data[offset]) |
                   (UInt32(data[offset + 1]) << 8) |
                   (UInt32(data[offset + 2]) << 16) |
                   (UInt32(data[offset + 3]) << 24)
        }

        // Read frame counter
        let frameCounter = readUInt32(at: 0) ?? 0

        // Parse 20 PPG samples (interleaved R, IR, G per sample)
        let samplesPerFrame = 20
        let bytesPerSample = 12  // 4 bytes Red + 4 bytes IR + 4 bytes Green

        for i in 0..<samplesPerFrame {
            let sampleOffset = 4 + (i * bytesPerSample)  // Skip 4-byte frame counter
            let sampleTimestamp = timestamp.addingTimeInterval(Double(i) * 0.02)  // 50Hz = 0.02s

            // Read Red (bytes 0-3 of sample)
            if let ppgRed = readUInt32(at: sampleOffset) {
                if ppgRed > 1000 && ppgRed < 500000 {  // Valid range check
                    readings.append(SensorReading(
                        sensorType: .ppgRed,
                        value: Double(ppgRed),
                        timestamp: sampleTimestamp,
                        deviceId: peripheral?.identifier.uuidString,
                        quality: 0.9
                    ))
                }
            }

            // Read IR (bytes 4-7 of sample)
            if let ppgIR = readUInt32(at: sampleOffset + 4) {
                if ppgIR > 1000 && ppgIR < 500000 {
                    readings.append(SensorReading(
                        sensorType: .ppgInfrared,
                        value: Double(ppgIR),
                        timestamp: sampleTimestamp,
                        deviceId: peripheral?.identifier.uuidString,
                        quality: 0.9
                    ))
                }
            }

            // Read Green (bytes 8-11 of sample)
            if let ppgGreen = readUInt32(at: sampleOffset + 8) {
                if ppgGreen > 1000 && ppgGreen < 500000 {
                    readings.append(SensorReading(
                        sensorType: .ppgGreen,
                        value: Double(ppgGreen),
                        timestamp: sampleTimestamp,
                        deviceId: peripheral?.identifier.uuidString,
                        quality: 0.9
                    ))
                }
            }
        }

        // Send readings to subscribers
        for reading in readings {
            latestReadings[reading.sensorType] = reading
            sensorReadingsSubject.send(reading)
        }

        // Throttled summary logging
        if packetCount % 20 == 1 {
            let redCount = readings.filter { $0.sensorType == .ppgRed }.count
            let irCount = readings.filter { $0.sensorType == .ppgInfrared }.count
            let greenCount = readings.filter { $0.sensorType == .ppgGreen }.count
            print("✅ [OralableDevice] PPG Frame #\(frameCounter): \(readings.count) readings (R:\(redCount), IR:\(irCount), G:\(greenCount))")

            if let firstRed = readings.first(where: { $0.sensorType == .ppgRed }),
               let firstIR = readings.first(where: { $0.sensorType == .ppgInfrared }),
               let firstGreen = readings.first(where: { $0.sensorType == .ppgGreen }) {
                print("   Sample values - R:\(Int(firstRed.value)) IR:\(Int(firstIR.value)) G:\(Int(firstGreen.value))")
            }
        }

        return readings
    }
    
    private func parsePPGWaveform(_ data: Data) -> [SensorReading] {
        // NOTE: Despite the name, characteristic 3A0FF002 is actually ACCELEROMETER data
        // Accelerometer characteristic: tgm_service_acc_data_t structure
        // Bytes 0-3: frame counter (uint32)
        // Then CONFIG_ACC_SAMPLES_PER_FRAME (25) samples, each sample is 6 bytes:
        //   - Bytes 0-1: X (int16)
        //   - Bytes 2-3: Y (int16)
        //   - Bytes 4-5: Z (int16)
        // Total: 4 + (25 * 6) = 154 bytes

        var readings: [SensorReading] = []
        let timestamp = Date()

        guard data.count >= 154 else {
            print("⚠️ [OralableDevice] Insufficient accelerometer data: \(data.count) bytes (expected 154)")
            return readings
        }

        // Log first packet for debugging (throttled)
        if packetCount % 20 == 1 {
            let hexPreview = data.prefix(28).map { String(format: "%02X", $0) }.joined(separator: " ")
            print("📦 [OralableDevice] Accel Packet first 28 bytes: \(hexPreview)")
        }

        // Helper to read Int16 little-endian
        func readInt16(at offset: Int) -> Int16? {
            guard offset + 1 < data.count else { return nil }
            let unsigned = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            return Int16(bitPattern: unsigned)
        }

        // Helper to read UInt32 little-endian
        func readUInt32(at offset: Int) -> UInt32? {
            guard offset + 3 < data.count else { return nil }
            return UInt32(data[offset]) |
                   (UInt32(data[offset + 1]) << 8) |
                   (UInt32(data[offset + 2]) << 16) |
                   (UInt32(data[offset + 3]) << 24)
        }

        // Read frame counter
        let frameCounter = readUInt32(at: 0) ?? 0

        // Parse 25 accelerometer samples
        let samplesPerFrame = 25
        let bytesPerSample = 6  // 2 bytes X + 2 bytes Y + 2 bytes Z

        for i in 0..<samplesPerFrame {
            let sampleOffset = 4 + (i * bytesPerSample)  // Skip 4-byte frame counter
            let sampleTimestamp = timestamp.addingTimeInterval(Double(i) * 0.02)  // 50Hz = 0.02s

            // Read X (bytes 0-1 of sample)
            if let accelX = readInt16(at: sampleOffset) {
                let accelXG = Double(accelX) / 1000.0  // Convert mg to g
                if abs(accelXG) < 16.0 {  // Sanity check (±16g range)
                    readings.append(SensorReading(
                        sensorType: .accelerometerX,
                        value: accelXG,
                        timestamp: sampleTimestamp,
                        deviceId: peripheral?.identifier.uuidString,
                        quality: 0.95
                    ))
                }
            }

            // Read Y (bytes 2-3 of sample)
            if let accelY = readInt16(at: sampleOffset + 2) {
                let accelYG = Double(accelY) / 1000.0
                if abs(accelYG) < 16.0 {
                    readings.append(SensorReading(
                        sensorType: .accelerometerY,
                        value: accelYG,
                        timestamp: sampleTimestamp,
                        deviceId: peripheral?.identifier.uuidString,
                        quality: 0.95
                    ))
                }
            }

            // Read Z (bytes 4-5 of sample)
            if let accelZ = readInt16(at: sampleOffset + 4) {
                let accelZG = Double(accelZ) / 1000.0
                if abs(accelZG) < 16.0 {
                    readings.append(SensorReading(
                        sensorType: .accelerometerZ,
                        value: accelZG,
                        timestamp: sampleTimestamp,
                        deviceId: peripheral?.identifier.uuidString,
                        quality: 0.95
                    ))
                }
            }
        }

        // Send readings to subscribers
        for reading in readings {
            latestReadings[reading.sensorType] = reading
            sensorReadingsSubject.send(reading)
        }

        // Throttled summary logging
        if packetCount % 20 == 1 {
            let xCount = readings.filter { $0.sensorType == .accelerometerX }.count
            let yCount = readings.filter { $0.sensorType == .accelerometerY }.count
            let zCount = readings.filter { $0.sensorType == .accelerometerZ }.count
            print("✅ [OralableDevice] Accel Frame #\(frameCounter): \(readings.count) readings (X:\(xCount), Y:\(yCount), Z:\(zCount))")

            if let firstX = readings.first(where: { $0.sensorType == .accelerometerX }),
               let firstY = readings.first(where: { $0.sensorType == .accelerometerY }),
               let firstZ = readings.first(where: { $0.sensorType == .accelerometerZ }) {
                print("   Sample values - X:\(String(format: "%.3f", firstX.value))g Y:\(String(format: "%.3f", firstY.value))g Z:\(String(format: "%.3f", firstZ.value))g")
            }
        }

        return readings
    }
    
    private func parseBatteryData(_ data: Data) -> [SensorReading] {
        // Battery voltage data: 4 bytes as int32 in millivolts (mV)
        guard data.count >= 4 else {
            print("⚠️ [OralableDevice] Insufficient battery data: \(data.count) bytes (expected 4)")
            return []
        }

        // Helper to read Int32 little-endian
        func readInt32(at offset: Int) -> Int32? {
            guard offset + 3 < data.count else { return nil }
            let unsigned = UInt32(data[offset]) |
                          (UInt32(data[offset + 1]) << 8) |
                          (UInt32(data[offset + 2]) << 16) |
                          (UInt32(data[offset + 3]) << 24)
            return Int32(bitPattern: unsigned)
        }

        guard let batteryMillivolts = readInt32(at: 0) else {
            return []
        }

        // Convert mV to percentage (assuming 3.0V = 0%, 4.2V = 100%)
        let minVoltage = 3000.0  // 3.0V in mV
        let maxVoltage = 4200.0  // 4.2V in mV
        let batteryPercent = max(0, min(100, ((Double(batteryMillivolts) - minVoltage) / (maxVoltage - minVoltage)) * 100))

        self.batteryLevel = Int(batteryPercent)

        let reading = SensorReading(
            sensorType: .battery,
            value: batteryPercent,
            timestamp: Date(),
            deviceId: peripheral?.identifier.uuidString,
            quality: 1.0
        )

        latestReadings[.battery] = reading
        sensorReadingsSubject.send(reading)

        print("🔋 [OralableDevice] Battery: \(Int(batteryPercent))% (\(batteryMillivolts)mV)")
        return [reading]
    }

    private func parseTemperatureData(_ data: Data) -> [SensorReading] {
        // Temperature data: 8 bytes total
        // Bytes 0-3: frame counter (uint32)
        // Bytes 4-5: temperature as signed int16 in centidegree Celsius (1/100th degree)
        guard data.count >= 8 else {
            print("⚠️ [OralableDevice] Insufficient temperature data: \(data.count) bytes (expected 8)")
            return []
        }

        // Helper to read Int16 little-endian
        func readInt16(at offset: Int) -> Int16? {
            guard offset + 1 < data.count else { return nil }
            let unsigned = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            return Int16(bitPattern: unsigned)
        }

        guard let tempCentiDegrees = readInt16(at: 4) else {
            return []
        }

        // Convert centidegrees to degrees Celsius
        let temperatureCelsius = Double(tempCentiDegrees) / 100.0

        let reading = SensorReading(
            sensorType: .temperature,
            value: temperatureCelsius,
            timestamp: Date(),
            deviceId: peripheral?.identifier.uuidString,
            quality: 1.0
        )

        latestReadings[.temperature] = reading
        sensorReadingsSubject.send(reading)

        print("🌡️ [OralableDevice] Temperature: \(String(format: "%.2f", temperatureCelsius))°C")
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
                batteryCharacteristic = characteristic
                print("🔋 [OralableDevice] Found battery characteristic - will enable notifications")
            } else if characteristic.uuid == BLEConstants.characteristic003UUID ||
                      characteristic.uuid == BLEConstants.characteristic004UUID ||
                      characteristic.uuid == BLEConstants.characteristic007UUID ||
                      characteristic.uuid == BLEConstants.characteristic008UUID {
                otherCharacteristics.append(characteristic)
                print("📊 [OralableDevice] Found TGM characteristic \(characteristic.uuid.uuidString) - will enable notifications")
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
            return  // No log spam for normal operation
        }

        // Parse data (logging happens inside parsers at throttled rate)
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
