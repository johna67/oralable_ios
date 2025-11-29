//
//  OralableDevice.swift
//  OralableApp
//
//  CORRECTED: November 11, 2025
//  Fixed: SensorReading structure, protocol conformance, init signature
//  UPDATED: November 28, 2025
//  Added: Async/await discovery methods for proper notification enabling
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
    var peripheral: CBPeripheral?  // Strong reference to prevent deallocation
    
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

    // Batch subject for efficient multi-reading delivery
    private let sensorReadingsBatchSubject = PassthroughSubject<[SensorReading], Never>()
    var sensorReadingsBatch: AnyPublisher<[SensorReading], Never> {
        sensorReadingsBatchSubject.eraseToAnyPublisher()
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

    // Continuation for waiting until service discovery completes (legacy)
    private var connectionContinuation: CheckedContinuation<Void, Error>?

    // Day 2: Continuations for async/await discovery methods
    private var serviceDiscoveryContinuation: CheckedContinuation<Void, Error>?
    private var characteristicsDiscoveryContinuation: CheckedContinuation<Void, Error>?
    private var notificationEnableContinuation: CheckedContinuation<Void, Error>?

    // Packet counter for throttled logging
    private var packetCount = 0

    // Last timestamp used for sensor data (to ensure monotonically increasing timestamps)
    private var lastTimestamp: Date = Date()
    private let timestampLock = NSLock()

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
        
        Logger.shared.info("[OralableDevice] Initialized for '\(name)'")
        Logger.shared.info("[OralableDevice] Using TGM Service UUID: \(BLEConstants.serviceUUID.uuidString)")
    }
    
    // MARK: - Connection Management
    
    func connect() async throws {
        guard let peripheral = peripheral else {
            Logger.shared.error("[OralableDevice] No peripheral available")
            throw DeviceError.invalidPeripheral
        }

        Logger.shared.info("[OralableDevice] connect() called")
        Logger.shared.info("[OralableDevice] Peripheral state: \(peripheral.state.rawValue)")

        connectionState = .connecting
        deviceInfo.connectionState = .connecting

        // Wait for service discovery to complete
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectionContinuation = continuation

            Logger.shared.info("[OralableDevice] Discovering services...")
            peripheral.discoverServices([
                BLEConstants.serviceUUID,
                BLEConstants.batteryServiceUUID,
                BLEConstants.deviceInfoServiceUUID
            ])
        }

        Logger.shared.info("[OralableDevice] connect() completed - services and characteristics discovered")
    }
    
    func disconnect() async {
        Logger.shared.info("[OralableDevice] disconnect() called")
        
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
        Logger.shared.info("[OralableDevice] Disconnected")
    }
    
    func isAvailable() -> Bool {
        guard let peripheral = peripheral else { return false }
        return peripheral.state == .connected || peripheral.state == .connecting
    }
    
    // MARK: - Day 2: Async/Await Discovery Methods
    
    // Convenience UUIDs for findCharacteristic
    private let TGM_SERVICE_UUID = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
    private let SENSOR_DATA_CHARACTERISTIC_UUID = CBUUID(string: "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E")
    private let PPG_WAVEFORM_CHARACTERISTIC_UUID = CBUUID(string: "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E")
    
    func discoverServices() async throws {
        Logger.shared.info("[OralableDevice] Discovering services...")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.serviceDiscoveryContinuation = continuation
            peripheral?.discoverServices([TGM_SERVICE_UUID])
        }
    }
    
    func discoverCharacteristics() async throws {
        guard let tgmService = peripheral?.services?.first(where: { $0.uuid == TGM_SERVICE_UUID }) else {
            Logger.shared.error("[OralableDevice] TGM service not found")
            throw DeviceError.serviceNotFound("TGM Service")        }
        
        Logger.shared.info("[OralableDevice] Discovering characteristics...")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.characteristicsDiscoveryContinuation = continuation
            peripheral?.discoverCharacteristics(nil, for: tgmService)
        }
    }
    
    func enableNotifications() async throws {
        Logger.shared.info("[OralableDevice] Enabling notifications on sensor data characteristic...")
        
        // Enable notifications on sensor data characteristic (3A0FF001)
        guard let sensorChar = findCharacteristic(SENSOR_DATA_CHARACTERISTIC_UUID) else {
            Logger.shared.error("[OralableDevice] ❌ Sensor data characteristic not found")
            throw DeviceError.characteristicNotFound("Sensor Data")        }
        
        Logger.shared.info("[OralableDevice] Enabling notifications on sensor data characteristic")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.notificationEnableContinuation = continuation
            peripheral?.setNotifyValue(true, for: sensorChar)
        }
        
        // Note: The accelerometer characteristic notifications will be enabled separately
        // after the main continuation is resumed, to avoid blocking the ready state
    }
    
    func enableAccelerometerNotifications() async {
        // Enable notifications on PPG waveform characteristic (3A0FF002 - actually accelerometer data)
        if let ppgChar = findCharacteristic(PPG_WAVEFORM_CHARACTERISTIC_UUID) {
            Logger.shared.info("[OralableDevice] Enabling PPG waveform (accelerometer) notifications")
            peripheral?.setNotifyValue(true, for: ppgChar)
        } else {
            Logger.shared.warning("[OralableDevice] PPG waveform characteristic not available - accelerometer data will not stream")
        }
    }
    
    private func findCharacteristic(_ uuid: CBUUID) -> CBCharacteristic? {
        guard let services = peripheral?.services else { return nil }
        for service in services {
            if let characteristics = service.characteristics {
                if let char = characteristics.first(where: { $0.uuid == uuid }) {
                    return char
                }
            }
        }
        return nil
    }
    
    // MARK: - Data Operations
    
    func startDataStream() async throws {
        Logger.shared.debug("[OralableDevice] startDataStream() called")
        Logger.shared.debug("[OralableDevice] isConnected: \(isConnected)")
        Logger.shared.debug("[OralableDevice] connectionState: \(connectionState)")
        Logger.shared.debug("[OralableDevice] sensorDataCharacteristic: \(sensorDataCharacteristic != nil ? "✓" : "✗")")
        Logger.shared.debug("[OralableDevice] ppgWaveformCharacteristic: \(ppgWaveformCharacteristic != nil ? "✓" : "✗")")

        guard isConnected else {
            Logger.shared.error("[OralableDevice] Not connected - cannot start data stream")
            throw DeviceError.notConnected
        }

        guard let characteristic = sensorDataCharacteristic else {
            Logger.shared.error("[OralableDevice] Sensor data characteristic not found")
            throw DeviceError.characteristicNotFound("Sensor Data")
        }

        Logger.shared.debug("[OralableDevice] Enabling sensor data notifications on characteristic \(characteristic.uuid.uuidString)")
        peripheral?.setNotifyValue(true, for: characteristic)
        isStreaming = true
        Logger.shared.info("[OralableDevice] Sensor data notifications enabled")

        if let ppgChar = ppgWaveformCharacteristic {
            Logger.shared.debug("[OralableDevice] Enabling PPG waveform notifications on characteristic \(ppgChar.uuid.uuidString)")
            peripheral?.setNotifyValue(true, for: ppgChar)
            Logger.shared.info("[OralableDevice] PPG waveform notifications enabled")
        } else {
            Logger.shared.warning("[OralableDevice] PPG waveform characteristic not available - skipping")
        }

        // Enable notifications on battery characteristic
        if let batteryChar = batteryCharacteristic {
            Logger.shared.info("[OralableDevice] Enabling battery notifications on characteristic \(batteryChar.uuid.uuidString)")
            peripheral?.setNotifyValue(true, for: batteryChar)
            Logger.shared.info("[OralableDevice] Battery notifications enabled")
        } else {
            Logger.shared.warning("[OralableDevice] Battery characteristic not available - skipping")
        }

        // Enable notifications on other TGM characteristics (may contain temperature, etc.)
        for char in otherCharacteristics {
            Logger.shared.debug("[OralableDevice] Enabling notifications on characteristic \(char.uuid.uuidString)")
            peripheral?.setNotifyValue(true, for: char)
        }
        if !otherCharacteristics.isEmpty {
            Logger.shared.info("[OralableDevice] Enabled notifications on \(otherCharacteristics.count) additional TGM characteristics")
        }

        Logger.shared.info("[OralableDevice] Data stream started successfully")
    }
    
    func stopDataStream() async {
        Logger.shared.debug("[OralableDevice] stopDataStream() called")

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
        Logger.shared.info("[OralableDevice] Data streaming stopped")
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
        // Get next timestamp (ensure it's always increasing)
        timestampLock.lock()
        let now = Date()
        // Ensure timestamp advances by at least 0.02 seconds (50Hz) from last packet
        let minNextTimestamp = lastTimestamp.addingTimeInterval(0.02)
        let timestamp = now > minNextTimestamp ? now : minNextTimestamp
        lastTimestamp = timestamp
        timestampLock.unlock()

        // Route based on known characteristic UUIDs (no logging per packet - too verbose)
        if characteristic.uuid == BLEConstants.sensorDataCharacteristicUUID {
            return parseSensorData(data, timestamp: timestamp)
        } else if characteristic.uuid == BLEConstants.ppgWaveformCharacteristicUUID {
            return parsePPGWaveform(data, timestamp: timestamp)
        } else if characteristic.uuid == BLEConstants.batteryLevelCharacteristicUUID {
            return parseBatteryData(data, timestamp: timestamp)
        } else {
            // For unknown characteristics (003-008), use data size to identify type
            switch data.count {
            case 4:
                return parseBatteryData(data, timestamp: timestamp)
            case 8:
                return parseTemperatureData(data, timestamp: timestamp)
            case 154:
                return parsePPGWaveform(data, timestamp: timestamp)
            case 244:
                return parseSensorData(data, timestamp: timestamp)
            default:
                // Only log unknown formats
                Logger.shared.warning("[OralableDevice] Unknown data format: \(data.count) bytes from \(characteristic.uuid.uuidString)")
                let hexPreview = data.prefix(32).map { String(format: "%02X", $0) }.joined(separator: " ")
                Logger.shared.debug("   First 32 bytes: \(hexPreview)")
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
    
    private func parseSensorData(_ data: Data, timestamp: Date) -> [SensorReading] {
        var readings: [SensorReading] = []

        Logger.shared.debug("[OralableDevice] parseSensorData called with timestamp: \(timestamp)")

        // PPG characteristic 3A0FF001: tgm_service_ppg_data_t structure
        // Bytes 0-3: frame counter (uint32)
        // Then CONFIG_PPG_SAMPLES_PER_FRAME (20) samples, each sample is 12 bytes:
        //   - Bytes 0-3: Red (uint32)
        //   - Bytes 4-7: IR (uint32)
        //   - Bytes 8-11: Green (uint32)
        // Total: 4 + (20 * 12) = 244 bytes

        guard data.count >= 244 else {
            Logger.shared.warning("[OralableDevice] Insufficient PPG data: \(data.count) bytes (expected 244)")
            return readings
        }

        // Log first packet for debugging (throttled)
        packetCount += 1
        if packetCount % 20 == 1 {
            let hexPreview = data.prefix(32).map { String(format: "%02X", $0) }.joined(separator: " ")
            Logger.shared.debug("[OralableDevice] PPG Packet #\(packetCount) first 32 bytes: \(hexPreview)")
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

        // Update latestReadings map (keep only the most recent per channel)
        for reading in readings {
            latestReadings[reading.sensorType] = reading
        }

        // Throttled log every 20 packets to show we're receiving data
        if packetCount % 20 == 1 {
            Logger.shared.debug("[OralableDevice] PPG Frame #\(frameCounter): \(readings.count) readings (R:\(readings.filter { $0.sensorType == .ppgRed }.count), IR:\(readings.filter { $0.sensorType == .ppgInfrared }.count), G:\(readings.filter { $0.sensorType == .ppgGreen }.count))")
            if let firstRed = readings.first(where: { $0.sensorType == .ppgRed }),
               let firstIR = readings.first(where: { $0.sensorType == .ppgInfrared }),
               let firstGreen = readings.first(where: { $0.sensorType == .ppgGreen }) {
                Logger.shared.debug("   Sample values - R:\(Int(firstRed.value)) IR:\(Int(firstIR.value)) G:\(Int(firstGreen.value))")
            }
        }

        // Emit batch
        if !readings.isEmpty {
            sensorReadingsBatchSubject.send(readings)
        }

        return readings
    }

    private func parsePPGWaveform(_ data: Data, timestamp: Date) -> [SensorReading] {
        var readings: [SensorReading] = []

        // Accelerometer characteristic 3A0FF002: tgm_service_accel_data_t structure
        // Bytes 0-3: frame counter (uint32)
        // Then CONFIG_ACCEL_SAMPLES_PER_FRAME (25) samples, each sample is 6 bytes:
        //   - Bytes 0-1: x-axis (int16)
        //   - Bytes 2-3: y-axis (int16)
        //   - Bytes 4-5: z-axis (int16)
        // Total: 4 + (25 * 6) = 154 bytes

        guard data.count >= 154 else {
            Logger.shared.warning("[OralableDevice] Insufficient accel data: \(data.count) bytes (expected 154)")
            return readings
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
            let sampleOffset = 4 + (i * bytesPerSample)
            let sampleTimestamp = timestamp.addingTimeInterval(Double(i) * 0.02)  // 50Hz = 0.02s

            // Read X (bytes 0-1)
            if let x = readInt16(at: sampleOffset) {
                readings.append(SensorReading(
                    sensorType: .accelerometerX,
                    value: Double(x),
                    timestamp: sampleTimestamp,
                    deviceId: peripheral?.identifier.uuidString,
                    quality: 1.0
                ))
            }

            // Read Y (bytes 2-3)
            if let y = readInt16(at: sampleOffset + 2) {
                readings.append(SensorReading(
                    sensorType: .accelerometerY,
                    value: Double(y),
                    timestamp: sampleTimestamp,
                    deviceId: peripheral?.identifier.uuidString,
                    quality: 1.0
                ))
            }

            // Read Z (bytes 4-5)
            if let z = readInt16(at: sampleOffset + 4) {
                readings.append(SensorReading(
                    sensorType: .accelerometerZ,
                    value: Double(z),
                    timestamp: sampleTimestamp,
                    deviceId: peripheral?.identifier.uuidString,
                    quality: 1.0
                ))
            }
        }

        // Update latest readings
        for reading in readings {
            latestReadings[reading.sensorType] = reading
        }

        // Throttled log every 50 packets
        packetCount += 1
        if packetCount % 50 == 1 {
            Logger.shared.debug("[OralableDevice] Accel Packet #\(frameCounter): \(readings.count) readings")
            if let firstX = readings.first(where: { $0.sensorType == .accelerometerX }),
               let firstY = readings.first(where: { $0.sensorType == .accelerometerY }),
               let firstZ = readings.first(where: { $0.sensorType == .accelerometerZ }) {
                Logger.shared.debug("   Sample values - X:\(Int(firstX.value)) Y:\(Int(firstY.value)) Z:\(Int(firstZ.value))")
            }
        }

        // Emit batch
        if !readings.isEmpty {
            sensorReadingsBatchSubject.send(readings)
        }

        return readings
    }

    private func parseBatteryData(_ data: Data, timestamp: Date) -> [SensorReading] {
        // Battery data: 4 bytes (uint32 millivolts)
        guard data.count >= 4 else {
            Logger.shared.warning("[OralableDevice] Insufficient battery data: \(data.count) bytes")
            return []
        }

        // Helper to read UInt32 little-endian
        func readUInt32(at offset: Int) -> UInt32? {
            guard offset + 3 < data.count else { return nil }
            return UInt32(data[offset]) |
                   (UInt32(data[offset + 1]) << 8) |
                   (UInt32(data[offset + 2]) << 16) |
                   (UInt32(data[offset + 3]) << 24)
        }

        guard let batteryMillivolts = readUInt32(at: 0) else {
            return []
        }

        // Convert to percentage (3.0V = 0%, 4.2V = 100%)
        let minVoltage: Double = 3000  // 3.0V
        let maxVoltage: Double = 4200  // 4.2V
        let batteryPercent = min(max((Double(batteryMillivolts) - minVoltage) / (maxVoltage - minVoltage) * 100.0, 0.0), 100.0)

        let reading = SensorReading(
            sensorType: .battery,
            value: batteryPercent,
            timestamp: timestamp,
            deviceId: peripheral?.identifier.uuidString,
            quality: 1.0
        )

        latestReadings[.battery] = reading
        sensorReadingsBatchSubject.send([reading])

        Logger.shared.debug("[OralableDevice] Battery: \(Int(batteryPercent))% (\(batteryMillivolts)mV)")
        return [reading]
    }

    private func parseTemperatureData(_ data: Data, timestamp: Date) -> [SensorReading] {
        // Temperature data: 8 bytes total
        // Bytes 0-3: frame counter (uint32)
        // Bytes 4-5: temperature as signed int16 in centidegree Celsius (1/100th degree)
        guard data.count >= 8 else {
            Logger.shared.warning("[OralableDevice] Insufficient temperature data: \(data.count) bytes (expected 8)")
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
            timestamp: timestamp,
            deviceId: peripheral?.identifier.uuidString,
            quality: 1.0
        )

        latestReadings[.temperature] = reading
        sensorReadingsBatchSubject.send([reading])

        Logger.shared.debug("[OralableDevice] Temperature: \(String(format: "%.2f", temperatureCelsius))°C")
        return [reading]
    }
}

// MARK: - CBPeripheralDelegate

extension OralableDevice: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Logger.shared.debug("[OralableDevice] didDiscoverServices")

        if let error = error {
            Logger.shared.error("[OralableDevice] ❌ Service discovery error: \(error.localizedDescription)")
            
            // Resume Day 2 continuation if present
            if let continuation = serviceDiscoveryContinuation {
                serviceDiscoveryContinuation = nil
                continuation.resume(throwing: DeviceError.connectionFailed(error.localizedDescription))
            }
            
            // Resume legacy continuation if present
            if let continuation = connectionContinuation {
                connectionContinuation = nil
                continuation.resume(throwing: DeviceError.connectionFailed(error.localizedDescription))
            }
            return
        }

        guard let services = peripheral.services else {
            Logger.shared.warning("[OralableDevice] ❌ No services found")
            let error = DeviceError.characteristicNotFound("No services")
            
            // Resume Day 2 continuation if present
            if let continuation = serviceDiscoveryContinuation {
                serviceDiscoveryContinuation = nil
                continuation.resume(throwing: error)
            }
            
            // Resume legacy continuation if present
            if let continuation = connectionContinuation {
                connectionContinuation = nil
                continuation.resume(throwing: error)
            }
            return
        }
        
        Logger.shared.info("[OralableDevice] ✅ Discovered \(services.count) services")
        
        // Resume Day 2 continuation if present
        if let continuation = serviceDiscoveryContinuation {
            serviceDiscoveryContinuation = nil
            continuation.resume()
            Logger.shared.info("[OralableDevice] ✅ Services discovered - resuming continuation")
        }
        
        // Legacy behavior: discover characteristics for all services
        for service in services {
            Logger.shared.debug("   - \(service.uuid.uuidString)")
            
            if service.uuid == BLEConstants.serviceUUID {
                Logger.shared.debug("[OralableDevice] Discovering characteristics for TGM Service...")
                peripheral.discoverCharacteristics(nil, for: service)
            } else if service.uuid == BLEConstants.batteryServiceUUID {
                Logger.shared.debug("[OralableDevice] Discovering characteristics for Battery Service...")
                peripheral.discoverCharacteristics([BLEConstants.batteryLevelCharacteristicUUID], for: service)
            } else if service.uuid == BLEConstants.deviceInfoServiceUUID {
                Logger.shared.debug("[OralableDevice] Discovering characteristics for Device Info Service...")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Logger.shared.debug("[OralableDevice] didDiscoverCharacteristicsFor service: \(service.uuid.uuidString)")

        if let error = error {
            Logger.shared.error("[OralableDevice] ❌ Characteristic discovery error: \(error.localizedDescription)")
            
            // Resume Day 2 continuation if present
            if let continuation = characteristicsDiscoveryContinuation {
                characteristicsDiscoveryContinuation = nil
                continuation.resume(throwing: DeviceError.characteristicNotFound(error.localizedDescription))
            }
            
            // Resume legacy continuation if present
            if let continuation = connectionContinuation {
                connectionContinuation = nil
                continuation.resume(throwing: DeviceError.characteristicNotFound(error.localizedDescription))
            }
            return
        }

        guard let characteristics = service.characteristics else {
            Logger.shared.warning("[OralableDevice] ❌ No characteristics found")
            // Don't fail - other services might have characteristics
            return
        }
        
        Logger.shared.info("[OralableDevice] ✅ Discovered \(characteristics.count) characteristics")
        
        // Store ALL the characteristics we need
        for characteristic in characteristics {
            Logger.shared.debug("   - \(characteristic.uuid.uuidString)")
            Logger.shared.debug("     Properties: \(characteristic.properties)")
            
            if characteristic.uuid == BLEConstants.sensorDataCharacteristicUUID {
                sensorDataCharacteristic = characteristic
                Logger.shared.info("[OralableDevice] ✅ Found sensor data characteristic")
            } else if characteristic.uuid == BLEConstants.ppgWaveformCharacteristicUUID {
                ppgWaveformCharacteristic = characteristic
                Logger.shared.info("[OralableDevice] ✅ Found PPG waveform characteristic (accelerometer)")
            } else if characteristic.uuid == BLEConstants.characteristic005UUID ||
                      characteristic.uuid == BLEConstants.characteristic006UUID {
                controlCharacteristic = characteristic
                Logger.shared.info("[OralableDevice] ✅ Found control characteristic")
            } else if characteristic.uuid == BLEConstants.batteryLevelCharacteristicUUID {
                batteryCharacteristic = characteristic
                Logger.shared.info("[OralableDevice] ✅ Found battery characteristic")
            } else if characteristic.uuid == BLEConstants.characteristic003UUID ||
                      characteristic.uuid == BLEConstants.characteristic004UUID ||
                      characteristic.uuid == BLEConstants.characteristic007UUID ||
                      characteristic.uuid == BLEConstants.characteristic008UUID {
                otherCharacteristics.append(characteristic)
                Logger.shared.debug("[OralableDevice] ✅ Found TGM characteristic \(characteristic.uuid.uuidString)")
            } else if characteristic.uuid == BLEConstants.firmwareVersionCharacteristicUUID {
                Logger.shared.debug("[OralableDevice] Reading firmware version...")
                peripheral.readValue(for: characteristic)
            }
        }
        
        // Resume Day 2 continuation if we found the main sensor data characteristic
        if let _ = sensorDataCharacteristic, let continuation = characteristicsDiscoveryContinuation {
            characteristicsDiscoveryContinuation = nil
            continuation.resume()
            Logger.shared.info("[OralableDevice] ✅ Characteristics discovered - resuming continuation")
        }
        
        // Legacy behavior: resume connection continuation when sensor data characteristic found
        if sensorDataCharacteristic != nil && connectionContinuation != nil {
            connectionState = .connected
            deviceInfo.connectionState = .connected
            Logger.shared.info("[OralableDevice] Device fully connected and ready (legacy path)")

            if let continuation = connectionContinuation {
                connectionContinuation = nil
                continuation.resume()
                Logger.shared.info("[OralableDevice] ✅ Connection continuation resumed (legacy)")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            Logger.shared.error("[OralableDevice] Value update error: \(error.localizedDescription)")
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
            Logger.shared.error("[OralableDevice] ❌ Notification state error: \(error.localizedDescription)")
            
            // Resume Day 2 continuation if present
            if let continuation = notificationEnableContinuation {
                notificationEnableContinuation = nil
                continuation.resume(throwing: DeviceError.connectionFailed(error.localizedDescription))
            }
            return
        }
        
        Logger.shared.debug("[OralableDevice] Notification state changed for \(characteristic.uuid.uuidString)")
        Logger.shared.debug("[OralableDevice] Is notifying: \(characteristic.isNotifying)")
        
        // Resume Day 2 continuation when notifications enabled on sensor data characteristic
        if characteristic.uuid == SENSOR_DATA_CHARACTERISTIC_UUID && characteristic.isNotifying {
            if let continuation = notificationEnableContinuation {
                notificationEnableContinuation = nil
                continuation.resume()
                Logger.shared.info("[OralableDevice] ✅ Notifications enabled - resuming continuation")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            Logger.shared.error("[OralableDevice] Write error: \(error.localizedDescription)")
            return
        }
        
        Logger.shared.info("[OralableDevice] Write successful for \(characteristic.uuid.uuidString)")
    }
}
